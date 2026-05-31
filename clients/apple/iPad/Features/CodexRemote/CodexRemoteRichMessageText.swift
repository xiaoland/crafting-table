import Markdown
import SwiftUI

struct CodexRemoteRichMessageText: View {
    let text: String
    let isUserMessage: Bool

    private var blocks: [CodexRemoteMessageContentBlock] {
        CodexRemoteMessageContentParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                switch block.kind {
                case .markdown(let markdown):
                    CodexRemoteInlineMarkdownText(text: markdown)
                        .font(.body)
                        .foregroundStyle(isUserMessage ? .white : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
                case let .code(language, code):
                    CodexRemoteCodeBlockView(language: language, code: code)
                case let .mermaid(source):
                    CodexRemoteMermaidBlockView(source: source)
                case let .orderedList(startIndex, items):
                    CodexRemoteListBlockView(
                        kind: .ordered(startIndex: startIndex),
                        items: items,
                        isUserMessage: isUserMessage
                    )
                case let .unorderedList(items):
                    CodexRemoteListBlockView(
                        kind: .unordered,
                        items: items,
                        isUserMessage: isUserMessage
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
    }
}

private struct CodexRemoteMessageContentBlock: Identifiable {
    enum Kind {
        case markdown(String)
        case code(language: String?, code: String)
        case mermaid(String)
        case orderedList(startIndex: Int, items: [CodexRemoteMessageListItem])
        case unorderedList(items: [CodexRemoteMessageListItem])
    }

    let id: String
    let kind: Kind
}

private struct CodexRemoteMessageListItem: Identifiable {
    let id: String
    let markdown: String
}

private enum CodexRemoteMessageContentParser {
    static func parse(_ text: String) -> [CodexRemoteMessageContentBlock] {
        let document = Document(parsing: text)
        let children = Array(document.children)
        let hasUnclosedFence = sourceHasUnclosedFence(text)
        var blocks: [CodexRemoteMessageContentBlock] = []
        var pendingMarkdown = ""

        func flushMarkdown() {
            let trimmed = pendingMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                pendingMarkdown = ""
                return
            }

            blocks.append(
                CodexRemoteMessageContentBlock(
                    id: "\(blocks.count)-markdown-\(trimmed.hashValue)",
                    kind: .markdown(trimmed)
                )
            )
            pendingMarkdown = ""
        }

        for (index, child) in children.enumerated() {
            if let codeBlock = child as? CodeBlock {
                flushMarkdown()

                let language = normalizedLanguage(codeBlock.language)
                let isLastChild = index == children.indices.last
                let shouldDeferMermaidRender = hasUnclosedFence && isLastChild
                let kind: CodexRemoteMessageContentBlock.Kind

                if language == "mermaid", shouldDeferMermaidRender == false {
                    kind = .mermaid(codeBlock.code)
                } else {
                    kind = .code(language: language, code: codeBlock.code)
                }

                blocks.append(
                    CodexRemoteMessageContentBlock(
                        id: "\(blocks.count)-code-\(language ?? "plain")-\(codeBlock.code.hashValue)",
                        kind: kind
                    )
                )
            } else if let orderedList = child as? OrderedList {
                flushMarkdown()

                let items = listItems(from: orderedList)
                blocks.append(
                    CodexRemoteMessageContentBlock(
                        id: "\(blocks.count)-ordered-list-\(orderedList.startIndex)-\(items.map(\.markdown).joined().hashValue)",
                        kind: .orderedList(startIndex: Int(orderedList.startIndex), items: items)
                    )
                )
            } else if let unorderedList = child as? UnorderedList {
                flushMarkdown()

                let items = listItems(from: unorderedList)
                blocks.append(
                    CodexRemoteMessageContentBlock(
                        id: "\(blocks.count)-unordered-list-\(items.map(\.markdown).joined().hashValue)",
                        kind: .unorderedList(items: items)
                    )
                )
            } else {
                pendingMarkdown += child.format().trimmingCharacters(in: .newlines)
                pendingMarkdown += "\n\n"
            }
        }

        flushMarkdown()

        if blocks.isEmpty {
            return [
                CodexRemoteMessageContentBlock(
                    id: "0-markdown-empty",
                    kind: .markdown(text)
                )
            ]
        }

        return blocks
    }

    private static func normalizedLanguage(_ rawLanguage: String?) -> String? {
        guard let rawLanguage else {
            return nil
        }

        let trimmed = rawLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map { String($0).lowercased() }
    }

    private static func sourceHasUnclosedFence(_ source: String) -> Bool {
        var openFence: (marker: Character, count: Int)?

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmedPrefix = line.drop(while: { $0 == " " || $0 == "\t" })
            guard let marker = trimmedPrefix.first,
                  marker == "`" || marker == "~"
            else {
                continue
            }

            let count = trimmedPrefix.prefix(while: { $0 == marker }).count
            guard count >= 3 else {
                continue
            }

            if let currentOpenFence = openFence {
                if currentOpenFence.marker == marker, count >= currentOpenFence.count {
                    openFence = nil
                }
            } else {
                openFence = (marker, count)
            }
        }

        return openFence != nil
    }

    private static func listItems(from list: Markup) -> [CodexRemoteMessageListItem] {
        list.children
            .compactMap { $0 as? ListItem }
            .enumerated()
            .map { index, item in
                let markdown = item.children
                    .map { child in
                        if let paragraph = child as? Paragraph {
                            return paragraph.format().trimmingCharacters(in: .whitespacesAndNewlines)
                        }

                        return child.format().trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { $0.isEmpty == false }
                    .joined(separator: "\n")

                let itemText = markdown.isEmpty ? " " : markdown

                return CodexRemoteMessageListItem(
                    id: "\(index)-\(itemText.hashValue)",
                    markdown: itemText
                )
            }
    }
}

private struct CodexRemoteInlineMarkdownText: View {
    let text: String

    var body: some View {
        Text(renderedText)
    }

    private var renderedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )

        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct CodexRemoteListBlockView: View {
    enum Kind {
        case ordered(startIndex: Int)
        case unordered
    }

    let kind: Kind
    let items: [CodexRemoteMessageListItem]
    let isUserMessage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(marker(for: offset))
                        .font(.body)
                        .foregroundStyle(isUserMessage ? .white.opacity(0.78) : .secondary)
                        .frame(width: markerWidth, alignment: .trailing)

                    CodexRemoteInlineMarkdownText(text: item.markdown)
                        .font(.body)
                        .foregroundStyle(isUserMessage ? .white : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("codex-remote-list-block")
    }

    private var markerWidth: CGFloat {
        switch kind {
        case .ordered:
            return 30
        case .unordered:
            return 16
        }
    }

    private func marker(for offset: Int) -> String {
        switch kind {
        case .ordered(let startIndex):
            return "\(startIndex + offset)."
        case .unordered:
            return "•"
        }
    }
}

struct CodexRemoteCodeBlockView: View {
    let language: String?
    let code: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(languageLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    UIPasteboard.general.string = code
                    didCopy = true

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        didCopy = false
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(didCopy ? "Copied" : "Copy code")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .tertiarySystemBackground))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(CodexRemoteCodeHighlighter.highlight(code, language: language))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("codex-remote-code-block")
    }

