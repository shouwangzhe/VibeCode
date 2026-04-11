import SwiftUI

struct ReadFileView: View {
    let toolInput: [String: AnyCodableValue]?

    private var filePath: String {
        toolInput?["file_path"]?.stringValue ?? "unknown"
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    private var lineRange: String? {
        if let offset = toolInput?["offset"]?.stringValue,
           let limit = toolInput?["limit"]?.stringValue {
            return "lines \(offset)-\(Int(offset) ?? 0 + (Int(limit) ?? 0))"
        }
        if let offset = toolInput?["offset"] {
            if case .int(let v) = offset {
                if let limit = toolInput?["limit"], case .int(let l) = limit {
                    return "lines \(v)-\(v + l)"
                }
                return "from line \(v)"
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(filePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let range = lineRange {
                        Text("(\(range))")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            Text("Read")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
