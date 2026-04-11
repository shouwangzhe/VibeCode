import SwiftUI

struct CollapsedView: View {
    let sessionManager: SessionManager

    private var activeSessions: [ClaudeSession] {
        sessionManager.sessions.values.filter { $0.status.isActive }.sorted { $0.startedAt < $1.startedAt }
    }

    private var needsAttention: Bool {
        activeSessions.contains { $0.status == .waitingForApproval || $0.status == .waitingForInput }
    }

    private var isProcessing: Bool {
        activeSessions.contains { $0.status == .thinking || $0.status == .runningTool }
    }

    private var currentMascotState: MascotState {
        guard !activeSessions.isEmpty else { return .idle }
        // Priority: approval > input > running > thinking > compacting > ready > ended
        if activeSessions.contains(where: { $0.status == .waitingForApproval }) { return .approval }
        if activeSessions.contains(where: { $0.status == .waitingForInput }) { return .input }
        if activeSessions.contains(where: { $0.status == .runningTool }) { return .running }
        if activeSessions.contains(where: { $0.status == .thinking }) { return .thinking }
        if activeSessions.contains(where: { $0.status == .compacting }) { return .compacting }
        if activeSessions.contains(where: { $0.status == .ready }) { return .ready }
        return .ended
    }

    /// Returns the session that matches the mascot's priority — same priority order,
    /// within same status pick the most recently active one
    private var highestPrioritySession: ClaudeSession {
        let priorityOrder: [SessionStatus] = [.waitingForApproval, .waitingForInput, .runningTool, .thinking, .compacting, .ready, .ended]
        for status in priorityOrder {
            let matching = activeSessions.filter { $0.status == status }
            if let best = matching.sorted(by: { $0.lastActivity > $1.lastActivity }).first {
                return best
            }
        }
        return activeSessions[0]
    }

    var body: some View {
        HStack(spacing: 6) {
            // Pixel mascot animation
            PixelMascotView(state: currentMascotState)
                .frame(width: 22, height: 22)

            if activeSessions.isEmpty {
                Text("VibeCode")
                    .font(Font(NSFont.menuBarFont(ofSize: 0)))
                    .foregroundColor(.white.opacity(0.85))
            } else {
                // Show the session matching the mascot's priority state
                let session = highestPrioritySession
                let displayText = getDisplayText(for: session)

                Text(displayText)
                    .font(Font(NSFont.menuBarFont(ofSize: 0)))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                if needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 0)
        .frame(height: VibeCodeConstants.collapsedHeight - 2)
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        if needsAttention { return .yellow }
        if isProcessing { return .cyan }
        if !activeSessions.isEmpty { return .green }
        return .gray
    }

    private func getDisplayText(for session: ClaudeSession) -> String {
        let count = activeSessions.count
        let countSuffix = count > 1 ? " [\(count)]" : ""

        switch session.status {
        case .runningTool:
            if let operation = session.currentOperation {
                return operation + countSuffix
            }
            if let tool = session.currentTool {
                return tool + countSuffix
            }
            return "Running tool..." + countSuffix

        case .thinking:
            if let prompt = session.lastUserPrompt {
                return truncateForDisplay(prompt) + countSuffix
            }
            return "Thinking — " + session.projectName + countSuffix

        case .waitingForApproval:
            if let perm = session.pendingPermissions.last {
                let toolInfo = perm.toolName
                if let input = perm.toolInput,
                   let cmd = input["command"]?.stringValue {
                    return "Approve: \(toolInfo) — \(truncateForDisplay(cmd))" + countSuffix
                }
                return "Approve: \(toolInfo)" + countSuffix
            }
            return "Needs approval" + countSuffix

        case .waitingForInput:
            return "Waiting for input" + countSuffix

        case .compacting:
            return "Compacting context..." + countSuffix

        case .ready:
            return "\u{2713} " + session.projectName + countSuffix

        case .ended:
            return "Ended" + countSuffix
        }
    }

    private func truncateForDisplay(_ text: String, maxLength: Int = 60) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
}
