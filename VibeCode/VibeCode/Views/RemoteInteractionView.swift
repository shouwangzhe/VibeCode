import SwiftUI

/// Shows when a remote Claude Code session needs terminal interaction
struct RemoteInteractionView: View {
    let session: ClaudeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("Needs Interaction")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }

            Text(session.interactionReason ?? "Remote session needs your input")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 6) {
                if let sourceId = session.remoteSourceId,
                   let sshCmd = RemoteSourceManager.shared?.sshCommandForSource(id: sourceId),
                   !sshCmd.isEmpty {
                    Button(action: { openTerminal(command: sshCmd) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 10))
                            Text("Open Terminal")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.cyan.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Set SSH command in Remote Source settings")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
        }
    }

    private func openTerminal(command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
