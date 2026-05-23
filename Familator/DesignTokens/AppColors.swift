import SwiftUI

// MARK: - Color hex initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - App color tokens

extension Color {
    // MARK: Backgrounds
    static let appBg = Color(hex: 0xFBFAF8)
    static let appSurface = Color(hex: 0xFFFFFF)
    static let appSurfaceSoft = Color(hex: 0xF7F7F4)
    static let appSurfaceHover = Color(hex: 0xF4F2FF)
    static let appSurfaceActive = Color(hex: 0xEFECFF)

    // MARK: Chrome
    static let appBorder = Color(hex: 0xE9E7E2)
    static let appText = Color(hex: 0x20201D)
    static let appMuted = Color(hex: 0x8C8983)
    static let appFocus = Color(hex: 0x3F66EA)

    // MARK: Section accents
    static let appAccentDashboard = Color(hex: 0x7F7C75)
    static let appAccentTasks = Color(hex: 0x7167F6)
    static let appAccentCalendar = Color(hex: 0x8B8881)
    static let appAccentTravel = Color(hex: 0x8B8881)
    static let appAccentNotes = Color(hex: 0x8B8881)
    static let appAccentWorkspace = Color(hex: 0x3F66EA)
    static let appAccentSettings = Color(hex: 0x8B8881)
}
