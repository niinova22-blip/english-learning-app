import Foundation
import TutorEngine

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

    /// The compiled string table for this language. Lets code (and tests)
    /// render text in a specific language regardless of the device setting;
    /// falls back to the main bundle when the table is missing.
    var bundle: Bundle {
        let code = self == .turkish ? "tr" : "en"
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    /// The language the AI tutor, chat and coach should write in.
    var learnerLanguage: LearnerLanguage {
        self == .turkish ? .turkish : .english
    }

    var locale: Locale {
        switch self {
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        }
    }
}
