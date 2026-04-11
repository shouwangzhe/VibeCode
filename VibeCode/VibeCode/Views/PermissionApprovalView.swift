import SwiftUI

struct PermissionApprovalView: View {
    let permission: PermissionRequestModel
    let onApprove: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool info
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                Text("Permission Request")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
            }

            toolDetailView
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                )

            // Action buttons
            HStack(spacing: 6) {
                Button(action: { onApprove(permission.id, "deny") }) {
                    Text("Deny")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { onApprove(permission.id, "allow") }) {
                    Text("Allow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { onApprove(permission.id, "always_allow") }) {
                    Text("Always")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.cyan.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var toolDetailView: some View {
        switch permission.toolName {
        case "Bash":
            BashCommandView(toolInput: permission.toolInput)
        case "Edit":
            EditDiffView(toolInput: permission.toolInput)
        case "Write":
            WritePreviewView(toolInput: permission.toolInput)
        case "Read":
            ReadFileView(toolInput: permission.toolInput)
        case "WebFetch":
            WebFetchView(toolInput: permission.toolInput, isSearch: false)
        case "WebSearch":
            WebFetchView(toolInput: permission.toolInput, isSearch: true)
        default:
            Text(permission.displayDescription)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
    }
}
