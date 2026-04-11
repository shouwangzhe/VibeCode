import SwiftUI

struct BashCommandView: View {
    let toolInput: [String: AnyCodableValue]?

    private var command: String {
        toolInput?["command"]?.stringValue ?? ""
    }

    private var description: String? {
        toolInput?["description"]?.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("Bash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
                Spacer()
                Button(action: copyCommand) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            if let desc = description {
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                Text(command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 80)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}
