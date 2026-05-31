import SwiftUI
import WebKit

struct CodexRemoteMermaidBlockView: View {
    let source: String
    @State private var renderState = CodexRemoteMermaidRenderState.rendering

    var body: some View {
        switch renderState {
        case .rendering:
            CodexRemoteMermaidWebView(source: source, renderState: $renderState)
                .frame(minHeight: 220)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }
                .accessibilityIdentifier("codex-remote-mermaid-block")
        case .rendered(let height):
            CodexRemoteMermaidWebView(source: source, renderState: $renderState)
                .frame(height: max(160, min(height, 620)))
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }
                .accessibilityIdentifier("codex-remote-mermaid-block")
        case .failed:
            CodexRemoteCodeBlockView(language: "mermaid", code: source)
        }
    }
}

private enum CodexRemoteMermaidRenderState: Equatable {
    case rendering
    case rendered(CGFloat)
    case failed
}

private struct CodexRemoteMermaidWebView: UIViewRepresentable {
    let source: String
    @Binding var renderState: CodexRemoteMermaidRenderState

    func makeCoordinator() -> Coordinator {
        Coordinator(renderState: $renderState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.messageName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastSource != source else {
            return
        }

        context.coordinator.lastSource = source
        renderState = .rendering
        webView.loadHTMLString(html(source: source), baseURL: Bundle.main.resourceURL)
    }

    private func html(source: String) -> String {
        let sourceLiteral = Self.javascriptStringLiteral(source)

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="mermaid.min.js"></script>
          <style>
            html, body {
              background: #ffffff;
              color: #111111;
              margin: 0;
              padding: 0;
              overflow: hidden;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            }

            #container {
              box-sizing: border-box;
              padding: 14px;
              width: 100%;
            }

            svg {
              display: block;
              max-width: 100%;
              height: auto;
              margin: 0 auto;
            }

            .node rect,
            .node circle,
            .node ellipse,
            .node polygon,
            .node path,
            .cluster rect {
              fill: #ffffff !important;
              stroke: #111111 !important;
            }

            .edgePath path,
            .flowchart-link,
            .messageLine0,
            .messageLine1 {
              stroke: #111111 !important;
            }

            text,
            .label,
            .nodeLabel,
            .edgeLabel {
              color: #111111 !important;
              fill: #111111 !important;
            }

            .edgeLabel,
            .edgeLabel rect {
              background: #ffffff !important;
              fill: #ffffff !important;
            }

            #error {
              color: #111111;
              font: 13px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              white-space: pre-wrap;
            }
          </style>
        </head>
        <body>
          <div id="container"></div>
          <script>
            const source = \(sourceLiteral);
            const post = (payload) => window.webkit.messageHandlers.\(Coordinator.messageName).postMessage(payload);

            window.onerror = function(message) {
              post({ type: "error", message: String(message) });
            };

            async function renderDiagram() {
              try {
                if (!window.mermaid) {
                  throw new Error("Mermaid runtime is unavailable.");
                }

                mermaid.initialize({
                  startOnLoad: false,
                  securityLevel: "strict",
                  theme: "base",
                  themeVariables: {
                    background: "#ffffff",
                    primaryColor: "#ffffff",
                    primaryTextColor: "#111111",
                    primaryBorderColor: "#111111",
                    lineColor: "#111111",
                    secondaryColor: "#ffffff",
                    tertiaryColor: "#ffffff",
                    mainBkg: "#ffffff",
                    secondBkg: "#ffffff",
                    tertiaryBkg: "#ffffff",
                    fontFamily: "-apple-system, BlinkMacSystemFont, SF Pro Text, sans-serif"
                  }
                });

                const result = await mermaid.render("codexRemoteMermaid", source);
                const container = document.getElementById("container");
                container.innerHTML = result.svg;
                requestAnimationFrame(() => {
                  post({
                    type: "height",
                    height: Math.ceil(document.documentElement.scrollHeight)
                  });
                });
              } catch (error) {
                const container = document.getElementById("container");
                const errorElement = document.createElement("pre");
                errorElement.id = "error";
                errorElement.textContent = error && error.message ? error.message : String(error);
                container.replaceChildren(errorElement);
                post({ type: "error", message: errorElement.textContent });
              }
            }

            renderDiagram();
          </script>
        </body>
        </html>
        """
    }

    private static func javascriptStringLiteral(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return encoded.replacingOccurrences(of: "</", with: "<\\/")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageName = "codexRemoteMermaid"
        var lastSource: String?
        private var renderState: Binding<CodexRemoteMermaidRenderState>

        init(renderState: Binding<CodexRemoteMermaidRenderState>) {
            self.renderState = renderState
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String
            else {
                return
            }

            DispatchQueue.main.async {
                switch type {
                case "height":
                    if let height = payload["height"] as? CGFloat {
                        self.renderState.wrappedValue = .rendered(height)
                    } else if let height = payload["height"] as? Double {
                        self.renderState.wrappedValue = .rendered(CGFloat(height))
                    }
                case "error":
                    self.renderState.wrappedValue = .failed
                default:
                    break
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            switch navigationAction.navigationType {
            case .other:
                decisionHandler(.allow)
            default:
                decisionHandler(.cancel)
            }
        }
    }
}
