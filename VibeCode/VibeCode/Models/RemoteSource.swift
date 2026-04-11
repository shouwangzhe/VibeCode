import Foundation

/// Represents a remote VibeCode agent running in a container/server
struct RemoteSource: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String        // e.g. "dev容器"
    var url: String         // e.g. "http://dev.lvpengbin.host:19876"
    var isEnabled: Bool
    var token: String?      // optional auth token
    var sshCommand: String? // e.g. "ssh -t dev.lvpengbin.host tmux attach -t claude"

    init(id: UUID = UUID(), name: String, url: String, isEnabled: Bool = true, token: String? = nil, sshCommand: String? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.token = token
        self.sshCommand = sshCommand
    }

    /// Base URL with trailing slash stripped
    var baseURL: String {
        url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
