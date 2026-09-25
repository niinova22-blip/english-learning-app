import Foundation

/// A whole-number percentage in the UI language's order:
/// "80%" in English, "%80" in Turkish (catalog key "%lld%%").
enum PercentText {
    static func format(_ value: Int) -> String {
        String(localized: "\(value)%")
    }

    static func format(share: Double) -> String {
        format(Int((share * 100).rounded()))
    }
}
