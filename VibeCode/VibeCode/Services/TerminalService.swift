import AppKit
import Foundation

/// Jumps to the terminal window/tab running a Claude Code session
struct TerminalService {
    static func jumpToSession(_ session: ClaudeSession) {
        guard let pid = session.pid ?? findPid(sessionId: session.id) else {
            print("Cannot find PID for session \(session.id)")
            return
        }

        // Find the TTY for this PID
        guard let tty = findTTY(pid: pid) else {
            print("Cannot find TTY for PID \(pid)")
            return
        }

        // Try iTerm2 first, then Terminal.app
        if isAppRunning("iTerm2") {
            jumpToITerm2(tty: tty)
        } else if isAppRunning("Terminal") {
            jumpToTerminal(tty: tty)
        }
    }

    /// Send text input to a session's terminal and press Enter
    static func sendInput(to session: ClaudeSession, text: String) {
        // Prefer stored TTY, fallback to PID-based lookup
        let tty: String
        if let sessionTTY = session.tty {
            tty = sessionTTY
        } else if let pid = session.pid ?? findPid(sessionId: session.id),
                  let foundTTY = findTTY(pid: pid) {
            tty = foundTTY
        } else {
            print("Cannot find TTY for session \(session.id)")
            return
        }

        // Escape text for AppleScript
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        if isAppRunning("iTerm2") {
            sendToITerm2(tty: tty, text: escaped)
        } else if isAppRunning("Terminal") {
            sendToTerminalApp(tty: tty, text: escaped)
        }
    }

    private static func findPid(sessionId: String) -> Int? {
        let sessionsDir = VibeCodeConstants.claudeSessionsPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) else { return nil }

        for file in files where file.hasSuffix(".json") {
            let path = (sessionsDir as NSString).appendingPathComponent(file)
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sid = json["sessionId"] as? String, sid == sessionId,
                  let pid = json["pid"] as? Int else { continue }
            return pid
        }
        return nil
    }

    private static func findTTY(pid: Int) -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "tty=", "-p", "\(pid)"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isAppRunning(_ name: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.localizedName == name }
    }

    private static func jumpToITerm2(tty: String) {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s contains "\(tty)" then
                            select w
                            tell t to select
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func jumpToTerminal(tty: String) {
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t contains "\(tty)" then
                        set selected tab of w to t
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
        }
    }

    private static func sendToITerm2(tty: String, text: String) {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s contains "\(tty)" then
                            select w
                            tell t to select
                            tell s to write text "\(text)"
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func sendToTerminalApp(tty: String, text: String) {
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t contains "\(tty)" then
                        set selected tab of w to t
                        do script "\(text)" in t
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }
}
