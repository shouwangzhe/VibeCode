import Foundation

/// Watches transcript JSONL files for sessions without active hooks (e.g. ducc v2.1.71).
/// Incrementally reads new lines, parses them into IPCMessage, and feeds them to SessionManager.handleEvent().
class TranscriptWatcher {
    private weak var sessionManager: SessionManager?
    private var watchers: [String: WatcherState] = [:]
    private let watcherQueue = DispatchQueue(label: "com.vibecode.transcript.watcher", qos: .utility)
    private let maxWatchers = 20

    private struct WatcherState {
        let sessionId: String
        let filePath: String
        var fileOffset: UInt64
        var partialLineBuffer: String = ""
        var source: DispatchSourceFileSystemObject?
        var fileDescriptor: Int32
        var lastReadTime: Date = .distantPast
        var debounceWorkItem: DispatchWorkItem?
    }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Public API

    func startWatching(sessionId: String, transcriptPath: String, initialOffset: UInt64 = 0) {
        watcherQueue.async { [weak self] in
            self?._startWatching(sessionId: sessionId, transcriptPath: transcriptPath, initialOffset: initialOffset)
        }
    }

    func stopWatching(sessionId: String) {
        watcherQueue.async { [weak self] in
            self?._stopWatching(sessionId: sessionId)
        }
    }

    func stopAll() {
        watcherQueue.async { [weak self] in
            guard let self else { return }
            for sessionId in Array(self.watchers.keys) {
                self._stopWatching(sessionId: sessionId)
            }
        }
    }

    // MARK: - Internal

    private func _startWatching(sessionId: String, transcriptPath: String, initialOffset: UInt64) {
        // Stop existing watcher if any
        _stopWatching(sessionId: sessionId)

        // Evict oldest watcher if at capacity
        if watchers.count >= maxWatchers {
            if let oldest = watchers.min(by: { $0.value.lastReadTime < $1.value.lastReadTime }) {
                sessionLog("Evicting watcher for \(oldest.key) (LRU)")
                _stopWatching(sessionId: oldest.key)
            }
        }

        let fd = open(transcriptPath, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else {
            sessionLog("Failed to open transcript for watching: \(transcriptPath)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: watcherQueue
        )

        var state = WatcherState(
            sessionId: sessionId,
            filePath: transcriptPath,
            fileOffset: initialOffset,
            fileDescriptor: fd
        )
        state.source = source

        source.setEventHandler { [weak self] in
            self?.handleFileChange(sessionId: sessionId)
        }

        source.setCancelHandler {
            close(fd)
        }

        watchers[sessionId] = state
        source.resume()
        sessionLog("Started transcript watching: \(sessionId) at offset \(initialOffset)")
    }

    private func _stopWatching(sessionId: String) {
        guard var state = watchers.removeValue(forKey: sessionId) else { return }
        state.debounceWorkItem?.cancel()
        state.source?.cancel()
        state.source = nil
        sessionLog("Stopped transcript watching: \(sessionId)")
    }

    private func handleFileChange(sessionId: String) {
        guard var state = watchers[sessionId] else { return }

        // Cancel pending debounced read
        state.debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.readIncrementally(sessionId: sessionId)
        }
        state.debounceWorkItem = workItem
        watchers[sessionId] = state

        watcherQueue.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
    }

    private func readIncrementally(sessionId: String) {
        guard var state = watchers[sessionId] else { return }
        guard let fh = FileHandle(forReadingAtPath: state.filePath) else { return }
        defer { fh.closeFile() }

        // Handle file truncation
        let currentSize = fh.seekToEndOfFile()
        if currentSize < state.fileOffset {
            state.fileOffset = 0
            state.partialLineBuffer = ""
        }

        fh.seek(toFileOffset: state.fileOffset)
        let newData = fh.readDataToEndOfFile()
        guard !newData.isEmpty else { return }

        guard var text = String(data: newData, encoding: .utf8) else { return }

        // Prepend partial line from last read
        if !state.partialLineBuffer.isEmpty {
            text = state.partialLineBuffer + text
            state.partialLineBuffer = ""
        }

        let lines = text.components(separatedBy: "\n")
        var messages: [IPCMessage] = []

        for (i, line) in lines.enumerated() {
            if i == lines.count - 1 {
                // Last element: partial line if non-empty
                if !line.isEmpty {
                    state.partialLineBuffer = line
                }
            } else {
                guard !line.isEmpty else { continue }
                messages.append(contentsOf: parseTranscriptLine(line, sessionId: sessionId))
            }
        }

        state.fileOffset = fh.offsetInFile - UInt64(state.partialLineBuffer.utf8.count)
        state.lastReadTime = Date()
        watchers[sessionId] = state

        if !messages.isEmpty {
            DispatchQueue.main.async { [weak self] in
                for msg in messages {
                    self?.sessionManager?.handleEvent(msg)
                }
            }
        }
    }

    // MARK: - JSONL Parsing

    private func parseTranscriptLine(_ line: String, sessionId: String) -> [IPCMessage] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return [] }

