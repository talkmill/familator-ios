import Foundation
import UIKit

enum TipTapCodec {
    static let emptyDocument: JSONValue = .object([
        "type": .string("doc"),
        "content": .array([
            .object(["type": .string("paragraph")]),
        ]),
    ])

    static func toAttributedString(from json: JSONValue) -> NSAttributedString {
        guard case .object(let root) = json else { return NSAttributedString(string: "") }
        guard case .string(let type)? = root["type"], type == "doc" else { return NSAttributedString(string: "") }
        let output = NSMutableAttributedString()
        appendBlockNodes(root["content"], into: output)
        sanitizeForFixedLightCanvas(output)
        return output
    }

    static func fromAttributedString(_ attributed: NSAttributedString) -> JSONValue {
        let string = attributed.string.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = string.components(separatedBy: "\n")
        var paragraphNodes: [JSONValue] = []
        var offset = 0
        for paragraph in paragraphs {
            let length = (paragraph as NSString).length
            let range = NSRange(location: offset, length: length)
            let runs = inlineRuns(from: attributed, in: range)
            paragraphNodes.append(.object([
                "type": .string("paragraph"),
                "content": .array(runs),
            ]))
            offset += length + 1
        }
        return .object([
            "type": .string("doc"),
            "content": .array(paragraphNodes.isEmpty ? [.object(["type": .string("paragraph")])] : paragraphNodes),
        ])
    }

    private static func appendBlockNodes(_ nodes: JSONValue?, into output: NSMutableAttributedString) {
        guard case .array(let arr)? = nodes else { return }
        for node in arr {
            guard case .object(let obj) = node, case .string(let type)? = obj["type"] else { continue }
            switch type {
            case "paragraph":
                appendInline(obj["content"], base: baseAttributes(font: .systemFont(ofSize: 16)), into: output)
                output.append(NSAttributedString(string: "\n"))
            case "heading":
                let level = intFromJSON(obj["attrs"], key: "level") ?? 1
                let size = max(20 - CGFloat(level * 2), 14)
                appendInline(obj["content"], base: baseAttributes(font: .boldSystemFont(ofSize: size)), into: output)
                output.append(NSAttributedString(string: "\n"))
            case "bulletList":
                appendList(obj["content"], ordered: false, into: output)
            case "orderedList":
                appendList(obj["content"], ordered: true, into: output)
            case "listItem":
                appendBlockNodes(obj["content"], into: output)
            case "table":
                appendTable(obj["content"], into: output)
            case "blockquote":
                appendBlockNodes(obj["content"], into: output)
            case "codeBlock":
                appendInline(obj["content"], base: baseAttributes(font: .monospacedSystemFont(ofSize: 14, weight: .regular)), into: output)
                output.append(NSAttributedString(string: "\n"))
            case "horizontalRule":
                output.append(NSAttributedString(string: "────────\n", attributes: baseAttributes(font: .systemFont(ofSize: 16))))
            default:
                appendBlockNodes(obj["content"], into: output)
            }
        }
    }

    private static func appendList(_ nodes: JSONValue?, ordered: Bool, into output: NSMutableAttributedString) {
        guard case .array(let arr)? = nodes else { return }
        for (index, item) in arr.enumerated() {
            guard case .object(let listItem) = item else { continue }
            guard case .array(let content)? = listItem["content"] else { continue }
            for child in content {
                guard case .object(let childNode) = child else { continue }
                guard case .string(let type)? = childNode["type"], type == "paragraph" else { continue }
                let prefix = ordered ? "\(index + 1). " : "• "
                output.append(NSAttributedString(string: prefix, attributes: baseAttributes(font: .systemFont(ofSize: 16))))
                appendInline(childNode["content"], base: baseAttributes(font: .systemFont(ofSize: 16)), into: output)
                output.append(NSAttributedString(string: "\n"))
            }
        }
    }

