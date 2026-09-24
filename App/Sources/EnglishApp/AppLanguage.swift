import Foundation

/// The language the interface is showing: Turkish on Turkish devices,
/// English everywhere else (English is the development language, so iOS
/// falls back to it). The single source for anything that must match the
/// UI language — case mapping, date formatting and the AI's reply language.
enum AppLanguage: Equatable {
    case turkish
    case english

    static var current: AppLanguage {
        resolve(preferredLocalization: Bundle.main.preferredLocalizations.first)
    }

    static func resolve(preferredLocalization: String?) -> AppLanguage {
        (preferredLocalization ?? "").lowercased().hasPrefix("tr") ? .turkish : .english
    }

    var locale: Locale {
        switch self {
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        }
    }
}