    private var languageLabel: String {
        language?.isEmpty == false ? language! : "code"
    }
}

private enum CodexRemoteCodeHighlighter {
    static func highlight(_ code: String, language: String?) -> AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = .primary

        applyPatterns(to: &result, source: code, patterns: patterns(for: language))
        return result
    }

    private static func patterns(for language: String?) -> [(String, Color)] {
        let normalizedLanguage = language?.lowercased()
        let common = [
            (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, Color.secondary),
            (#"//.*|#.*|/\*[\s\S]*?\*/"#, Color.gray),
            (#"\b(?:true|false|null|nil|self|super)\b"#, Color.purple)
        ]

        switch normalizedLanguage {
        case "swift":
            return common + [
                (#"\b(?:actor|as|associatedtype|async|await|case|catch|class|defer|do|else|enum|extension|for|func|guard|if|import|in|init|let|private|protocol|public|return|static|struct|switch|throw|throws|try|typealias|var|while)\b"#, Color.blue)
            ]
        case "json":
            return [
                (#""[^"]+"\s*:"#, Color.blue),
                (#""(?:\\.|[^"\\])*""#, Color.secondary),
                (#"\b(?:true|false|null)\b"#, Color.purple),
                (#"-?\b\d+(?:\.\d+)?\b"#, Color.orange)
            ]
        case "bash", "sh", "zsh", "shell":
            return common + [
                (#"\b(?:cd|cp|curl|echo|export|find|git|grep|ls|mkdir|npm|rg|rm|sed|swift|xcodebuild)\b"#, Color.blue),
                (#"\$[A-Za-z_][A-Za-z0-9_]*"#, Color.purple)
            ]
        default:
            return common
        }
    }

    private static func applyPatterns(
        to attributedString: inout AttributedString,
        source: String,
        patterns: [(String, Color)]
    ) {
        for (pattern, color) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            regex.enumerateMatches(in: source, range: nsRange) { match, _, _ in
                guard let match,
                      let sourceRange = Range(match.range, in: source),
                      let lowerBound = AttributedString.Index(sourceRange.lowerBound, within: attributedString),
                      let upperBound = AttributedString.Index(sourceRange.upperBound, within: attributedString)
                else {
                    return
                }

                attributedString[lowerBound..<upperBound].foregroundColor = color
            }
        }
    }
}
