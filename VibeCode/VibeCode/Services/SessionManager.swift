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
    static weak var shared: SessionManager?
    var sessions: [String: ClaudeSession] = [:]
    var autoApprove: Bool = UserDefaults.standard.bool(forKey: "autoApprovePermissions")
    private var permissionCallbacks: [String: (IPCResponse) -> Void] = [:]
    private var discoveryTimer: Timer?
    private(set) var transcriptWatcher: TranscriptWatcher?

    /// Initialize transcript watcher for hookless sessions (e.g. ducc v2.1.71)
    func setupTranscriptWatcher() {
        transcriptWatcher = TranscriptWatcher(sessionManager: self)
    }

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
        transcriptWatcher?.stopAll()
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
                    // Check if already tracked by PID
                    let alreadyTrackedByPid = self.sessions.values.contains(where: { $0.pid == info.pid })
                    if alreadyTrackedByPid {
                        // For process- placeholder sessions, update status based on CPU since
                        // they don't receive IPC events to correct their state
                        if let (sid, session) = self.sessions.first(where: {
                            $0.key.hasPrefix("process-") && $0.value.pid == info.pid
                        }) {
                            let cpuStatus: SessionStatus = info.cpuPercent > 5.0 ? .thinking : .ready
                            if session.status != cpuStatus {
                                session.status = cpuStatus
                                sessionLog("Updated process session \(sid) status to \(cpuStatus.rawValue) (CPU \(info.cpuPercent)%)")
                            }
                        }
                        continue
                    }

                    // Check if already tracked by TTY (IPC-created sessions may lack PID)
                    if let tty = info.tty,
                       let (existingId, existingSession) = self.sessions.first(where: {
                           !$0.key.hasPrefix("process-") && $0.value.tty == tty && $0.value.pid == nil
                       }) {
                        // Fill in the missing PID on the existing IPC-created session
                        existingSession.pid = info.pid
                        sessionLog("Merged process PID \(info.pid) into existing session \(existingId) by TTY \(tty)")
                        continue
                    }

                    let sessionId = "process-\(info.pid)"
                    if self.sessions[sessionId] != nil { continue }

                    let session = ClaudeSession(id: sessionId, cwd: info.cwd)
                    session.pid = info.pid
                    session.tty = info.tty
                    // Infer initial status from CPU usage: active CPU means working, idle means waiting for input
                    session.status = info.cpuPercent > 5.0 ? .thinking : .ready
                    self.sessions[sessionId] = session
                    sessionLog("Discovered session from process: PID \(info.pid), TTY \(info.tty ?? "?"), CPU \(info.cpuPercent)% → \(session.status.rawValue)")
                }
            }
        }

        // Clean up dead sessions (only those with known PIDs)
        let deadSessions = sessions.filter { _, session in
            guard let pid = session.pid else { return false }
            return kill(pid_t(pid), 0) != 0
        }

        for (sessionId, _) in deadSessions {
            if sessions[sessionId]?.isTranscriptWatching == true {
                transcriptWatcher?.stopWatching(sessionId: sessionId)
            }
            sessions.removeValue(forKey: sessionId)
            sessionLog("Removed dead session: \(sessionId)")
        }

        // Activate transcript watching for hookless sessions (e.g. ducc v2.1.71)
        // Wait >15s after creation to give hooks a chance to fire first
        for (sessionId, session) in sessions where
            !session.hasActiveHooks &&
            !session.isTranscriptWatching &&
            !sessionId.hasPrefix("process-") &&
            session.status != .ended &&
            Date().timeIntervalSince(session.startedAt) > 15
        {
            if let path = findTranscriptPath(sessionId: sessionId, cwd: session.cwd) {
                session.transcriptPath = path
                session.isTranscriptWatching = true
                let offset = Self.fileSize(at: path)
                transcriptWatcher?.startWatching(sessionId: sessionId, transcriptPath: path, initialOffset: offset)
                sessionLog("Started transcript watching for hookless session \(sessionId)")
            }
        }

        // Re-infer status for sessions showing "ready" but with recently modified transcript.
        // This catches sessions where hooks aren't firing or where discovery defaulted to ready.
        let readySessions = sessions.filter { $0.value.status == .ready && $0.value.pid != nil }
        if !readySessions.isEmpty {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                var allProjectDirs: [(base: String, dir: String)] = []
                for basePath in VibeCodeConstants.allProjectsPaths {
                    if let dirs = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                        for dir in dirs {
                            allProjectDirs.append((base: basePath, dir: dir))
                        }
                    }
                }
                guard !allProjectDirs.isEmpty else { return }

                for (sessionId, _) in readySessions {
                    for entry in allProjectDirs {
                        let transcriptPath = "\(entry.base)/\(entry.dir)/\(sessionId).jsonl"
                        guard let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptPath),
                              let modDate = attrs[.modificationDate] as? Date else { continue }

                        // Only re-infer if transcript was modified in last 15 seconds
                        guard Date().timeIntervalSince(modDate) < 15 else { break }

                        let status = Self.inferStatusFromFile(transcriptPath)
                        if status != .ready {
                            DispatchQueue.main.async {
                                if self?.sessions[sessionId]?.status == .ready {
                                    self?.sessions[sessionId]?.status = status
                                    sessionLog("Re-inferred status for \(sessionId): \(status.rawValue)")
                                }
                            }
                        }
                        break
                    }
                }
            }
        }
    }

    private struct DiscoveredProcess {
        let pid: Int
        let tty: String?
        let cwd: String
        let cpuPercent: Double
    }

    /// Scan running processes for claude/ducc instances (called on background thread)
    private static func scanProcessList() -> [DiscoveredProcess] {
        // Use a single shell command to get PID, TTY, %CPU for all claude processes
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "ps -eo pid,tty,pcpu,command | grep '/claude' | grep -v grep | grep -v vibecode-bridge | grep -v claude-go | grep -E '\\-\\-settings|\\-\\-dangerously|\\-\\-allow'"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return [] }

        var results: [DiscoveredProcess] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 3, let pid = Int(parts[0]) else { continue }
            guard kill(pid_t(pid), 0) == 0 else { continue }

            let tty = String(parts[1])
            let cpu = Double(parts[2]) ?? 0
            results.append(DiscoveredProcess(pid: pid, tty: tty != "??" ? tty : nil, cwd: "~", cpuPercent: cpu))
        }

        // Batch cwd lookup: single lsof call for all PIDs
        if !results.isEmpty {
            let pids = results.map { "\($0.pid)" }.joined(separator: ",")
            let cwdMap = batchGetCwd(pids: pids)
            results = results.map { proc in
                DiscoveredProcess(pid: proc.pid, tty: proc.tty, cwd: cwdMap[proc.pid] ?? "~", cpuPercent: proc.cpuPercent)
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
        // Mark sessions that receive real IPC events (not transcript) as having active hooks
        if message.source != "transcript", let session = sessions[message.sessionId] {
            if !session.hasActiveHooks {
                session.hasActiveHooks = true
                // Stop transcript watching for this session — hooks are working
                if session.isTranscriptWatching {
                    session.isTranscriptWatching = false
                    transcriptWatcher?.stopWatching(sessionId: message.sessionId)
                    sessionLog("Confirmed active hooks for \(message.sessionId), stopped transcript watcher")
                }
            }
        }

        // Skip transcript events for sessions with active hooks (dedup)
        if message.source == "transcript",
           sessions[message.sessionId]?.hasActiveHooks == true {
            return
        }

        // Auto-create session if we receive an event for an unknown session
        // (e.g. VibeCode was restarted while sessions were already running)
        if message.eventType != .sessionEnd {
            ensureSession(for: message)
        }

        // Clear stale pending permissions when session moves on.
        // If the user answered in the terminal (not via VibeCode), the pending permission
        // was never resolved through our callback. Only events that PROVE Claude has moved
        // past the permission request should trigger clearing:
        // - PostToolUse/PostToolUseFailure: tool finished (user must have approved in terminal)
        // - Stop: Claude finished responding entirely
        // - UserPromptSubmit: user sent a new message
        // - SessionStart: session restarted
        // Do NOT clear on PreToolUse/SubagentStart etc. — these can race with PermissionRequest.
        let clearEvents: Set<HookEventType> = [.postToolUse, .postToolUseFailure, .stop, .userPromptSubmit, .sessionStart]
        if clearEvents.contains(message.eventType) {
            if let session = sessions[message.sessionId], !session.pendingPermissions.isEmpty {
                sessionLog("Clearing \(session.pendingPermissions.count) stale pending permissions for session \(message.sessionId) (triggered by \(message.eventType.rawValue))")
                // Unblock any bridge processes still waiting by sending a deny response
                for perm in session.pendingPermissions {
                    if let callback = permissionCallbacks.removeValue(forKey: perm.id) {
                        sessionLog("Releasing dangling bridge for request \(perm.id)")
                        callback(IPCResponse(id: perm.id, decision: "deny", reason: "Answered in terminal"))
                    }
                }
                session.pendingPermissions.removeAll()
                // Don't set status here — let the event handler below set the correct state
                // (e.g. stop → ready, userPromptSubmit → thinking, postToolUse → thinking)
            }
        }

        switch message.eventType {
        case .sessionStart:
            // If ensureSession already upgraded a process- placeholder, preserve its PID/TTY
            if let existing = sessions[message.sessionId], existing.pid != nil {
                existing.status = .ready
                existing.tty = message.tty ?? existing.tty
                sessionLog("SessionStart: reused existing session \(message.sessionId) with PID \(existing.pid ?? -1)")
            } else {
                // Clean up any process- placeholder that matches this TTY
                if let tty = message.tty,
                   let (placeholderId, placeholder) = sessions.first(where: {
                       $0.key.hasPrefix("process-") && $0.value.tty == tty
                   }) {
                    sessions.removeValue(forKey: placeholderId)
                    placeholder.tty = tty
                    placeholder.status = .ready
                    sessions[message.sessionId] = placeholder
                    sessionLog("SessionStart: upgraded placeholder \(placeholderId) to \(message.sessionId)")
                } else {
                    let session = ClaudeSession(id: message.sessionId, cwd: message.cwd ?? "~")
                    session.tty = message.tty
                    sessions[message.sessionId] = session
                }
            }
            // Reset task state for new session
            sessions[message.sessionId]?.tasks.removeAll()
            sessions[message.sessionId]?.nextTaskId = 1
            CrashReporter.shared.addBreadcrumb(category: "session", message: "Session started: \(message.sessionId)")

        case .sessionEnd:
            sessions[message.sessionId]?.status = .ended
            if sessions[message.sessionId]?.isTranscriptWatching == true {
                transcriptWatcher?.stopWatching(sessionId: message.sessionId)
                sessions[message.sessionId]?.isTranscriptWatching = false
            }
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

            // Task progress interception
            if let toolName = message.toolName, let toolInput = message.toolInput {
                if toolName == "TaskCreate" {
                    handleTaskCreate(sessionId: message.sessionId, toolInput: toolInput)
                } else if toolName == "TaskUpdate" {
                    handleTaskUpdate(sessionId: message.sessionId, toolInput: toolInput)
                }
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
            // Don't set to ready if subagents are still running
            if let count = sessions[message.sessionId]?.subagentCount, count > 0 {
                sessions[message.sessionId]?.status = .thinking
            } else {
                sessions[message.sessionId]?.status = .ready
            }
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
            // If session shows ready but agents are starting, it's actually working
            if sessions[message.sessionId]?.status == .ready {
                sessions[message.sessionId]?.status = .thinking
            }
            sessions[message.sessionId]?.lastActivity = Date()

        case .subagentStop:
            if let count = sessions[message.sessionId]?.subagentCount, count > 0 {
                sessions[message.sessionId]?.subagentCount -= 1
            }
            sessions[message.sessionId]?.lastActivity = Date()

        case .preCompact:
            sessions[message.sessionId]?.status = .compacting

        case .postCompact:
            // After compaction, Claude continues working — not idle
            sessions[message.sessionId]?.status = .thinking

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
                // After approval, Claude continues executing — set to thinking
                // After deny, Claude stops the tool — set to ready
                if decision == "deny" {
                    session.status = .ready
                } else {
                    session.status = .thinking
                }
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
                // After answering a question, Claude continues working
                session.status = .thinking
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

    // MARK: - Task Progress Tracking

    private func handleTaskCreate(sessionId: String, toolInput: [String: AnyCodableValue]) {
        guard let session = sessions[sessionId] else { return }
        let subject = toolInput["subject"]?.stringValue ?? "Unknown task"
        let activeForm = toolInput["activeForm"]?.stringValue

        let taskId = String(session.nextTaskId)
        session.nextTaskId += 1

        let task = TaskItem(id: taskId, subject: subject, activeForm: activeForm)
        session.tasks[taskId] = task
        sessionLog("TaskCreate: session=\(sessionId) id=\(taskId) subject=\(subject)")
    }

    private func handleTaskUpdate(sessionId: String, toolInput: [String: AnyCodableValue]) {
        guard let session = sessions[sessionId] else { return }
        guard let taskId = toolInput["taskId"]?.stringValue else { return }

        // Handle unknown task (VibeCode may have missed creates after restart)
        if session.tasks[taskId] == nil {
            let placeholder = TaskItem(id: taskId, subject: "Task #\(taskId)")
            session.tasks[taskId] = placeholder
            if let idNum = Int(taskId) {
                session.nextTaskId = max(session.nextTaskId, idNum + 1)
            }
            sessionLog("TaskUpdate: created placeholder for unknown task \(taskId)")
        }

        if let statusStr = toolInput["status"]?.stringValue {
            switch statusStr {
            case "in_progress": session.tasks[taskId]?.status = .inProgress
            case "completed": session.tasks[taskId]?.status = .completed
            case "deleted": session.tasks[taskId]?.status = .deleted
            case "pending": session.tasks[taskId]?.status = .pending
            default: break
            }
        }

        if let newSubject = toolInput["subject"]?.stringValue {
            session.tasks[taskId]?.subject = newSubject
        }
        if let newActiveForm = toolInput["activeForm"]?.stringValue {
            session.tasks[taskId]?.activeForm = newActiveForm
        }

        sessionLog("TaskUpdate: session=\(sessionId) id=\(taskId) status=\(toolInput["status"]?.stringValue ?? "?")")
    }

    // MARK: - Transcript Path Discovery

    /// Find the transcript JSONL file for a given session
    private func findTranscriptPath(sessionId: String, cwd: String) -> String? {
        let fm = FileManager.default
        let encodedDir = VibeCodeConstants.encodedProjectDir(for: cwd)

        // Fast path: construct path directly from cwd
        for basePath in VibeCodeConstants.allProjectsPaths {
            let directPath = "\(basePath)/\(encodedDir)/\(sessionId).jsonl"
            if fm.fileExists(atPath: directPath) {
                return directPath
            }
        }

        // Slow path: scan all project directories
        for basePath in VibeCodeConstants.allProjectsPaths {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: basePath) else { continue }
            for dir in projectDirs {
                let path = "\(basePath)/\(dir)/\(sessionId).jsonl"
                if fm.fileExists(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    /// Get file size in bytes, returns 0 if file doesn't exist
    private static func fileSize(at path: String) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else { return 0 }
        return size
    }

    // MARK: - Transcript Parsing

    /// Infer session status from transcript: if last assistant message ends with tool_use, it's thinking
    private static func inferStatusFromTranscript(sessionId: String) -> SessionStatus {
        // Find transcript file across all project directories
        for basePath in VibeCodeConstants.allProjectsPaths {
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: basePath) else { continue }
            for dir in projectDirs {
                let transcriptPath = "\(basePath)/\(dir)/\(sessionId).jsonl"
                if FileManager.default.fileExists(atPath: transcriptPath) {
                    return inferStatusFromFile(transcriptPath)
                }
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
