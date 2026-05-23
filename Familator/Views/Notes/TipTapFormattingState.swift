import Foundation

@MainActor
final class TipTapFormattingState: ObservableObject {
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var headingLevel: Int = 0 // 0 = paragraph, 1-3 = heading level
    @Published var isBulletList = false
    @Published var isOrderedList = false
    @Published var color: String = ""
    @Published var fontSize: String = ""
    @Published var canUndo = false
    @Published var canRedo = false

    func update(from json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        isBold = dict["bold"] as? Bool ?? false
        isItalic = dict["italic"] as? Bool ?? false
        isUnderline = dict["underline"] as? Bool ?? false
        headingLevel = dict["heading"] as? Int ?? 0
        isBulletList = dict["bulletList"] as? Bool ?? false
        isOrderedList = dict["orderedList"] as? Bool ?? false
        color = dict["color"] as? String ?? ""
        fontSize = dict["fontSize"] as? String ?? ""
        canUndo = dict["canUndo"] as? Bool ?? false
        canRedo = dict["canRedo"] as? Bool ?? false
    }
}
