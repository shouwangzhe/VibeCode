import Foundation

enum VibeCodeConstants {
    static let socketPath = "/tmp/vibecode.sock"
    static let pidFilePath = "/tmp/vibecode.pid"
    static let bundleIdentifier = "com.vibecode.macos"
    static let appName = "VibeCode"
    static let claudeSettingsPath = NSHomeDirectory() + "/.claude/settings.json"
    static let claudeSessionsPath = NSHomeDirectory() + "/.claude/sessions"
    static let bridgeName = "vibecode-bridge"
    static let bridgeLauncherPath = NSHomeDirectory() + "/.vibecode/bin/vibecode-bridge"

    // Transcript project directories
    static let claudeProjectsPath = NSHomeDirectory() + "/.claude/projects"
    static let duccProjectsPath = NSHomeDirectory() + "/.ducc/projects"
    static var allProjectsPaths: [String] { [claudeProjectsPath, duccProjectsPath] }

    /// Encode a cwd path to the directory name format used by Claude Code transcript storage.
    /// Claude Code replaces all non-alphanumeric characters (/, _, spaces, etc.) with "-".
    /// e.g. "/Users/foo/my_project" -> "-Users-foo-my-project"
    static func encodedProjectDir(for cwd: String) -> String {
        var result = ""
        for char in cwd {
            if char.isLetter || char.isNumber {
                result.append(char)
            } else {
                result.append("-")
            }
        }
        return result
    }

    // Panel dimensions
    static let collapsedWidth: CGFloat = 194  // Match Vibe Island width
    static let collapsedHeight: CGFloat = 30  // Match menu bar height exactly
    static let expandedWidth: CGFloat = 360
    static let expandedMaxHeight: CGFloat = 240
    static let panelCornerRadius: CGFloat = 6
    static let nonNotchTopOffset: CGFloat = 4

    // Sentry
    static let sentryDSN = "https://placeholder@sentry.io/0"
}
