import Foundation

struct SoundPack: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let author: String
    /// Maps event key ("sessionStart", "sessionEnd", "permissionRequest", "toolExecution") to sound filename
    let sounds: [String: String]

    var isBuiltIn: Bool {
        ["default", "minimal", "retro"].contains(id)
    }

    static let eventKeys = ["sessionStart", "sessionEnd", "responseComplete", "permissionRequest", "toolExecution"]
}
