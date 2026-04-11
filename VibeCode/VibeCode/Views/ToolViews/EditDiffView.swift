import SwiftUI

struct EditDiffView: View {
    let toolInput: [String: AnyCodableValue]?

    private var filePath: String {
        toolInput?["file_path"]?.stringValue ?? "unknown"
    }

    private var oldString: String {
        toolInput?["old_string"]?.stringValue ?? ""
    }

    private var newString: String {
        toolInput?["new_string"]?.stringValue ?? ""
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // File path header
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text(fileName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Text("Edit")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Text(filePath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.middle)

            // Diff content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Removed lines
                    if !oldString.isEmpty {
                        ForEach(Array(oldString.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            HStack(spacing: 4) {
                                Text("-")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                                    .frame(width: 10)
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.red.opacity(0.9))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.1))
                        }
                    }

                    // Added lines
                    if !newString.isEmpty {
                        ForEach(Array(newString.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            HStack(spacing: 4) {
                                Text("+")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                    .frame(width: 10)
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.9))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.1))
                        }
                    }
                }
            }
            .frame(maxHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
