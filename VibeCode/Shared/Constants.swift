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
