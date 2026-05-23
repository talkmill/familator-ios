import SwiftUI
import WebKit

struct TipTapWebView: UIViewRepresentable {
    let contentJSON: JSONValue
    let isEditable: Bool
    let formattingState: TipTapFormattingState
    let onContentChanged: (JSONValue) -> Void
    let onBlur: () -> Void
    let commandSink: TipTapCommandSink

    /// Tracks which note is loaded to avoid redundant setContent calls.
    /// Uses only the note ID (not updatedAt) to avoid clobbering in-progress edits
    /// when the server returns a new updatedAt after save.
    let contentId: String

    @Binding var dynamicHeight: CGFloat

    private static let messageHandlerNames = ["contentChanged", "formattingChanged", "editorBlurred", "editorReady", "heightChanged"]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        let proxy = WeakScriptMessageHandler(context.coordinator)
        for name in Self.messageHandlerNames {
            controller.add(proxy, name: name)
        }
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = .white
        // Disable WKWebView's own scrolling — the parent List handles scrolling.
        // This also prevents gesture conflicts that block taps from reaching the editor.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .white
        webView.scrollView.bounces = false

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        context.coordinator.webView = webView
        commandSink.attach(webView)

        if let htmlURL = Bundle.main.url(forResource: "tiptap-editor", withExtension: "html") {
            let dirURL = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: dirURL)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        // Keep coordinator's parent in sync so editorReady uses fresh values
        coordinator.parent = self

        // Guard all JS calls on isReady — page may not have loaded yet
        guard coordinator.isReady else { return }

        // Update editable state
        if coordinator.lastEditable != isEditable {
            coordinator.lastEditable = isEditable
            webView.evaluateJavaScript("window.editorSetEditable(\(isEditable))", completionHandler: nil)
        }

        // Load content when content ID changes (new note selected)
        if coordinator.lastContentId != contentId {
            coordinator.lastContentId = contentId
            coordinator.loadContent(contentJSON)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        let controller = uiView.configuration.userContentController
        for name in messageHandlerNames {
            controller.removeScriptMessageHandler(forName: name)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: TipTapWebView
        weak var webView: WKWebView?
        var isReady = false
        var lastContentId = ""
        var lastEditable: Bool?

        init(parent: TipTapWebView) {
            self.parent = parent
        }

        func loadContent(_ json: JSONValue) {
            guard let webView else { return }
            guard let data = try? JSONEncoder().encode(json),
                  let jsonString = String(data: data, encoding: .utf8)
            else { return }
            // setContent(content, false) — the false means emitUpdate:false,
            // so TipTap will NOT fire onUpdate and no contentChanged message
            // will be posted back. No suppression logic needed.
            webView.evaluateJavaScript("window.editorSetContent(\(jsonString))", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                isReady = true
                lastContentId = parent.contentId
                loadContent(parent.contentJSON)
                let editable = lastEditable ?? parent.isEditable
                webView?.evaluateJavaScript("window.editorSetEditable(\(editable))", completionHandler: nil)

            case "contentChanged":
                guard let body = message.body as? String,
                      let data = body.data(using: .utf8),
                      let json = try? JSONDecoder().decode(JSONValue.self, from: data)
                else { return }
                Task { @MainActor in
                    self.parent.onContentChanged(json)
                }

            case "formattingChanged":
                guard let body = message.body as? String else { return }
                Task { @MainActor in
                    self.parent.formattingState.update(from: body)
                }

            case "editorBlurred":
                Task { @MainActor in
                    self.parent.onBlur()
                }

            case "heightChanged":
                guard let height = message.body as? Double, height > 0 else { return }
                Task { @MainActor in
                    self.parent.dynamicHeight = max(height, 220)
                }

            default:
                break
            }
        }
    }
}

/// Weak proxy to avoid the strong-reference cycle between
/// WKUserContentController → Coordinator → (parent holds WKWebView).
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
