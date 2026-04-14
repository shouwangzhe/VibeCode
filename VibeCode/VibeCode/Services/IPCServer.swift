import Foundation
import os.log

enum IPCError: LocalizedError {
    case readError(String)
    case invalidLength(Int)
    case decodeError(String)

    var errorDescription: String? {
        switch self {
        case .readError(let msg): return "Read error: \(msg)"
        case .invalidLength(let len): return "Invalid message length: \(len)"
        case .decodeError(let msg): return "Decode error: \(msg)"
        }
    }
}

private let logger = Logger(subsystem: "com.vibecode.macos", category: "IPC")
private let maxLogSize: UInt64 = 5 * 1024 * 1024 // 5MB

private func ipcLog(_ msg: String) {
    logger.info("\(msg)")
    let logPath = "/tmp/vibecode-ipc.log"
    let line = "\(Date()) \(msg)\n"

    guard let data = line.data(using: .utf8) else { return }

    rotateLogIfNeeded(at: logPath)

    if FileManager.default.fileExists(atPath: logPath) {
        if let fh = FileHandle(forWritingAtPath: logPath) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }
    } else {
        FileManager.default.createFile(atPath: logPath, contents: data)
    }
}

private func rotateLogIfNeeded(at path: String) {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let fileSize = attrs[.size] as? UInt64,
          fileSize > maxLogSize else {
        return
    }

    let backupPath = path + ".old"
    try? FileManager.default.removeItem(atPath: backupPath)
    try? FileManager.default.moveItem(atPath: path, toPath: backupPath)
}

/// Unix Domain Socket server for receiving hook events from the bridge
class IPCServer {
    private let sessionManager: SessionManager
    private weak var panelController: NotchPanelController?
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.vibecode.ipc.server", qos: .userInteractive)
    private let clientQueue = DispatchQueue(label: "com.vibecode.ipc.client", qos: .userInteractive, attributes: .concurrent)

    init(sessionManager: SessionManager, panelController: NotchPanelController) {
        self.sessionManager = sessionManager
        self.panelController = panelController
    }

    func start() {
        cleanupStaleSocket()
        writePidFile()

        queue.async { [weak self] in
            self?.runServer()
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
        unlink(VibeCodeConstants.socketPath)
        unlink(VibeCodeConstants.pidFilePath)
    }

    private func cleanupStaleSocket() {
        // Check if another instance is running
        if let pidStr = try? String(contentsOfFile: VibeCodeConstants.pidFilePath, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if kill(pid, 0) == 0 {
                // Process is alive — another instance is running
                ipcLog("Another VibeCode instance is running (PID \(pid))")
                return
            }
        }
        // Remove stale socket
        unlink(VibeCodeConstants.socketPath)
    }

    private func writePidFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        try? "\(pid)".write(toFile: VibeCodeConstants.pidFilePath, atomically: true, encoding: .utf8)
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { Darwin.close(clientSocket) }

        do {
            let message = try readMessage(from: clientSocket)
            processMessage(message, clientSocket: clientSocket)
        } catch let error as IPCError {
            ipcLog("[IPC] Error: \(error.localizedDescription)")
            CrashReporter.shared.captureError(error)
        } catch {
            ipcLog("[IPC] Unexpected error: \(error)")
            CrashReporter.shared.captureError(error)
        }
    }

    private func readMessage(from socket: Int32) throws -> IPCMessage {
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = recv(socket, &lengthBytes, 4, MSG_WAITALL)
        guard bytesRead == 4 else {
            throw IPCError.readError("Failed to read length header, got \(bytesRead) bytes")
        }

        let length = Int(lengthBytes[0]) << 24 | Int(lengthBytes[1]) << 16 |
                     Int(lengthBytes[2]) << 8 | Int(lengthBytes[3])
        guard length > 0, length < 1_000_000 else {
            throw IPCError.invalidLength(length)
        }

        var messageData = Data(count: length)
        let dataRead = messageData.withUnsafeMutableBytes { ptr in
            recv(socket, ptr.baseAddress!, length, MSG_WAITALL)
        }
        guard dataRead == length else {
            throw IPCError.readError("Short read: expected \(length), got \(dataRead)")
        }

        ipcLog("[IPC] Received \(length) bytes")

        do {
            return try JSONDecoder().decode(IPCMessage.self, from: messageData)
        } catch {
            let raw = String(data: messageData, encoding: .utf8) ?? "<binary>"
            throw IPCError.decodeError("JSON decode failed: \(raw.prefix(200))")
        }
    }

    private func processMessage(_ message: IPCMessage, clientSocket: Int32) {
        ipcLog("[IPC] Event: \(message.eventType.rawValue) session=\(message.sessionId) tool=\(message.toolName ?? "nil") input=\(message.toolInput?.description ?? "nil")")

        // Auto-approve: respond immediately without showing UI
        if message.eventType == .permissionRequest && sessionManager.autoApprove {
            ipcLog("[IPC] Auto-approving request \(message.id)")
            let resp = IPCResponse(id: message.id, decision: "always_allow", reason: nil)
            if let respData = try? JSONEncoder().encode(resp) {
                sendLengthPrefixed(data: respData, to: clientSocket)
            }
            DispatchQueue.main.async { [weak self] in
                self?.sessionManager.handleEvent(message)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.sessionManager.handleEvent(message)

            if message.eventType == .permissionRequest {
                self?.panelController?.expand()
            }
        }

        if message.eventType == .permissionRequest {
            handlePermissionRequest(message, clientSocket: clientSocket)
        }
    }

    private func handlePermissionRequest(_ message: IPCMessage, clientSocket: Int32) {
        ipcLog("[IPC] Setting up permission callback for request \(message.id)")
        let semaphore = DispatchSemaphore(value: 0)
        var response: IPCResponse?

        DispatchQueue.main.sync { [weak self] in
            ipcLog("[IPC] Registering callback for request \(message.id)")
            self?.sessionManager.registerPermissionCallback(requestId: message.id) { resp in
                ipcLog("[IPC] Callback invoked for request \(message.id), decision=\(resp.decision ?? "nil")")
                response = resp
                semaphore.signal()
            }
        }

        ipcLog("[IPC] Waiting for user response on request \(message.id)")
        let result = semaphore.wait(timeout: .now() + 86400)
        ipcLog("[IPC] Wait completed for request \(message.id), result=\(result == .success ? "success" : "timeout")")

        if let resp = response, let respData = try? JSONEncoder().encode(resp) {
            ipcLog("[IPC] Sending response for request \(message.id): decision=\(resp.decision ?? "nil")")
            sendLengthPrefixed(data: respData, to: clientSocket)
        } else {
            ipcLog("[IPC] ERROR: No response to send for request \(message.id)")
        }
    }

    private func sendLengthPrefixed(data: Data, to socket: Int32) {
        let length = UInt32(data.count)
        var lengthBytes: [UInt8] = [
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ]
        send(socket, &lengthBytes, 4, 0)
        data.withUnsafeBytes { ptr in
            _ = send(socket, ptr.baseAddress!, data.count, 0)
        }
    }

    private func runServer() {
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            ipcLog("Failed to create socket: \(errno)")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = VibeCodeConstants.socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: min(buf.count, 104))
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                _ = bind(serverSocket, sockPtr, addrLen)
            }
        }

        listen(serverSocket, 10)
        isRunning = true
        ipcLog("IPC server listening on \(VibeCodeConstants.socketPath)")

        while isRunning {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { continue }

            ipcLog("[IPC] Client connected (fd=\(clientSocket))")
            clientQueue.async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }
}
