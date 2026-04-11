import SwiftUI

struct ExpandedView: View {
    let sessionManager: SessionManager
    let hasNotch: Bool
    let onApprove: (String, String) -> Void
    let onQuestionSubmit: (String, [String: AnyCodableValue]) -> Void
    let onJumpToSession: (ClaudeSession) -> Void
    let onReplyToSession: (ClaudeSession, String) -> Void

    private var activeSessions: [ClaudeSession] {
        sessionManager.sessions.values
            .filter { $0.status.isActive }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var pendingPermissions: [PermissionRequestModel] {
        activeSessions.flatMap { $0.pendingPermissions }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("VibeCode")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(activeSessions.count) active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, hasNotch ? 40 : 8)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // AskUserQuestion (special permission request)
            if let question = pendingPermissions.first(where: { $0.toolName == "AskUserQuestion" }) {
                AskUserQuestionView(
                    permission: question,
                    onSubmit: onQuestionSubmit
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().background(Color.white.opacity(0.1))
            }
            // Regular permission requests
            else if let permission = pendingPermissions.first {
                PermissionApprovalView(
                    permission: permission,
                    onApprove: onApprove
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().background(Color.white.opacity(0.1))
            }

            // Session list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(activeSessions) { session in
                        SessionRowView(session: session, onReply: onReplyToSession)
                            .onTapGesture { onJumpToSession(session) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if activeSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No active sessions")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
