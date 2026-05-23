import SwiftUI
import UIKit

/// App typography system using Inter and DM Sans with Dynamic Type scaling.
///
/// Usage:
///   .font(AppFont.body)
///   .font(AppFont.inter(.semibold, size: 14, relativeTo: .callout))
enum AppFont {
    // MARK: - Inter (body text)

    static func inter(
        _ weight: Font.Weight = .regular,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        let name = interPostScriptName(for: weight)
        guard let baseFont = UIFont(name: name, size: size) else {
            // Fallback to system font if custom font unavailable
            let systemFont = UIFont.systemFont(ofSize: size, weight: uiFontWeight(from: weight))
            return Font(UIFontMetrics(forTextStyle: uiTextStyle(from: textStyle)).scaledFont(for: systemFont))
        }
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle(from: textStyle))
        return Font(metrics.scaledFont(for: baseFont))
    }

    // MARK: - DM Sans (headings/shell)

    static func dmSans(
        _ weight: Font.Weight = .regular,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        let name = dmSansPostScriptName(for: weight)
        guard let baseFont = UIFont(name: name, size: size) else {
            let systemFont = UIFont.systemFont(ofSize: size, weight: uiFontWeight(from: weight))
            return Font(UIFontMetrics(forTextStyle: uiTextStyle(from: textStyle)).scaledFont(for: systemFont))
        }
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle(from: textStyle))
        return Font(metrics.scaledFont(for: baseFont))
    }

    // MARK: - Semantic styles
    // Computed properties so UIFontMetrics re-evaluates when Dynamic Type changes at runtime.

    static var largeTitle: Font { dmSans(.bold, size: 28, relativeTo: .largeTitle) }
    static var title: Font { dmSans(.bold, size: 22, relativeTo: .title) }
    static var title2: Font { dmSans(.semibold, size: 18, relativeTo: .title2) }
    static var title3: Font { dmSans(.regular, size: 16, relativeTo: .title3) }
    static var headline: Font { inter(.semibold, size: 16, relativeTo: .headline) }
    static var body: Font { inter(.regular, size: 15, relativeTo: .body) }
    static var callout: Font { inter(.regular, size: 14, relativeTo: .callout) }
    static var subheadline: Font { inter(.regular, size: 13, relativeTo: .subheadline) }
    static var footnote: Font { inter(.regular, size: 12, relativeTo: .footnote) }
    static var caption: Font { inter(.regular, size: 11, relativeTo: .caption) }
    static var caption2: Font { inter(.regular, size: 10, relativeTo: .caption2) }
}

// MARK: - Private helpers

private func interPostScriptName(for weight: Font.Weight) -> String {
    switch weight {
    case .bold: return "Inter-Bold"
    case .semibold: return "Inter-SemiBold"
    default: return "Inter-Regular"
    }
}

private func dmSansPostScriptName(for weight: Font.Weight) -> String {
    switch weight {
    case .heavy, .black: return "DMSans-ExtraBold"
    case .bold: return "DMSans-Bold"
    default: return "DMSans-Regular"
    }
}

private func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .regular: return .regular
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    default: return .regular
    }
}

private func uiTextStyle(from style: Font.TextStyle) -> UIFont.TextStyle {
    switch style {
    case .largeTitle: return .largeTitle
    case .title: return .title1
    case .title2: return .title2
    case .title3: return .title3
    case .headline: return .headline
    case .body: return .body
    case .callout: return .callout
    case .subheadline: return .subheadline
    case .footnote: return .footnote
    case .caption: return .caption1
    case .caption2: return .caption2
    default: return .body
    }
}
