import Foundation
import os.log

private let sessionLogger = Logger(subsystem: "com.vibecode.macos", category: "SessionManager")

private func sessionLog(_ msg: String) {
    sessionLogger.info("\(msg)")
    let line = "\(Date()) [SessionManager] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: "/tmp/vibecode-ipc.log") {
            if let fh = FileHandle(forWritingAtPath: "/tmp/vibecode-ipc.log") {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: "/tmp/vibecode-ipc.log", contents: data)
        }
    }
}

/// Manages all active Claude Code sessions
@Observable
class SessionManager {
    var sessions: [String: ClaudeSession] = [:]
    private var permissionCallbacks: [String: (IPCResponse) -> Void] = [:]
    private var discoveryTimer: Timer?

    func handleEvent(_ message: IPCMessage) {
        sessionLog("handleEvent: \(message.eventType.rawValue) session=\(message.sessionId) tty=\(message.tty ?? "nil")")
        handleEventImmediate(message)
        SoundService.shared.play(message.eventType)
    }

    /// Start periodic session discovery
    func startDiscovery() {
        discoverExistingSessions()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.discoverExistingSessions()
        }
    }

    /// Stop periodic session discovery
    func stopDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
    }

    /// Scan ~/.claude/sessions/*.json and running claude processes to find active sessions
    func discoverExistingSessions() {
        // Method 1: Scan session JSON files
        let sessionsDir = VibeCodeConstants.claudeSessionsPath
        if let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) {
            for file in files where file.hasSuffix(".json") {
                let path = (sessionsDir as NSString).appendingPathComponent(file)
                guard let data = FileManager.default.contents(atPath: path),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let sessionId = json["sessionId"] as? String,
                      let pid = json["pid"] as? Int else { continue }

                guard kill(pid_t(pid), 0) == 0 else { continue }
                if sessions[sessionId] != nil { continue }

                let cwd = json["cwd"] as? String ?? "~"
                let session = ClaudeSession(id: sessionId, cwd: cwd)
                session.pid = pid
                session.status = .ready
                session.sessionName = json["name"] as? String

                sessions[sessionId] = session
                sessionLog("Discovered session from JSON: \(sessionId) (PID \(pid))")

                // Infer actual status from transcript (background)
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    let status = Self.inferStatusFromTranscript(sessionId: sessionId)
                    DispatchQueue.main.async {
                        if let s = self?.sessions[sessionId], s.status == .ready, status != .ready {
                            s.status = status
                            sessionLog("Inferred status for \(sessionId): \(status.rawValue)")
                        }
                    }
                }
            }
        }

        // Method 2: Scan running claude/ducc processes (on background thread to avoid blocking UI)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let discovered = Self.scanProcessList()
            sessionLog("Process scan found \(discovered.count) claude processes")
            guard !discovered.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self = self else { return }
                for info in discovered {
                    let alreadyTracked = self.sessions.values.contains(where: { $0.pid == info.pid })
                    if alreadyTracked {
                        sessionLog("Process PID \(info.pid) already tracked, skipping")
                        continue
                    }
                    let sessionId = "process-\(info.pid)"
                    if self.sessions[sessionId] != nil { continue }

                    let session = ClaudeSession(id: sessionId, cwd: info.cwd)
                    session.pid = info.pid
                    session.tty = info.tty
                    session.status = .ready  // Default to ready; active sessions update quickly via IPC events
                    self.sessions[sessionId] = session
                    sessionLog("Discovered session from process: PID \(info.pid), TTY \(info.tty ?? "?")")
                }
            }
        }

        // Clean up dead sessions (only those with known PIDs)
        let deadSessions = sessions.filter { _, session in
            guard let pid = session.pid else { return false }
            return kill(pid_t(pid), 0) != 0
        }

        for (sessionId, _) in deadSessions {
            sessions.removeValue(forKey: sessionId)
            sessionLog("Removed dead session: \(sessionId)")
        }
    }

    private struct DiscoveredProcess {
        let pid: Int
        let tty: String?
        let cwd: String
    }

    /// Scan running processes for claude/ducc instances (called on background thread)
    private static func scanProcessList() -> [DiscoveredProcess] {
        // Use a single shell command to get PID, TTY for all claude processes
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "ps -eo pid,tty,command | grep '/claude' | grep -v grep | grep -v vibecode-bridge | grep -v claude-go | grep -E '\\-\\-settings|\\-\\-dangerously|\\-\\-allow'"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return [] }

        var results: [DiscoveredProcess] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = Int(parts[0]) else { continue }
            guard kill(pid_t(pid), 0) == 0 else { continue }

            let tty = String(parts[1])
            results.append(DiscoveredProcess(pid: pid, tty: tty != "??" ? tty : nil, cwd: "~"))
        }

        // Batch cwd lookup: single lsof call for all PIDs
        if !results.isEmpty {
            let pids = results.map { "\($0.pid)" }.joined(separator: ",")
            let cwdMap = batchGetCwd(pids: pids)
            results = results.map { proc in
                DiscoveredProcess(pid: proc.pid, tty: proc.tty, cwd: cwdMap[proc.pid] ?? "~")
            }
        }

        return results
    }

    /// Get cwd for multiple PIDs in a single lsof call
    private static func batchGetCwd(pids: String) -> [Int: String] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "lsof -a -d cwd -Fpn -p \(pids) 2>/dev/null"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return [:] }

        // Parse lsof output: "p<pid>\nn<path>\n" pairs
        var result: [Int: String] = [:]
        var currentPid: Int?
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("p") {
                currentPid = Int(line.dropFirst(1))
            } else if line.hasPrefix("n/"), let pid = currentPid {
                result[pid] = String(line.dropFirst(1))
            }
        }
        return result
    }

    /// Ensure a session exists for the given message, creating one on-the-fly if needed.
    /// This handles the case where VibeCode starts (or restarts) after sessions are already running.
    private func ensureSession(for message: IPCMessage) {
        if let session = sessions[message.sessionId] {
            // Update TTY if we get it from a new event
            if session.tty == nil, let tty = message.tty {
                session.tty = tty
            }
            return
        }

        // Check if we have a process-discovered placeholder for this session's TTY
        // If so, replace it with the real session ID
        if let tty = message.tty {
            if let (placeholderId, placeholder) = sessions.first(where: {
                $0.key.hasPrefix("process-") && $0.value.tty == tty
            }) {
                sessions.removeValue(forKey: placeholderId)
                placeholder.tty = tty
                sessions[message.sessionId] = placeholder
                sessionLog("Upgraded placeholder \(placeholderId) to real session \(message.sessionId)")
                return
            }
        }

        let session = ClaudeSession(id: message.sessionId, cwd: message.cwd ?? "~")
        session.tty = message.tty
        sessions[message.sessionId] = session
        sessionLog("Auto-created session for mid-flight event: \(message.sessionId) tty=\(message.tty ?? "nil")")
    }

    private func handleEventImmediate(_ message: IPCMessage) {
        // Auto-create session if we receive an event for an unknown session
        // (e.g. VibeCode was restarted while sessions were already running)
        if message.eventType != .sessionEnd {
            ensureSession(for: message)
        }

        // Clear stale pending permissions when session moves on.
        // If the user answered in the terminal (not via VibeCode), the pending permission
        // was never resolved through our callback. Subsequent events prove Claude has moved on.
        // Only clear permissions whose callback is already gone (truly stale).
        // If callback still exists, the bridge is still blocking — permission is genuinely pending.
        if message.eventType != .permissionRequest {
            if let session = sessions[message.sessionId], !session.pendingPermissions.isEmpty {
                let stale = session.pendingPermissions.filter { permissionCallbacks[$0.id] == nil }
                if !stale.isEmpty {
                    sessionLog("Clearing \(stale.count) stale pending permissions for session \(message.sessionId)")
                    session.pendingPermissions.removeAll { permissionCallbacks[$0.id] == nil }
                    if session.pendingPermissions.isEmpty && session.status == .waitingForApproval {
                        session.status = .ready
                    }
                }
            }
        }

        switch message.eventType {
        case .sessionStart:
            let session = ClaudeSession(id: message.sessionId, cwd: message.cwd ?? "~")
            sessions[message.sessionId] = session
            CrashReporter.shared.addBreadcrumb(category: "session", message: "Session started: \(message.sessionId)")

        case .sessionEnd:
            sessions[message.sessionId]?.status = .ended
            CrashReporter.shared.addBreadcrumb(category: "session", message: "Session ended: \(message.sessionId)")
            let sid = message.sessionId
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.sessions.removeValue(forKey: sid)
            }

        case .userPromptSubmit:
            sessions[message.sessionId]?.status = .thinking
            sessions[message.sessionId]?.lastActivity = Date()
            // Store user prompt from message prompt field
            sessionLog("UserPromptSubmit: prompt=\(message.prompt ?? "nil")")
            if let promptText = message.prompt, !promptText.isEmpty {
                sessions[message.sessionId]?.lastUserPrompt = promptText
            } else if let promptText = message.toolInput?["prompt"]?.stringValue {
                sessions[message.sessionId]?.lastUserPrompt = promptText
            }

        case .preToolUse:
            sessions[message.sessionId]?.status = .runningTool
            sessions[message.sessionId]?.currentTool = message.toolName
            sessions[message.sessionId]?.currentToolInput = message.toolInput
            sessions[message.sessionId]?.lastActivity = Date()

            // Store a summary of the tool execution for display when Ready
            if let toolName = message.toolName, let toolInput = message.toolInput {
                let summary = formatToolSummary(toolName: toolName, toolInput: toolInput)
                sessions[message.sessionId]?.lastToolOutput = summary
            }

        case .postToolUse, .postToolUseFailure:
            // Save tool summary before clearing
            if let tool = sessions[message.sessionId]?.currentTool,
               let input = sessions[message.sessionId]?.currentToolInput {
                sessions[message.sessionId]?.lastToolOutput = formatToolSummary(toolName: tool, toolInput: input)
            }

            sessions[message.sessionId]?.status = .thinking
            sessions[message.sessionId]?.currentTool = nil
            sessions[message.sessionId]?.currentToolInput = nil
            sessions[message.sessionId]?.lastActivity = Date()
            // lastToolOutput already set in PreToolUse

        case .stop:
            sessions[message.sessionId]?.status = .ready
            sessions[message.sessionId]?.currentTool = nil
            sessions[message.sessionId]?.currentToolInput = nil
            // Extract last assistant response from transcript
            if let transcriptPath = message.transcriptPath {
                let sid = message.sessionId
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let response = Self.extractLastAssistantText(from: transcriptPath)
                    DispatchQueue.main.async {
                        self?.sessions[sid]?.lastAssistantResponse = response
                    }
                }
            }

        case .permissionRequest:
            let permission = PermissionRequestModel(
                id: message.id,
                sessionId: message.sessionId,
                toolName: message.toolName ?? "Unknown",
                toolInput: message.toolInput,
                timestamp: Date()
            )
            sessions[message.sessionId]?.status = .waitingForApproval
            sessions[message.sessionId]?.pendingPermissions.append(permission)
            CrashReporter.shared.addBreadcrumb(category: "permission", message: "Permission requested: \(message.toolName ?? "unknown")")

        case .subagentStart:
            sessions[message.sessionId]?.subagentCount += 1

        case .subagentStop:
            if let count = sessions[message.sessionId]?.subagentCount, count > 0 {
                sessions[message.sessionId]?.subagentCount -= 1
            }

        case .preCompact:
            sessions[message.sessionId]?.status = .compacting

        case .postCompact:
            sessions[message.sessionId]?.status = .ready

        case .notification:
            break
        }
    }

    func registerPermissionCallback(requestId: String, callback: @escaping (IPCResponse) -> Void) {
        sessionLog("Registering callback for request \(requestId)")
        permissionCallbacks[requestId] = callback
        sessionLog("Callback registered. Total callbacks: \(permissionCallbacks.count)")
    }

    func respondToPermission(requestId: String, decision: String) {
        sessionLog("respondToPermission called for request \(requestId), decision=\(decision)")
        sessionLog("Current callbacks count: \(permissionCallbacks.count)")

        let response = IPCResponse(id: requestId, decision: decision, reason: nil)

        // Remove from pending permissions
        for (_, session) in sessions {
            session.pendingPermissions.removeAll { $0.id == requestId }
            if session.pendingPermissions.isEmpty && session.status == .waitingForApproval {
                session.status = .ready
            }
        }

        // Invoke callback to send response back to bridge
        if let callback = permissionCallbacks[requestId] {
            sessionLog("Callback found for request \(requestId), invoking...")
            callback(response)
            sessionLog("Callback invoked for request \(requestId)")
        } else {
            sessionLog("ERROR: No callback found for request \(requestId)")
        }

        permissionCallbacks.removeValue(forKey: requestId)
        sessionLog("Callback removed. Remaining callbacks: \(permissionCallbacks.count)")
    }

    func respondToQuestion(requestId: String, answers: [String: AnyCodableValue]) {
        sessionLog("respondToQuestion called for request \(requestId)")
        sessionLog("respondToQuestion answers: \(answers)")

        let response = IPCResponse(id: requestId, decision: "allow", reason: nil, updatedInput: answers)
        sessionLog("respondToQuestion IPCResponse updatedInput: \(String(describing: response.updatedInput))")

        // Remove from pending permissions
        for (_, session) in sessions {
            session.pendingPermissions.removeAll { $0.id == requestId }
            if session.pendingPermissions.isEmpty && session.status == .waitingForApproval {
                session.status = .ready
            }
        }

        // Invoke callback
        if let callback = permissionCallbacks[requestId] {
            sessionLog("Question callback found for request \(requestId), invoking...")
            callback(response)
        } else {
            sessionLog("ERROR: No callback found for question request \(requestId)")
        }

        permissionCallbacks.removeValue(forKey: requestId)
    }

    // MARK: - Tool Summary Formatting

    private func formatToolSummary(toolName: String, toolInput: [String: AnyCodableValue]) -> String {
        switch toolName {
        case "Bash":
            if let cmd = toolInput["command"]?.stringValue {
                let firstLine = cmd.components(separatedBy: "\n").first ?? cmd
                let truncated = firstLine.count > 50 ? String(firstLine.prefix(50)) + "..." : firstLine
                return "Bash: \(truncated)"
            }
            return "Bash"

        case "Read":
            if let path = toolInput["file_path"]?.stringValue {
                let filename = (path as NSString).lastPathComponent
                return "Read: \(filename)"
            }
            return "Read"

        case "Edit":
            if let path = toolInput["file_path"]?.stringValue {
                let filename = (path as NSString).lastPathComponent
                return "Edit: \(filename)"
            }
            return "Edit"

        case "Write":
            if let path = toolInput["file_path"]?.stringValue {
                let filename = (path as NSString).lastPathComponent
                return "Write: \(filename)"
            }
            return "Write"

        case "Grep":
            if let pattern = toolInput["pattern"]?.stringValue {
                let truncated = pattern.count > 30 ? String(pattern.prefix(30)) + "..." : pattern
                return "Grep: \(truncated)"
            }
            return "Grep"

        case "Glob":
            if let pattern = toolInput["pattern"]?.stringValue {
                return "Glob: \(pattern)"
            }
            return "Glob"

        default:
            return toolName
        }
    }

    // MARK: - Transcript Parsing

    /// Infer session status from transcript: if last assistant message ends with tool_use, it's thinking
    private static func inferStatusFromTranscript(sessionId: String) -> SessionStatus {
        // Find transcript file
        let projectsDir = NSHomeDirectory() + "/.claude/projects"
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return .ready }

        for dir in projectDirs {
            let transcriptPath = "\(projectsDir)/\(dir)/\(sessionId).jsonl"
            if FileManager.default.fileExists(atPath: transcriptPath) {
                return inferStatusFromFile(transcriptPath)
            }
        }
        return .ready
    }

    private static func inferStatusFromFile(_ path: String) -> SessionStatus {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return .ready }
        defer { fileHandle.closeFile() }

        let tailSize: UInt64 = 32 * 1024
        let fileSize = fileHandle.seekToEndOfFile()
        let readOffset = fileSize > tailSize ? fileSize - tailSize : 0
        fileHandle.seek(toFileOffset: readOffset)
        let tailData = fileHandle.readDataToEndOfFile()
        guard let content = String(data: tailData, encoding: .utf8) else { return .ready }

        // Check last few entries to determine state
        let lines = content.components(separatedBy: "\n").reversed()
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            // Skip system messages (compaction, reminders, etc.)
            if type == "system" { continue }

            if type == "assistant" {
                if let message = json["message"] as? [String: Any],
                   let contentArr = message["content"] as? [[String: Any]],
                   let lastBlock = contentArr.last {
                    // tool_use → still working; text-only → ready
                    if lastBlock["type"] as? String == "tool_use" {
                        return .runningTool
                    }
                    // stop_reason == "tool_use" means there are more tool calls pending
                    if let stopReason = message["stop_reason"] as? String, stopReason == "tool_use" {
                        return .thinking
                    }
                }
                return .ready
            }

            if type == "user" {
                // Last non-system entry is user → assistant should be responding
                return .thinking
            }
        }
        return .ready
    }

    /// Read a transcript JSONL file and extract the last assistant text response.
    /// Only reads the tail of the file for performance (transcripts can be very large).
    private static func extractLastAssistantText(from path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        // Read only the last 64KB — the most recent messages are at the end
        let tailSize: UInt64 = 64 * 1024
        let fileSize = fileHandle.seekToEndOfFile()
        let readOffset = fileSize > tailSize ? fileSize - tailSize : 0
        fileHandle.seek(toFileOffset: readOffset)
        let tailData = fileHandle.readDataToEndOfFile()

        guard let content = String(data: tailData, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n").reversed()
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let contentArr = message["content"] as? [[String: Any]] else { continue }

            // Find text blocks (skip tool_use blocks)
            let textBlocks = contentArr.filter { $0["type"] as? String == "text" }
            if let lastText = textBlocks.last?["text"] as? String, !lastText.isEmpty {
                return lastText
            }
        }
        return nil
    }
}