        let cwd = json["cwd"] as? String
        let timestamp = parseTimestamp(json["timestamp"])

        switch type {
        case "user":
            return parseUserEntry(json, sessionId: sessionId, cwd: cwd, timestamp: timestamp)
        case "assistant":
            return parseAssistantEntry(json, sessionId: sessionId, cwd: cwd, timestamp: timestamp)
        case "system":
            return parseSystemEntry(json, sessionId: sessionId, cwd: cwd, timestamp: timestamp)
        default:
            return []
        }
    }

    private func parseUserEntry(_ json: [String: Any], sessionId: String, cwd: String?, timestamp: Double) -> [IPCMessage] {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] else { return [] }

        // User prompt (string content) → UserPromptSubmit
        if let promptText = content as? String, !promptText.isEmpty {
            // Skip internal messages (XML tags, empty)
            if promptText.hasPrefix("<") { return [] }
            return [IPCMessage(
                id: UUID().uuidString, eventType: .userPromptSubmit, source: "transcript",
                sessionId: sessionId, cwd: cwd, toolName: nil, toolInput: nil,
                prompt: promptText, timestamp: timestamp
            )]
        }

        // Tool results (array content) → PostToolUse
        if let contentArray = content as? [[String: Any]] {
            var messages: [IPCMessage] = []
            for block in contentArray {
                if block["type"] as? String == "tool_result" {
                    let isError = block["is_error"] as? Bool ?? false
                    messages.append(IPCMessage(
                        id: UUID().uuidString,
                        eventType: isError ? .postToolUseFailure : .postToolUse,
                        source: "transcript", sessionId: sessionId, cwd: cwd,
                        toolName: nil, toolInput: nil, prompt: nil, timestamp: timestamp
                    ))
                }
            }
            return messages
        }
        return []
    }

    private func parseAssistantEntry(_ json: [String: Any], sessionId: String, cwd: String?, timestamp: Double) -> [IPCMessage] {
        guard let message = json["message"] as? [String: Any],
              let contentArray = message["content"] as? [[String: Any]] else { return [] }

        // Only process final entries (stop_reason != null) to avoid duplicate streaming events
        guard message["stop_reason"] is String else { return [] }
        let stopReason = message["stop_reason"] as? String

        var messages: [IPCMessage] = []

        // tool_use blocks → PreToolUse
        for block in contentArray {
            if block["type"] as? String == "tool_use" {
                let toolName = block["name"] as? String
                var toolInput: [String: AnyCodableValue]? = nil
                if let rawInput = block["input"] as? [String: Any] {
                    toolInput = rawInput.mapValues { AnyCodableValue.from($0) }
                }
                messages.append(IPCMessage(
                    id: UUID().uuidString, eventType: .preToolUse, source: "transcript",
                    sessionId: sessionId, cwd: cwd, toolName: toolName, toolInput: toolInput,
                    prompt: nil, timestamp: timestamp
                ))
            }
        }

        // end_turn with no tool_use → Stop
        if stopReason == "end_turn" && !contentArray.contains(where: { $0["type"] as? String == "tool_use" }) {
            let textBlocks = contentArray.filter { $0["type"] as? String == "text" }
            let lastText = textBlocks.last?["text"] as? String
            messages.append(IPCMessage(
                id: UUID().uuidString, eventType: .stop, source: "transcript",
                sessionId: sessionId, cwd: cwd, toolName: nil, toolInput: nil,
                prompt: lastText, timestamp: timestamp
            ))
        }

        return messages
    }

    private func parseSystemEntry(_ json: [String: Any], sessionId: String, cwd: String?, timestamp: Double) -> [IPCMessage] {
        let subtype = json["subtype"] as? String

        switch subtype {
        case "compact_boundary":
            return [
                IPCMessage(id: UUID().uuidString, eventType: .preCompact, source: "transcript",
                           sessionId: sessionId, cwd: cwd, toolName: nil, toolInput: nil, prompt: nil, timestamp: timestamp),
                IPCMessage(id: UUID().uuidString, eventType: .postCompact, source: "transcript",
                           sessionId: sessionId, cwd: cwd, toolName: nil, toolInput: nil, prompt: nil, timestamp: timestamp)
            ]
        default:
            return []
        }
    }

    private func parseTimestamp(_ value: Any?) -> Double {
        if let ts = value as? Double { return ts }
        if let tsStr = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: tsStr) {
                return date.timeIntervalSince1970
            }
        }
        return Date().timeIntervalSince1970
    }

    private func sessionLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) [TranscriptWatcher] \(message)\n"
        if let data = line.data(using: .utf8),
           let fh = FileHandle(forWritingAtPath: "/tmp/vibecode-ipc.log") {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        }
    }
}
