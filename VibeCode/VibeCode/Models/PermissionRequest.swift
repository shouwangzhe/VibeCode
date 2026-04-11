import Foundation

struct PermissionRequestModel: Identifiable {
    let id: String
    let sessionId: String
    let toolName: String
    let toolInput: [String: AnyCodableValue]?
    let timestamp: Date

    var displayDescription: String {
        guard let input = toolInput else { return toolName }
        if let command = input["command"]?.stringValue {
            return "\(toolName): \(command)"
        }
        if let filePath = input["file_path"]?.stringValue {
            return "\(toolName): \(filePath)"
        }
        return toolName
    }
}
