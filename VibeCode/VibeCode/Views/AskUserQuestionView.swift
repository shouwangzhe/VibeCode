import SwiftUI

/// Renders AskUserQuestion options from Claude Code
/// tool_input format: { "questions": [{ "question": "...", "header": "...", "options": [{ "label": "...", "description": "..." }], "multiSelect": false }] }
struct AskUserQuestionView: View {
    let permission: PermissionRequestModel
    let onSubmit: (String, [String: AnyCodableValue]) -> Void

    @State private var answers: [Int: Set<Int>] = [:]  // questionIndex -> selected option indices
    @State private var otherSelected: Set<Int> = []      // questionIndices where "Other" is chosen
    @State private var otherTexts: [Int: String] = [:]   // questionIndex -> custom text input

    private var questions: [[String: AnyCodableValue]] {
        guard let input = permission.toolInput,
              let questionsValue = input["questions"],
              case .array(let arr) = questionsValue else {
            return []
        }
        return arr.compactMap { item -> [String: AnyCodableValue]? in
            if case .dictionary(let dict) = item { return dict }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                Text("Claude's Questions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("(\(questions.count))")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan.opacity(0.7))
            }

            ForEach(Array(questions.enumerated()), id: \.offset) { qIndex, question in
                questionView(index: qIndex, question: question)
            }

            // Submit button
            Button(action: submitAnswers) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                    Text("Submit")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(allAnswered ? .green : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(allAnswered ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(!allAnswered)
        }
    }

    @ViewBuilder
    private func questionView(index: Int, question: [String: AnyCodableValue]) -> some View {
        let questionText = question["question"]?.stringValue ?? ""
        let header = question["header"]?.stringValue
        let isMultiSelect: Bool = {
            if case .bool(let b) = question["multiSelect"] { return b }
            return false
        }()
        let options: [[String: AnyCodableValue]] = {
            guard case .array(let arr) = question["options"] else { return [] }
            return arr.compactMap { item in
                if case .dictionary(let dict) = item { return dict }
                return nil
            }
        }()

        VStack(alignment: .leading, spacing: 4) {
            if let h = header {
                Text(h)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
            }

            Text(questionText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)

            if isMultiSelect {
                Text("multi-select")
                    .font(.system(size: 9))
                    .foregroundColor(.orange.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.15)))
            }

            // Option buttons
            FlowLayout(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.offset) { optIndex, option in
                    let label = option["label"]?.stringValue ?? "Option \(optIndex)"
                    let isSelected = answers[index]?.contains(optIndex) ?? false

                    Button(action: {
                        toggleOption(questionIndex: index, optionIndex: optIndex, multiSelect: isMultiSelect)
                    }) {
                        Text(label)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // "Other" button
                let isOtherSelected = otherSelected.contains(index)
                Button(action: {
                    toggleOther(questionIndex: index, multiSelect: isMultiSelect)
                }) {
                    Text("Other")
                        .font(.system(size: 10, weight: isOtherSelected ? .semibold : .regular))
                        .foregroundColor(isOtherSelected ? .white : .white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isOtherSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isOtherSelected ? Color.orange.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Free-text input when "Other" is selected
            if otherSelected.contains(index) {
                TextField("Type your answer...", text: Binding(
                    get: { otherTexts[index] ?? "" },
                    set: { otherTexts[index] = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func toggleOption(questionIndex: Int, optionIndex: Int, multiSelect: Bool) {
        if multiSelect {
            var current = answers[questionIndex] ?? []
            if current.contains(optionIndex) {
                current.remove(optionIndex)
            } else {
                current.insert(optionIndex)
            }
            answers[questionIndex] = current
        } else {
            answers[questionIndex] = [optionIndex]
            // Deselect "Other" when picking a preset option in single-select mode
            otherSelected.remove(questionIndex)
            otherTexts.removeValue(forKey: questionIndex)
        }
    }

    private func toggleOther(questionIndex: Int, multiSelect: Bool) {
        if otherSelected.contains(questionIndex) {
            otherSelected.remove(questionIndex)
            otherTexts.removeValue(forKey: questionIndex)
        } else {
            otherSelected.insert(questionIndex)
            if !multiSelect {
                // Deselect preset options in single-select mode
                answers.removeValue(forKey: questionIndex)
            }
        }
    }

    private var allAnswered: Bool {
        for i in 0..<questions.count {
            let hasPresetAnswer = answers[i] != nil && !answers[i]!.isEmpty
            let hasOtherAnswer = otherSelected.contains(i) && !(otherTexts[i] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            if !hasPresetAnswer && !hasOtherAnswer {
                return false
            }
        }
        return !questions.isEmpty
    }

    private func submitAnswers() {
        // Build the response in Claude Code's expected format
        var result: [String: AnyCodableValue] = [:]

        for (qIndex, question) in questions.enumerated() {
            let options: [[String: AnyCodableValue]] = {
                guard case .array(let arr) = question["options"] else { return [] }
                return arr.compactMap { if case .dictionary(let d) = $0 { return d }; return nil }
            }()
            let isMultiSelect: Bool = {
                if case .bool(let b) = question["multiSelect"] { return b }
                return false
            }()
            let questionText = question["question"]?.stringValue ?? "q\(qIndex)"

            let hasOther = otherSelected.contains(qIndex)
            let otherText = (otherTexts[qIndex] ?? "").trimmingCharacters(in: .whitespaces)
            let selected = answers[qIndex] ?? []

            if isMultiSelect {
                var selectedValues: [AnyCodableValue] = selected.sorted().compactMap { idx in
                    guard idx < options.count else { return nil }
                    return options[idx]["label"].map { $0 } ?? .string("Option \(idx)")
                }
                if hasOther && !otherText.isEmpty {
                    selectedValues.append(.string(otherText))
                }
                result[questionText] = .array(selectedValues)
            } else if hasOther && !otherText.isEmpty {
                // Single-select with "Other" free text
                result[questionText] = .string(otherText)
            } else if let idx = selected.first, idx < options.count {
                let label = options[idx]["label"]?.stringValue ?? "Option \(idx)"
                result[questionText] = .string(label)
            }
        }

        onSubmit(permission.id, ["answers": .dictionary(result)])
    }
}

/// Simple flow layout for option buttons
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                totalWidth = max(totalWidth, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, x - spacing)

        return CGSize(width: max(totalWidth, 0), height: max(y + rowHeight, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        let maxX = bounds.maxX > bounds.minX ? bounds.maxX : bounds.minX + 300

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