    private static func appendInline(_ nodes: JSONValue?, base: [NSAttributedString.Key: Any], into output: NSMutableAttributedString) {
        guard case .array(let arr)? = nodes else { return }
        for node in arr {
            guard case .object(let obj) = node else { continue }
            guard case .string(let type)? = obj["type"], type == "text" else { continue }
            guard case .string(let text)? = obj["text"] else { continue }
            var attrs = base
            if case .array(let marks)? = obj["marks"] {
                for mark in marks {
                    guard case .object(let markObj) = mark else { continue }
                    guard case .string(let markType)? = markObj["type"] else { continue }
                    switch markType {
                    case "bold":
                        attrs[.font] = UIFont.boldSystemFont(ofSize: (attrs[.font] as? UIFont)?.pointSize ?? 16)
                    case "italic":
                        let size = (attrs[.font] as? UIFont)?.pointSize ?? 16
                        attrs[.font] = UIFont.italicSystemFont(ofSize: size)
                    case "underline":
                        attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    case "textStyle":
                        if let pointSize = pixelValue(markObj["attrs"], key: "fontSize") {
                            let current = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                            attrs[.font] = current.withSize(pointSize)
                        }
                        if let colorHex = stringValue(markObj["attrs"], key: "color"),
                           let color = UIColor(cssColor: colorHex),
                           !color.isIllegibleOnWhiteBackground
                        {
                            attrs[.foregroundColor] = color
                        }
                    default:
                        break
                    }
                }
            }
            output.append(NSAttributedString(string: text, attributes: attrs))
        }
    }

    private static func appendTable(_ content: JSONValue?, into output: NSMutableAttributedString) {
        guard case .array(let rows)? = content else { return }
        for row in rows {
            guard case .object(let rowObj) = row else { continue }
            guard case .array(let cells)? = rowObj["content"] else { continue }
            var renderedCells: [String] = []
            for cell in cells {
                let cellOut = NSMutableAttributedString()
                if case .object(let cellObj) = cell {
                    appendBlockNodes(cellObj["content"], into: cellOut)
                }
                let text = cellOut.string.trimmingCharacters(in: .whitespacesAndNewlines)
                renderedCells.append(text)
            }
            if !renderedCells.isEmpty {
                output.append(NSAttributedString(string: renderedCells.joined(separator: " | "), attributes: baseAttributes(font: .systemFont(ofSize: 16))))
                output.append(NSAttributedString(string: "\n"))
            }
        }
    }

    private static func inlineRuns(from attributed: NSAttributedString, in range: NSRange) -> [JSONValue] {
        guard range.location != NSNotFound, range.length > 0 else { return [] }
        var runs: [JSONValue] = []
        attributed.enumerateAttributes(in: range) { attributes, subrange, _ in
            let text = (attributed.string as NSString).substring(with: subrange)
            guard !text.isEmpty else { return }
            var marks: [JSONValue] = []
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    marks.append(.object(["type": .string("bold")]))
                }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    marks.append(.object(["type": .string("italic")]))
                }
                marks.append(.object([
                    "type": .string("textStyle"),
                    "attrs": .object(["fontSize": .string("\(Int(font.pointSize))px")]),
                ]))
            }
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                marks.append(.object(["type": .string("underline")]))
            }
            if let color = attributes[.foregroundColor] as? UIColor,
               color.shouldPersistAsTipTapColor,
               let hex = color.tiptapHexColor
            {
                if let idx = marks.firstIndex(where: { mark in
                    guard case .object(let obj) = mark else { return false }
                    guard case .string(let type)? = obj["type"] else { return false }
                    return type == "textStyle"
                }) {
                    if case .object(var markObj) = marks[idx] {
                        var attrsObj: [String: JSONValue] = [:]
                        if case .object(let existingAttrs)? = markObj["attrs"] {
                            attrsObj = existingAttrs
                        }
                        attrsObj["color"] = .string(hex)
                        markObj["attrs"] = .object(attrsObj)
                        marks[idx] = .object(markObj)
                    }
                } else {
                    marks.append(.object([
                        "type": .string("textStyle"),
                        "attrs": .object(["color": .string(hex)]),
                    ]))
                }
            }
            var node: [String: JSONValue] = [
                "type": .string("text"),
                "text": .string(text),
            ]
            if !marks.isEmpty {
                node["marks"] = .array(marks)
            }
            runs.append(.object(node))
        }
        return runs
    }

    private static func intFromJSON(_ value: JSONValue?, key: String) -> Int? {
        guard case .object(let obj)? = value else { return nil }
        guard let raw = obj[key] else { return nil }
        switch raw {
        case .number(let number): return Int(number)
        case .string(let string): return Int(string)
        default: return nil
        }
    }

    private static func pixelValue(_ value: JSONValue?, key: String) -> CGFloat? {
        guard case .object(let obj)? = value else { return nil }
        guard case .string(let raw)? = obj[key] else { return nil }
        let normalized = raw.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Int(normalized) else { return nil }
        return CGFloat(number)
    }

    private static func stringValue(_ value: JSONValue?, key: String) -> String? {
        guard case .object(let obj)? = value else { return nil }
        guard case .string(let raw)? = obj[key] else { return nil }
        return raw
    }

    private static func baseAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        // Fixed black: dynamic `.label` can resolve to white under mixed trait hierarchies
        // while the note editor uses a forced light canvas.
        [
            .font: font,
            .foregroundColor: UIColor.black,
        ]
    }

    /// Removes or replaces foreground colors that disappear on a white note background
    /// (e.g. `#fff` from bad round-trips, or dynamic semantic colors stored in JSON).
    private static func sanitizeForFixedLightCanvas(_ input: NSMutableAttributedString) {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let full = NSRange(location: 0, length: input.length)
        guard full.length > 0 else { return }
        var replacements: [(NSRange, UIColor)] = []
        input.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            guard let color = value as? UIColor else { return }
            if color.isIllegibleOnWhiteBackground {
                replacements.append((range, .black))
            } else {
                replacements.append((range, color.resolvedColor(with: lightTraits)))
            }
        }
        for (range, color) in replacements {
            input.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
}

