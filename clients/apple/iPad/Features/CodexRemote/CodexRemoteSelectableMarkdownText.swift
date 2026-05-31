import Foundation
import Markdown
import SwiftUI
import UIKit

struct CodexRemoteSelectableMarkdownText: UIViewRepresentable {
    let text: String
    let isUserMessage: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = CodexRemoteMarkdownAttributedStringRenderer.render(
            text,
            isUserMessage: isUserMessage
        )
        textView.linkTextAttributes = [
            .foregroundColor: isUserMessage ? UIColor.white : UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else {
            return nil
        }

        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(fittingSize.height))
    }
}

private enum CodexRemoteMarkdownAttributedStringRenderer {
    static func render(_ source: String, isUserMessage: Bool) -> NSAttributedString {
        let document = Document(parsing: source)
        var renderer = Renderer(isUserMessage: isUserMessage)
        renderer.renderBlocks(document.children)
        return renderer.finalize()
    }

    private struct Renderer {
        private struct InlineStyle {
            var font: UIFont
            var color: UIColor
            var isBold = false
            var isItalic = false
            var isStrikethrough = false
            var link: URL?
        }

        private let isUserMessage: Bool
        private let textColor: UIColor
        private let secondaryTextColor: UIColor
        private let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        private let monospaceFont = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize * 0.92,
            weight: .regular
        )
        private var storage = NSMutableAttributedString()

        init(isUserMessage: Bool) {
            self.isUserMessage = isUserMessage
            textColor = isUserMessage ? .white : .label
            secondaryTextColor = isUserMessage ? UIColor.white.withAlphaComponent(0.78) : .secondaryLabel
        }

        mutating func finalize() -> NSAttributedString {
            trimTrailingNewlines()
            return storage
        }

        mutating func renderBlocks(_ blocks: MarkupChildren) {
            for block in blocks {
                renderBlock(block, listDepth: 0)
            }
        }

        private mutating func renderBlock(_ block: Markup, listDepth: Int) {
            switch block {
            case let heading as Heading:
                appendInlineChildren(
                    heading.inlineChildren,
                    style: baseStyle(font: headingFont(for: heading.level), isBold: true)
                )
                appendNewlines(2)

            case let paragraph as Paragraph:
                appendInlineChildren(paragraph.inlineChildren, style: baseStyle())
                appendNewlines(2)

            case let list as UnorderedList:
                renderListItems(list.children, orderedStart: nil, listDepth: listDepth)
                appendNewlineIfNeeded()

            case let list as OrderedList:
                renderListItems(list.children, orderedStart: Int(list.startIndex), listDepth: listDepth)
                appendNewlineIfNeeded()

            case let quote as BlockQuote:
                renderBlockQuote(quote.children, listDepth: listDepth)
                appendNewlineIfNeeded()

            case _ as ThematicBreak:
                append("────────", style: baseStyle(color: secondaryTextColor))
                appendNewlines(2)

            default:
                let fallback = block.format().trimmingCharacters(in: .whitespacesAndNewlines)
                guard fallback.isEmpty == false else {
                    return
                }
                append(fallback, style: baseStyle())
                appendNewlines(2)
            }
        }

        private mutating func renderListItems(
            _ items: MarkupChildren,
            orderedStart: Int?,
            listDepth: Int
        ) {
            var ordinal = orderedStart ?? 1

            for item in items {
                guard let listItem = item as? ListItem else {
                    continue
                }

                let marker = orderedStart == nil ? "•" : "\(ordinal)."
                renderListItem(listItem, marker: marker, listDepth: listDepth)
                ordinal += 1
            }
        }

        private mutating func renderListItem(_ item: ListItem, marker: String, listDepth: Int) {
            let indent = String(repeating: "    ", count: listDepth)
            append("\(indent)\(marker) ", style: baseStyle(color: secondaryTextColor))

            var didRenderFirstBlock = false
            for child in item.children {
                if let paragraph = child as? Paragraph {
                    if didRenderFirstBlock {
                        append(indent + "  ", style: baseStyle(color: secondaryTextColor))
                    }
                    appendInlineChildren(paragraph.inlineChildren, style: baseStyle())
                    appendNewlineIfNeeded()
                    didRenderFirstBlock = true
                } else if child is UnorderedList || child is OrderedList {
                    renderBlock(child, listDepth: listDepth + 1)
                } else {
                    renderBlock(child, listDepth: listDepth)
                }
            }
        }

