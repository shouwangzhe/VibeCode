import SwiftUI

struct WritePreviewView: View {
    let toolInput: [String: AnyCodableValue]?

    private var filePath: String {
        toolInput?["file_path"]?.stringValue ?? "unknown"
    }

    private var content: String {
        toolInput?["content"]?.stringValue ?? ""
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    private var previewLines: [String] {
        let lines = content.components(separatedBy: "\n")
        return Array(lines.prefix(10))
    }

    private var totalLines: Int {
        content.components(separatedBy: "\n").count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // File path header
            HStack(spacing: 4) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text(fileName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Text("Write")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Text(filePath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.middle)

            // Content preview
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(previewLines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                                .frame(width: 20, alignment: .trailing)
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))

            if totalLines > 10 {
                Text("... \(totalLines - 10) more lines")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}
