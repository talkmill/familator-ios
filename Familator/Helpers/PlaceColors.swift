import SwiftUI

enum PlaceColors {
    static let colors: [Color] = [
        Color(red: 0x3b / 255, green: 0x82 / 255, blue: 0xf6 / 255), // blue-500
        Color(red: 0x10 / 255, green: 0xb9 / 255, blue: 0x81 / 255), // emerald-500
        Color(red: 0x8b / 255, green: 0x5c / 255, blue: 0xf6 / 255), // violet-500
        Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255), // amber-500
        Color(red: 0xf4 / 255, green: 0x3f / 255, blue: 0x5e / 255), // rose-500
        Color(red: 0x06 / 255, green: 0xb6 / 255, blue: 0xd4 / 255), // cyan-500
        Color(red: 0xd9 / 255, green: 0x46 / 255, blue: 0xef / 255), // fuchsia-500
        Color(red: 0x84 / 255, green: 0xcc / 255, blue: 0x16 / 255), // lime-500
    ]

    static func color(forIndex index: Int) -> Color {
        colors[index % colors.count]
    }
}
