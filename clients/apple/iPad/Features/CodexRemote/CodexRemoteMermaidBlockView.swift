import SwiftUI
import WebKit

struct CodexRemoteMermaidBlockView: View {
    let source: String
    @State private var renderState = CodexRemoteMermaidRenderState.rendering
    @State private var isPreviewPresented = false

    var body: some View {
        switch renderState {
        case .rendering:
            mermaidContainer(minHeight: 220)
        case .rendered(let height):
            mermaidContainer(height: max(160, min(height, 620)))
        case .failed:
            CodexRemoteCodeBlockView(language: "mermaid", code: source)
        }
    }

    @ViewBuilder
    private func mermaidContainer(height: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        ZStack(alignment: .topTrailing) {
            CodexRemoteMermaidWebView(source: source, renderState: $renderState)
                .frame(height: height)
                .frame(minHeight: minHeight)

            Button {
                isPreviewPresented = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(8)
            .accessibilityLabel("Preview diagram")
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        }
        .accessibilityIdentifier("codex-remote-mermaid-block")
        .fullScreenCover(isPresented: $isPreviewPresented) {
            CodexRemoteMermaidPreview(source: source)
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
        webView.loadHTMLString(
            CodexRemoteMermaidHTML.page(
                source: source,
                messageName: Coordinator.messageName,
                isPreview: false
            ),
            baseURL: Bundle.main.resourceURL
        )
    }
}

private struct CodexRemoteMermaidPreview: View {
    let source: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CodexRemoteMermaidPreviewWebView(source: source)
                .background(Color.white)
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Diagram")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Close")
                    }
                }
        }
    }
}

private struct CodexRemoteMermaidPreviewWebView: UIViewRepresentable {
    let source: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bouncesZoom = true
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 6
        webView.scrollView.delegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastSource != source else {
            return
        }

        context.coordinator.lastSource = source
        webView.loadHTMLString(
            CodexRemoteMermaidHTML.page(
                source: source,
                messageName: nil,
                isPreview: true
            ),
            baseURL: Bundle.main.resourceURL
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var lastSource: String?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.subviews.first
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

private enum CodexRemoteMermaidHTML {
    static func page(source: String, messageName: String?, isPreview: Bool) -> String {
        let sourceLiteral = javascriptStringLiteral(source)
        let postScript: String

        if let messageName {
            postScript = "const post = (payload) => window.webkit.messageHandlers.\(messageName).postMessage(payload);"
        } else {
            postScript = "const post = (_payload) => {};"
        }

        let viewport = isPreview
            ? "width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=6.0, user-scalable=yes"
            : "width=device-width, initial-scale=1.0"
        let bodyOverflow = isPreview ? "auto" : "hidden"
        let containerMinHeight = isPreview ? "min-height: 100vh;" : ""
        let svgSizing = "max-width: 100%; height: auto; margin: 0 auto;"

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="\(viewport)">
          <script src="mermaid.min.js"></script>
          <style>
            html, body {
              background: #ffffff;
              color: #111111;
              margin: 0;
              padding: 0;
              overflow: \(bodyOverflow);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            }

            #container {
              box-sizing: border-box;
              padding: \(isPreview ? 24 : 14)px;
              width: 100%;
              \(containerMinHeight)
            }

            svg {
              display: block;
              \(svgSizing)
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
            \(postScript)

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
}

private extension CodexRemoteMermaidWebView {
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
