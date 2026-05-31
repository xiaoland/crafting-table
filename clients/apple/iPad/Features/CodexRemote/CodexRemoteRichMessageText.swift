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
                    CodexRemoteMarkdownBlockView(text: markdown, isUserMessage: isUserMessage)
                        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
                case let .code(language, code):
                    CodexRemoteCodeBlockView(language: language, code: code)
                case let .mermaid(source):
                    CodexRemoteMermaidBlockView(source: source)
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
    }

    let id: String
    let kind: Kind
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
