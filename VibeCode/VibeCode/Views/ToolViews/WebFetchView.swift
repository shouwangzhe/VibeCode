import SwiftUI

struct WebFetchView: View {
    let toolInput: [String: AnyCodableValue]?
    let isSearch: Bool

    private var url: String? {
        toolInput?["url"]?.stringValue
    }

    private var query: String? {
        toolInput?["query"]?.stringValue
    }

    private var prompt: String? {
        toolInput?["prompt"]?.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: isSearch ? "magnifyingglass" : "globe")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                Text(isSearch ? "WebSearch" : "WebFetch")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.purple)
                Spacer()
            }

            if let url = url {
                Text(url)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.9))
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if let query = query {
                Text(query)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }

            if let prompt = prompt {
                Text(prompt)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
        }
    }
}
