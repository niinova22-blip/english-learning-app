import SwiftUI
import UIKit

/// Color roles for the "academic and focused" direction. Every role has a
/// light and a dark value; views only ever use these roles.
enum Theme {
    static let paper = dynamic(light: 0xFBF8F2, dark: 0x151A1C)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1E2527)
    static let border = dynamic(light: 0xE7E1D6, dark: 0x2E3739)
    static let ink = dynamic(light: 0x1F2A2E, dark: 0xEEF2F1)
    static let secondaryInk = dynamic(light: 0x6B7280, dark: 0x9CA3AF)
    static let primary = dynamic(light: 0x0F766E, dark: 0x2DD4BF)
    static let accent = dynamic(light: 0xEA580C, dark: 0xFB923C)
    static let danger = dynamic(light: 0xB91C1C, dark: 0xF87171)
    static let reading = fixed(0x3B82F6)
    static let listening = fixed(0x7C3AED)
    static let writing = fixed(0x0891B2)
    static let speaking = fixed(0xDB2777)
    static let pronunciation = fixed(0x65A30D)

    static func rgb(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            uiColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func fixed(_ hex: UInt32) -> Color {
        Color(uiColor(hex))
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        let c = rgb(hex)
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}

extension Font {
    /// Serif (New York) title that still scales with Dynamic Type.
    static func serifTitle(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .serif).weight(.bold)
    }
}
