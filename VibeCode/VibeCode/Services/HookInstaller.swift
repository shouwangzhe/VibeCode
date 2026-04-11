import Foundation

/// Installs/uninstalls Claude Code hooks in ~/.claude/settings.json
struct HookInstaller {
    static func install() {
        let bridgePath = findBridgePath()
        let settingsPath = VibeCodeConstants.claudeSettingsPath

        // Read existing settings
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Build hook entry
        let hookCommand: [String: Any] = [
            "type": "command",
            "command": bridgePath,
            "timeout": 86400
        ]
        let hookEntry: [[String: Any]] = [
            ["hooks": [hookCommand], "matcher": ""]
        ]

        // Events to hook
        let events = [
            "SessionStart", "SessionEnd",
            "PreToolUse", "PostToolUse", "PostToolUseFailure",
            "PermissionRequest",
            "UserPromptSubmit", "Stop",
            "SubagentStart", "SubagentStop",
            "PreCompact", "PostCompact",
            "Notification"
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            hooks[event] = hookEntry
        }
        settings["hooks"] = hooks

        // Write back
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
            print("Hooks installed successfully")
        }
    }

    static func uninstall() {
        let settingsPath = VibeCodeConstants.claudeSettingsPath
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        settings.removeValue(forKey: "hooks")
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private static func findBridgePath() -> String {
        // First check if running from app bundle
        if let bundlePath = Bundle.main.path(forAuxiliaryExecutable: VibeCodeConstants.bridgeName) {
            return bundlePath
        }
        // Fallback to launcher script path
        return VibeCodeConstants.bridgeLauncherPath
    }
}