        private mutating func renderBlockQuote(_ blocks: MarkupChildren, listDepth: Int) {
            for block in blocks {
                append("▌ ", style: baseStyle(color: secondaryTextColor))
                if let paragraph = block as? Paragraph {
                    appendInlineChildren(paragraph.inlineChildren, style: baseStyle())
                    appendNewlineIfNeeded()
                } else {
                    renderBlock(block, listDepth: listDepth)
                }
            }
        }

        private mutating func appendInlineChildren<S: Sequence>(
            _ children: S,
            style: InlineStyle
        ) where S.Element == InlineMarkup {
            for child in children {
                appendInline(child, style: style)
            }
        }

        private mutating func appendInline(_ inline: InlineMarkup, style: InlineStyle) {
            switch inline {
            case let text as Markdown.Text:
                append(text.string, style: style)

            case let code as InlineCode:
                append(
                    code.code,
                    style: InlineStyle(
                        font: monospaceFont,
                        color: textColor,
                        isBold: false,
                        isItalic: false,
                        isStrikethrough: style.isStrikethrough,
                        link: style.link
                    ),
                    extraAttributes: [
                        .backgroundColor: isUserMessage
                            ? UIColor.white.withAlphaComponent(0.18)
                            : UIColor.secondarySystemBackground
                    ]
                )

            case let strong as Strong:
                var nested = style
                nested.isBold = true
                appendInlineChildren(strong.inlineChildren, style: nested)

            case let emphasis as Emphasis:
                var nested = style
                nested.isItalic = true
                appendInlineChildren(emphasis.inlineChildren, style: nested)

            case let strikethrough as Strikethrough:
                var nested = style
                nested.isStrikethrough = true
                appendInlineChildren(strikethrough.inlineChildren, style: nested)

            case let link as Markdown.Link:
                var nested = style
                nested.color = isUserMessage ? .white : .systemBlue
                nested.link = link.destination.flatMap(URL.init(string:))
                appendInlineChildren(link.inlineChildren, style: nested)

            case _ as SoftBreak:
                append(" ", style: style)

            case _ as LineBreak:
                append("\n", style: style)

            case let container as InlineContainer:
                appendInlineChildren(container.inlineChildren, style: style)

            default:
                append(inline.plainText, style: style)
            }
        }

        private func baseStyle(
            font: UIFont? = nil,
            color: UIColor? = nil,
            isBold: Bool = false
        ) -> InlineStyle {
            InlineStyle(
                font: font ?? bodyFont,
                color: color ?? textColor,
                isBold: isBold
            )
        }

        private func headingFont(for level: Int) -> UIFont {
            let textStyle: UIFont.TextStyle
            switch level {
            case 1:
                textStyle = .title2
            case 2:
                textStyle = .title3
            default:
                textStyle = .headline
            }
            return UIFont.preferredFont(forTextStyle: textStyle)
        }

        private mutating func append(
            _ string: String,
            style: InlineStyle,
            extraAttributes: [NSAttributedString.Key: Any] = [:]
        ) {
            guard string.isEmpty == false else {
                return
            }

            var attributes: [NSAttributedString.Key: Any] = [
                .font: styledFont(style),
                .foregroundColor: style.color
            ]
            if style.isStrikethrough {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if let link = style.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            extraAttributes.forEach { attributes[$0.key] = $0.value }

            storage.append(NSAttributedString(string: string, attributes: attributes))
        }

        private func styledFont(_ style: InlineStyle) -> UIFont {
            var traits: UIFontDescriptor.SymbolicTraits = []
            if style.isBold {
                traits.insert(.traitBold)
            }
            if style.isItalic {
                traits.insert(.traitItalic)
            }

            guard traits.isEmpty == false,
                  let descriptor = style.font.fontDescriptor.withSymbolicTraits(traits)
            else {
                return style.font
            }
            return UIFont(descriptor: descriptor, size: style.font.pointSize)
        }

        private mutating func appendNewlines(_ count: Int) {
            guard count > 0 else {
                return
            }
            append(String(repeating: "\n", count: count), style: baseStyle())
        }

        private mutating func appendNewlineIfNeeded() {
            guard storage.string.hasSuffix("\n") == false else {
                return
            }
            append("\n", style: baseStyle())
        }

        private mutating func trimTrailingNewlines() {
            while storage.string.hasSuffix("\n") {
                storage.deleteCharacters(in: NSRange(location: storage.length - 1, length: 1))
            }
        }
    }
}
