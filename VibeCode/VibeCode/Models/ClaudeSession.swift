import Foundation

enum SessionStatus: String {
    case ready = "Ready"
    case thinking = "Thinking"
    case runningTool = "Running tool"
    case waitingForApproval = "Needs approval"
    case waitingForInput = "Waiting for input"
    case compacting = "Compacting"
    case ended = "Ended"

    var color: String {
        switch self {
        case .ready: return "green"
        case .thinking, .runningTool: return "blue"
        case .waitingForApproval, .waitingForInput: return "yellow"
        case .compacting: return "orange"
        case .ended: return "gray"
        }
    }

    var isActive: Bool {
        self != .ended
    }
}

enum TerminalApp: String {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
    case warp = "Warp"
    case vscode = "VS Code"
}

@Observable
class ClaudeSession: Identifiable {
    let id: String
    let cwd: String
    let startedAt: Date
    var status: SessionStatus
    var currentTool: String?
    var currentToolInput: [String: AnyCodableValue]?
    var lastUserPrompt: String?
    var lastActivity: Date
    var subagentCount: Int = 0
    var pid: Int?
    var tty: String?
    var terminalApp: TerminalApp?
    var pendingPermissions: [PermissionRequestModel] = []
    var isRemote: Bool = false
    var remoteSourceId: UUID?
    var needsInteraction: Bool = false
    var interactionReason: String?
    var lastToolOutput: String?
    var lastAssistantResponse: String?
    var sessionName: String?

    var projectName: String {
        let dir = (cwd as NSString).lastPathComponent
        if let name = sessionName, !name.isEmpty {
            return "\(dir) · \(name)"
        }
        return dir
    }

    var currentOperation: String? {
        if let tool = currentTool {
            // Extract meaningful input from tool
            if let input = currentToolInput {
                let inputText = extractToolInputText(from: input)
                return "\(tool): \(inputText)"
            }
            return tool
        }
        return nil
    }

    private func extractToolInputText(from input: [String: AnyCodableValue]) -> String {
        // Try common input fields
        if let command = input["command"]?.stringValue {
            return truncate(command, maxLength: 60)
        }
        if let filePath = input["file_path"]?.stringValue {
            return truncate(filePath, maxLength: 60)
        }
        if let pattern = input["pattern"]?.stringValue {
            return truncate(pattern, maxLength: 60)
        }
        if let query = input["query"]?.stringValue {
            return truncate(query, maxLength: 60)
        }
        if let url = input["url"]?.stringValue {
            return truncate(url, maxLength: 60)
        }
        if let prompt = input["prompt"]?.stringValue {
            return truncate(prompt, maxLength: 60)
        }
        if let description = input["description"]?.stringValue {
            return truncate(description, maxLength: 60)
        }
        // Default: show first available value
        if let firstValue = input.values.first?.stringValue {
            return truncate(firstValue, maxLength: 60)
        }
        return ""
    }

    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return text.prefix(maxLength) + "..."
    }

    init(id: String, cwd: String) {
        self.id = id
        self.cwd = cwd
        self.startedAt = Date()
        self.status = .ready
        self.lastActivity = Date()
    }
}
