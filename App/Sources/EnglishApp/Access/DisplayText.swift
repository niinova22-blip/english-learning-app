import Foundation
import LearningEngine

/// Content titles in the interface language (package JSON carries both; the
/// base field is the fallback). Learning content itself is never translated.
extension AppLanguage {
    var code: String { self == .turkish ? "tr" : "en" }
}

extension ContentPackage {
    var displayName: String { name(for: AppLanguage.current.code) }
    var displaySummary: String? { summary(for: AppLanguage.current.code) }
}

extension Unit {
    var displayTheme: String { theme(for: AppLanguage.current.code) }
}

extension Lesson {
    var displayTitle: String { title(for: AppLanguage.current.code) }
}
