import Foundation

/// Installs/uninstalls Claude Code hooks in settings.json files
/// Supports both standard Claude Code (~/.claude/settings.json)
/// and Ducc (baidu-cc) settings files
struct HookInstaller {

    /// All settings file paths to manage hooks in
    private static var allSettingsPaths: [String] {
        var paths = [VibeCodeConstants.claudeSettingsPath]
        let fm = FileManager.default

        // Ducc config dir: CLAUDE_CONFIG_DIR=$HOME/.ducc
        let duccSettings = NSHomeDirectory() + "/.ducc/settings.json"
        if fm.fileExists(atPath: duccSettings) || fm.fileExists(atPath: NSHomeDirectory() + "/.ducc") {
            paths.append(duccSettings)
        }

        // Discover ducc extension settings files (~/.comate/extensions/baidu.baidu-cc-*/resources/settings.json)
        let comateExtDir = NSHomeDirectory() + "/.comate/extensions"
        if let contents = try? fm.contentsOfDirectory(atPath: comateExtDir) {
            for dir in contents where dir.hasPrefix("baidu.baidu-cc") {
                let settingsFile = comateExtDir + "/" + dir + "/resources/settings.json"
                if fm.fileExists(atPath: settingsFile) {
                    paths.append(settingsFile)
                }
            }
        }
        return paths
    }

    static func install() {
        let bridgePath = findBridgePath()

        // Build hook entry for vibecode-bridge
        let hookCommand: [String: Any] = [
            "type": "command",
            "command": bridgePath,
            "timeout": 86400
        ]
        let vibeCodeEntry: [String: Any] = ["hooks": [hookCommand], "matcher": ""]

        // All 13 Claude Code hook events
        let events = [
            "SessionStart", "SessionEnd",
            "PreToolUse", "PostToolUse", "PostToolUseFailure",
            "PermissionRequest",
            "UserPromptSubmit", "Stop",
            "SubagentStart", "SubagentStop",
            "PreCompact", "PostCompact",
            "Notification"
        ]

        for settingsPath in allSettingsPaths {
            installInFile(settingsPath, events: events, vibeCodeEntry: vibeCodeEntry)
        }
    }

    private static func installInFile(_ settingsPath: String, events: [String], vibeCodeEntry: [String: Any]) {
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var added = 0
        for event in events {
            var entries = hooks[event] as? [[String: Any]] ?? []

            let alreadyRegistered = entries.contains { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { hook in
                    guard let cmd = hook["command"] as? String else { return false }
                    return cmd.contains("vibecode-bridge")
                }
            }

            if !alreadyRegistered {
                entries.insert(vibeCodeEntry, at: 0)
                added += 1
            }

            hooks[event] = entries
        }
        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
            print("Hooks installed in \(settingsPath): \(added) new, \(events.count) total events")
        }
    }

    static func uninstall() {
        for settingsPath in allSettingsPaths {
            uninstallFromFile(settingsPath)
        }
    }

    private static func uninstallFromFile(_ settingsPath: String) {
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, value) in hooks {
            guard var entries = value as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { hook in
                    guard let cmd = hook["command"] as? String else { return false }
                    return cmd.contains("vibecode-bridge")
                }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        settings["hooks"] = hooks.isEmpty ? nil : hooks
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
