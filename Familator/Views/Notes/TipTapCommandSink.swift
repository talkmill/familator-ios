import Foundation
import WebKit

/// Allowed editor commands. Using an enum prevents arbitrary JS injection.
enum TipTapCommand: String {
    case toggleBold
    case toggleItalic
    case toggleUnderline
    case toggleHeading
    case setParagraph
    case setColor
    case unsetColor
    case setFontSize
    case toggleBulletList
    case toggleOrderedList
    case insertTable
    case addRowAfter
    case addColumnAfter
    case deleteTable
    case undo
    case redo
}

/// Allows the toolbar to dispatch commands to the WKWebView editor without
/// holding a direct reference to the web view or its coordinator.
@MainActor
final class TipTapCommandSink: ObservableObject {
    private weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func execute(command: TipTapCommand, args: [String: Any]? = nil) {
        guard let webView else { return }
        let argsJSON: String
        if let args, !args.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: args),
           let str = String(data: data, encoding: .utf8) {
            argsJSON = str
        } else {
            argsJSON = "null"
        }
        let js = "window.editorCommand('\(command.rawValue)', \(argsJSON))"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
