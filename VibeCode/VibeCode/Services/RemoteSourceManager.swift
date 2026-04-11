import Foundation
import os.log

private let remoteLogger = Logger(subsystem: "com.vibecode.macos", category: "RemoteSource")

private func remoteLog(_ msg: String) {
    remoteLogger.info("\(msg)")
    let line = "\(Date()) [Remote] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: "/tmp/vibecode-ipc.log") {
            if let fh = FileHandle(forWritingAtPath: "/tmp/vibecode-ipc.log") {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            }
        }
    }
}

/// Manages remote VibeCode agents — polls for events and sends approval decisions
@Observable
class RemoteSourceManager {
    static var shared: RemoteSourceManager!

    var sources: [RemoteSource] = []
    var sourceStatus: [UUID: RemoteSourceStatus] = [:]

    private let sessionManager: SessionManager
    private weak var panelController: NotchPanelController?
    private var pollingTimers: [UUID: Timer] = [:]
    private let pollInterval: TimeInterval = 0.5

    enum RemoteSourceStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    init(sessionManager: SessionManager, panelController: NotchPanelController? = nil) {
        self.sessionManager = sessionManager
        self.panelController = panelController
        loadSources()
        RemoteSourceManager.shared = self
    }

    // MARK: - Source Management

    func addSource(name: String, url: String, token: String? = nil, sshCommand: String? = nil) {
        let source = RemoteSource(name: name, url: url, token: token, sshCommand: sshCommand)
        sources.append(source)
        saveSources()
        startPolling(source)
    }

    func removeSource(id: UUID) {
        stopPolling(id: id)
        sources.removeAll { $0.id == id }
        sourceStatus.removeValue(forKey: id)
        saveSources()
    }

    func updateSource(_ source: RemoteSource) {
        guard let idx = sources.firstIndex(where: { $0.id == source.id }) else { return }
        let wasEnabled = sources[idx].isEnabled
        sources[idx] = source

        if source.isEnabled && !wasEnabled {
            startPolling(source)
        } else if !source.isEnabled && wasEnabled {
            stopPolling(id: source.id)
        } else if source.isEnabled {
            // URL or token changed — restart
            stopPolling(id: source.id)
            startPolling(source)
        }
        saveSources()
    }

    func startAll() {
        for source in sources where source.isEnabled {
            startPolling(source)
        }
    }

    func stopAll() {
        for (id, _) in pollingTimers {
            stopPolling(id: id)
        }
    }

    // MARK: - Polling

    private func startPolling(_ source: RemoteSource) {
        stopPolling(id: source.id)
        sourceStatus[source.id] = .connecting

        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll(sourceId: source.id)
        }
        pollingTimers[source.id] = timer

