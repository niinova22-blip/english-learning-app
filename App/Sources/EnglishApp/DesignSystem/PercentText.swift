import Foundation

/// A whole-number percentage in the UI language's order:
/// "80%" in English, "%80" in Turkish (catalog key "%lld%%").
enum PercentText {
    static func format(_ value: Int, bundle: Bundle = .main) -> String {
        String(localized: "\(value)%", bundle: bundle)
    }

    static func format(share: Double, bundle: Bundle = .main) -> String {
        format(Int((share * 100).rounded()), bundle: bundle)
    }
}

/// Counted units with correct English plurals ("1 day", "5 days"); Turkish
/// uses one form ("5 gün"). Used to build longer sentences as `%@` pieces.
enum CountText {
    static func days(_ n: Int, bundle: Bundle = .main) -> String {
        String(localized: "\(n) days", bundle: bundle)
    }

    static func minutes(_ n: Int, bundle: Bundle = .main) -> String {
        String(localized: "\(n) minutes", bundle: bundle)
    }
}
