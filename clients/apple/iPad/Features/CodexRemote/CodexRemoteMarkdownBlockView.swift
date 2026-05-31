import SwiftUI

struct CodexRemoteMarkdownBlockView: View {
    let text: String
    let isUserMessage: Bool

    var body: some View {
        CodexRemoteSelectableMarkdownText(text: text, isUserMessage: isUserMessage)
            .accessibilityIdentifier("codex-remote-markdown-block")
    }
}
