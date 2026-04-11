import Foundation
import ServiceManagement

/// Manages launch at login functionality using SMAppService (macOS 13+)
class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private let service = SMAppService.mainApp

    private init() {}

    /// Check if launch at login is enabled
    var isEnabled: Bool {
        service.status == .enabled
    }

    /// Toggle launch at login
    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }

    /// Enable launch at login
    func enable() throws {
        guard service.status != .enabled else { return }
        try service.register()
    }

    /// Disable launch at login
    func disable() throws {
        guard service.status == .enabled else { return }
        try service.unregister()
    }

    /// Get current status
    var statusDescription: String {
        switch service.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Disabled"
        case .notFound:
            return "Not Found"
        case .requiresApproval:
            return "Requires Approval"
        @unknown default:
            return "Unknown"
        }
    }
}