private extension UIColor {
    /// TipTap / web may emit `#RRGGBB`, `rgb()`, or named CSS colors.
    convenience init?(cssColor raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let c = UIColor(hex: s) {
            self.init(cgColor: c.cgColor)
            return
        }
        let lower = s.lowercased()
        if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba("), let c = UIColor.parseRgbFunction(s) {
            self.init(cgColor: c.cgColor)
            return
        }
        return nil
    }

    /// `rgb(255, 0, 0)` / `rgba(255,0,0,0.5)` with optional spaces.
    static func parseRgbFunction(_ s: String) -> UIColor? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("),
              let close = trimmed.lastIndex(of: ")")
        else { return nil }
        let inner = trimmed[trimmed.index(after: open) ..< close]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3,
              let r = Double(parts[0]),
              let g = Double(parts[1]),
              let b = Double(parts[2])
        else { return nil }
        let a: Double
        if parts.count >= 4, let alpha = Double(parts[3]) {
            a = alpha
        } else {
            a = 1
        }
        return UIColor(
            red: CGFloat(r / 255.0),
            green: CGFloat(g / 255.0),
            blue: CGFloat(b / 255.0),
            alpha: CGFloat(a)
        )
    }

    /// True when this color would be hard or impossible to read on a white background.
    var isIllegibleOnWhiteBackground: Bool {
        let c = resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard c.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            var w: CGFloat = 0
            if c.getWhite(&w, alpha: &a) {
                return w * a + (1 - a) > 0.88
            }
            return false
        }
        if a < 0.12 { return true }
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.88
    }

    var tiptapHexColor: String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        if abs(a - 1.0) < 0.001 {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
        return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }

    var shouldPersistAsTipTapColor: Bool {
        // Avoid writing semantic default colors (like .label) into note JSON.
        // Persist only explicit custom colors so web/iOS stay visually compatible.
        let light = resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let labelLight = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        return !light.isNearlyEqual(to: labelLight)
    }

    func isNearlyEqual(to other: UIColor, epsilon: CGFloat = 0.01) -> Bool {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else {
            return false
        }
        return abs(r1 - r2) <= epsilon &&
            abs(g1 - g2) <= epsilon &&
            abs(b1 - b2) <= epsilon &&
            abs(a1 - a2) <= epsilon
    }
}
