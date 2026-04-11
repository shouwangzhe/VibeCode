import Foundation

// MARK: - Hook Event Types

public enum HookEventType: String, Codable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case permissionRequest = "PermissionRequest"
    case notification = "Notification"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
}

// MARK: - Hook Payload (from Claude Code stdin)

public struct HookInput: Codable {
    public let sessionId: String?
    public let transcriptPath: String?
    public let cwd: String?
    public let hookEventName: String?
    public let toolName: String?
    public let toolInput: [String: AnyCodableValue]?
    public let prompt: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case prompt
    }
}

// MARK: - IPC Message (over Unix socket)

public struct IPCMessage: Codable {
    public let id: String
    public let eventType: HookEventType
    public let source: String
    public let sessionId: String
    public let cwd: String?
    public let toolName: String?
    public let toolInput: [String: AnyCodableValue]?
    public let prompt: String?
    public let transcriptPath: String?
    public let tty: String?
    public let timestamp: Double

    public init(id: String, eventType: HookEventType, source: String, sessionId: String, cwd: String?, toolName: String?, toolInput: [String: AnyCodableValue]?, prompt: String?, transcriptPath: String? = nil, tty: String? = nil, timestamp: Double) {
        self.id = id; self.eventType = eventType; self.source = source; self.sessionId = sessionId
        self.cwd = cwd; self.toolName = toolName; self.toolInput = toolInput; self.prompt = prompt; self.transcriptPath = transcriptPath; self.tty = tty; self.timestamp = timestamp
    }
}

// MARK: - IPC Response (for permission requests)

public struct IPCResponse: Codable {
    public let id: String
    public let decision: String? // "allow", "deny", "always_allow", "bypass"
    public let reason: String?
    public let updatedInput: [String: AnyCodableValue]?

    public init(id: String, decision: String?, reason: String?, updatedInput: [String: AnyCodableValue]? = nil) {
        self.id = id; self.decision = decision; self.reason = reason; self.updatedInput = updatedInput
    }
}
