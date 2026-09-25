import SwiftUI
import UIKit

/// Color roles for the native-iOS direction: system grouped backgrounds and
/// label colors, with the brand petrol and orange tuned for WCAG AA text
/// contrast in both modes. Views only ever use these roles.
enum Theme {
    /// Brand values, kept as numbers so tests can check their contrast.
    enum Palette {
        static let primaryLight: UInt32 = 0x0D7A70
        static let primaryDark: UInt32 = 0x2DD4BF
        static let accentLight: UInt32 = 0xC94D0A
        static let accentDark: UInt32 = 0xFB923C
    }

    static let paper = Color(UIColor.systemGroupedBackground)
    static let surface = Color(UIColor.secondarySystemGroupedBackground)
    static let border = Color(UIColor.separator)
    static let ink = Color(UIColor.label)
    static let secondaryInk = Color(UIColor.secondaryLabel)
    static let primary = dynamic(light: Palette.primaryLight, dark: Palette.primaryDark)
    static let accent = dynamic(light: Palette.accentLight, dark: Palette.accentDark)
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
    /// Bold SF Pro title that scales with Dynamic Type.
    static func appTitle(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .default).weight(.bold)
    }

    /// SF Rounded for numbers: stats, streaks, prices, progress.
    static func number(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .rounded).weight(.semibold)
    }

    /// The one serif left: the word on the study card.
    static func headword(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.bold)
    }
}
