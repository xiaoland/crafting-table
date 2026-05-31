import MarkdownUI
import SwiftUI

struct CodexRemoteMarkdownBlockView: View {
    let text: String
    let isUserMessage: Bool

    var body: some View {
        Markdown(text)
            .markdownTextStyle {
                FontSize(.em(1))
                ForegroundColor(isUserMessage ? .white : .primary)
            }
            .markdownTextStyle(\.link) {
                ForegroundColor(isUserMessage ? .white : .blue)
                UnderlineStyle(.single)
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.9))
                ForegroundColor(isUserMessage ? .white : .primary)
                BackgroundColor(isUserMessage ? .white.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
            }
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("codex-remote-markdown-block")
    }
}
