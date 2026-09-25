import Foundation
import LearningEngine

/// The one order packages are offered in (onboarding and the goal switcher):
/// packages written for speakers of the UI language first, then packages for
/// everyone, then the rest; ties by name.
enum PackageOrdering {
    static func sorted(_ packages: [ContentPackage], for language: AppLanguage) -> [ContentPackage] {
        packages.sorted { lhs, rhs in
            let (l, r) = (rank(lhs, language), rank(rhs, language))
            if l != r { return l < r }
            let (ln, rn) = (lhs.name(for: language.code), rhs.name(for: language.code))
            if ln != rn { return ln.localizedStandardCompare(rn) == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    /// Packages to offer: on English UI, packages written for Turkish speakers
    /// are hidden unless they are the active goal or already owned (a learner
    /// who switched the phone to English keeps their package).
    static func visible(
        _ packages: [ContentPackage], language: AppLanguage, activeID: String?, ownedIDs: Set<String>
    ) -> [ContentPackage] {
        guard language != .turkish else { return packages }
        return packages.filter { $0.audience != "tr" || $0.id == activeID || ownedIDs.contains($0.id) }
    }

    /// True when an English-UI learner should be told the package is taught
    /// through Turkish.
    static func showsTurkishSpeakersNote(_ package: ContentPackage, language: AppLanguage) -> Bool {
        package.audience == "tr" && language != .turkish
    }

    private static func rank(_ package: ContentPackage, _ language: AppLanguage) -> Int {
        guard let audience = package.audience else { return 1 }
        return audience == languageCode(language) ? 0 : 2
    }

    private static func languageCode(_ language: AppLanguage) -> String {
        language == .turkish ? "tr" : "en"
    }
}

/// Plain-value row shown when choosing a package.
struct PackageOption: Identifiable, Equatable {
    let id: String
    let name: String
    let levelLower: String
    let levelUpper: String
    let summary: String?
    let isForTurkishSpeakers: Bool
    let isExam: Bool

    init(_ package: ContentPackage, language: AppLanguage) {
        id = package.id
        name = package.name(for: language.code)
        levelLower = package.levelLower
        levelUpper = package.levelUpper
        summary = package.summary(for: language.code)
        isForTurkishSpeakers = PackageOrdering.showsTurkishSpeakersNote(package, language: language)
        isExam = package.goal.isExam
    }
}
