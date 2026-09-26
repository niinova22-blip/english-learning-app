import Foundation
import LearningEngine

/// The numbers the package intro shows, all taken from the package itself
/// and the learner's daily minutes.
struct PackageIntroFacts: Equatable {
    /// Skills the plan studies (weight > 0), largest share first.
    let focusSkills: [Skill]
    /// Skills this package does not teach (weight 0).
    let skippedSkills: [Skill]
    let units: Int
    let lessons: Int
    let averageLessonMinutes: Int
    let dailyMinutes: Int
    let estimatedWeeks: Int
    private let weights: SkillWeights

    /// Share of daily time that goes to new lessons; the rest is reviews.
    static let newLessonShare = 0.6

    init(package: ContentPackage, dailyMinutes: Int) {
        let weights = package.skillWeights
        self.weights = weights
        focusSkills = Skill.allCases
            .filter { weights.weight(of: $0) > 0 }
            .enumerated()
            .sorted { lhs, rhs in
                let (l, r) = (weights.weight(of: lhs.element), weights.weight(of: rhs.element))
                return l != r ? l > r : lhs.offset < rhs.offset
            }
            .map(\.element)
        skippedSkills = Skill.allCases.filter { weights.weight(of: $0) == 0 }
        let allLessons = package.units.flatMap(\.lessons)
        units = package.units.count
        lessons = allLessons.count
        let totalMinutes = allLessons.map(\.estimatedDurationMinutes).reduce(0, +)
        averageLessonMinutes = allLessons.isEmpty ? 0 : Int((Double(totalMinutes) / Double(allLessons.count)).rounded())
        self.dailyMinutes = dailyMinutes
        estimatedWeeks = Self.estimatedWeeks(totalMinutes: totalMinutes, dailyMinutes: dailyMinutes)
    }

    static func estimatedWeeks(totalMinutes: Int, dailyMinutes: Int) -> Int {
        let perDay = Double(max(dailyMinutes, 1)) * newLessonShare
        let days = Double(totalMinutes) / perDay
        return max(1, Int((days / 7).rounded(.up)))
    }

    func percent(of skill: Skill) -> Int {
        Int((weights.share(of: skill) * 100).rounded())
    }
}

/// Remembers, per package id, that the learner has seen its intro.
enum PackageIntroStore {
    private static func key(_ packageID: String) -> String { "packageIntroSeen.\(packageID)" }

    static func hasSeen(_ packageID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key(packageID))
    }

    static func markSeen(_ packageID: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key(packageID))
    }

    /// The package whose intro should open now: the active one, after
    /// onboarding, the first time it is active.
    static func packageToIntroduce(activePackageID: String?, onboardingDone: Bool, defaults: UserDefaults = .standard) -> String? {
        guard onboardingDone, let activePackageID, !hasSeen(activePackageID, defaults: defaults) else { return nil }
        return activePackageID
    }
}
