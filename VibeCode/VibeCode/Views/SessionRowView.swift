import SwiftUI

struct SessionRowView: View {
    let session: ClaudeSession
    let onReply: ((ClaudeSession, String) -> Void)?

    @State private var replyText: String = ""
    @State private var isReplying: Bool = false

    init(session: ClaudeSession, onReply: ((ClaudeSession, String) -> Void)? = nil) {
        self.session = session
        self.onReply = onReply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator (left)
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                // Content (right)
                VStack(alignment: .leading, spacing: 4) {
                    // Header: project name + session info
                    HStack {
                        Text(session.projectName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        if let tool = session.currentTool {
                            Text("· \(tool)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        // Terminal app badge
                        if let terminalApp = session.terminalApp {
                            Text(terminalApp.rawValue)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Time since last activity
                        Text(timeAgo(from: session.lastActivity))
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                            .foregroundColor(.white.opacity(0.4))

                        // Reply tag (only for Ready sessions)
                        if session.status == .ready, onReply != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { isReplying.toggle() }
                            }) {
                                Text("Reply")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isReplying ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                                    .cornerRadius(4)
                                    .foregroundColor(isReplying ? .cyan : .white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // User prompt (if available)
                    if let prompt = session.lastUserPrompt, !prompt.isEmpty {
                        Text("你: \(prompt)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // Task progress (if any tasks exist)
                    if session.taskSummary.total > 0 {
                        let summary = session.taskSummary
                        let task = session.currentTask
                        HStack(spacing: 4) {
                            if summary.completed == summary.total {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green.opacity(0.7))
                            } else {
                                Image(systemName: "circle.dotted")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan.opacity(0.7))
                            }

                            Text("\(summary.completed)/\(summary.total)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))

                            if let task = task {
                                Text(task.displayText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.cyan.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }

                    // Claude output: assistant response, last tool summary, or current operation
                    if session.status == .ready, let response = session.lastAssistantResponse, !response.isEmpty {
                        Text("AI: \(response)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    } else if session.status == .ready, let output = session.lastToolOutput, !output.isEmpty {
                        Text(output)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    } else if let operation = session.currentOperation {
                        Text(operation)
                            .font(.system(size: 12))
                            .foregroundColor(.cyan.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Inline reply bar (shown when Reply tag is tapped)
            if isReplying, onReply != nil {
                HStack(spacing: 6) {
                    TextField("Reply...", text: $replyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .onSubmit { sendReply() }

                    Button(action: sendReply) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(replyText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : .cyan)
                    }
                    .buttonStyle(.plain)
                    .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .padding(.top, 2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
    }

    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        onReply?(session, text)
        replyText = ""
        withAnimation(.easeInOut(duration: 0.15)) { isReplying = false }
    }

    private var statusColor: Color {
        switch session.status {
        case .ready: return .green
        case .thinking, .runningTool: return .cyan
        case .waitingForApproval, .waitingForInput: return .yellow
        case .compacting: return .orange
        case .ended: return .gray
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
}