        // First poll immediately
        poll(sourceId: source.id)
    }

    private func stopPolling(id: UUID) {
        pollingTimers[id]?.invalidate()
        pollingTimers.removeValue(forKey: id)
        sourceStatus[id] = .disconnected
    }

    private func poll(sourceId: UUID) {
        guard let source = sources.first(where: { $0.id == sourceId }),
              source.isEnabled else {
            stopPolling(id: sourceId)
            return
        }

        let urlString = source.baseURL + "/events"
        guard let url = URL(string: urlString) else {
            sourceStatus[sourceId] = .error("Invalid URL")
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 3)
        if let token = source.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handlePollResponse(sourceId: sourceId, data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handlePollResponse(sourceId: UUID, data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            if sourceStatus[sourceId] != .error(error.localizedDescription) {
                remoteLog("Poll error for \(sourceId): \(error.localizedDescription)")
            }
            sourceStatus[sourceId] = .error(error.localizedDescription)
            return
        }

        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            sourceStatus[sourceId] = .error("Invalid response")
            return
        }

        sourceStatus[sourceId] = .connected

        if !events.isEmpty {
            remoteLog("Received \(events.count) events from \(sourceId)")
        }

        for eventDict in events {
            processRemoteEvent(eventDict, sourceId: sourceId)
        }
    }

    private func processRemoteEvent(_ eventDict: [String: Any], sourceId: UUID) {
        guard let eventTypeStr = eventDict["eventType"] as? String,
              let eventType = HookEventType(rawValue: eventTypeStr) else {
            return
        }

        let messageId = eventDict["id"] as? String ?? UUID().uuidString
        let sessionId = eventDict["sessionId"] as? String ?? "unknown"
        let cwd = eventDict["cwd"] as? String
        let toolName = eventDict["toolName"] as? String
        let prompt = eventDict["prompt"] as? String
        let transcriptPath = eventDict["transcriptPath"] as? String
        let tty = eventDict["tty"] as? String
        let timestamp = eventDict["timestamp"] as? Double ?? Date().timeIntervalSince1970

        // Convert toolInput
        var toolInput: [String: AnyCodableValue]? = nil
        if let rawInput = eventDict["toolInput"] as? [String: Any] {
            toolInput = rawInput.mapValues { AnyCodableValue.from($0) }
        }

        let message = IPCMessage(
            id: messageId,
            eventType: eventType,
            source: "remote",
            sessionId: sessionId,
            cwd: cwd,
            toolName: toolName,
            toolInput: toolInput,
            prompt: prompt,
            transcriptPath: transcriptPath,
            tty: tty,
            timestamp: timestamp
        )

        remoteLog("Remote event: \(eventTypeStr) session=\(sessionId) tool=\(toolName ?? "nil")")

        // Handle events through SessionManager
        sessionManager.handleEvent(message)

        // Mark remote sessions
        if let session = sessionManager.sessions[sessionId] {
            session.isRemote = true
            session.remoteSourceId = sourceId
        }

        // Detect interaction-needed events (only for truly terminal-only interactions)
        if eventType == .userPromptSubmit || eventType == .preToolUse || eventType == .permissionRequest || eventType == .stop {
            sessionManager.sessions[sessionId]?.needsInteraction = false
            sessionManager.sessions[sessionId]?.interactionReason = nil
        }

        // For permission requests, register a remote approval callback and expand panel
        if eventType == .permissionRequest {
            panelController?.expand()
            sessionManager.registerPermissionCallback(requestId: messageId) { [weak self] (response: IPCResponse) in
                self?.sendApproval(sourceId: sourceId, eventId: messageId, decision: response.decision ?? "deny", updatedInput: response.updatedInput)
            }
        }
    }

    // MARK: - Approval

    func sshCommandForSource(id: UUID) -> String? {
        return sources.first(where: { $0.id == id })?.sshCommand
    }

    // MARK: - Remote Input

    /// Send text input to a remote session's terminal via the agent's /input endpoint
    func sendInput(sourceId: UUID, sessionId: String, text: String) {
        guard let source = sources.first(where: { $0.id == sourceId }) else {
            remoteLog("sendInput: source \(sourceId) not found")
            return
        }

        let urlString = source.baseURL + "/input/\(sessionId)"
        guard let url = URL(string: urlString) else {
            remoteLog("sendInput: invalid URL \(urlString)")
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = source.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                remoteLog("sendInput error: \(error.localizedDescription)")
            } else {
                remoteLog("sendInput sent to session \(sessionId): \(text.prefix(100))")
            }
        }.resume()
    }

    private func sendApproval(sourceId: UUID, eventId: String, decision: String, updatedInput: [String: AnyCodableValue]? = nil) {
        guard let source = sources.first(where: { $0.id == sourceId }) else { return }

        let urlString = source.baseURL + "/approve/\(eventId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = source.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["decision": decision]
        if let updatedInput = updatedInput {
            // Convert AnyCodableValue to raw JSON-compatible types
            let rawInput = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(updatedInput)) as? [String: Any]
            if let rawInput = rawInput {
                body["updatedInput"] = rawInput
                remoteLogger.info("sendApproval: updatedInput included with \(rawInput.count) keys")
            } else {
                remoteLogger.error("sendApproval: failed to convert updatedInput")
            }
        } else {
            remoteLogger.info("sendApproval: no updatedInput")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let bodyData = request.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
            remoteLogger.info("sendApproval body: \(bodyStr)")
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                remoteLogger.error("Approval send error: \(error.localizedDescription)")
            } else {
                remoteLogger.info("Approval sent for \(eventId): \(decision)")
            }
        }.resume()
    }

    // MARK: - Health Check

    func checkHealth(source: RemoteSource, completion: @escaping (Bool, String) -> Void) {
        let urlString = source.baseURL + "/health"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 5)
        if let token = source.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["status"] as? String == "ok" else {
                    completion(false, "Invalid response")
                    return
                }
                completion(true, "Connected")
            }
        }.resume()
    }

    // MARK: - Persistence

    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "remoteSources")
        }
    }

    private func loadSources() {
        guard let data = UserDefaults.standard.data(forKey: "remoteSources"),
              let saved = try? JSONDecoder().decode([RemoteSource].self, from: data) else {
            return
        }
        sources = saved
    }
}
