import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class PackageIntroTests: XCTestCase {
    func makePackage() throws -> ContentPackage {
        let weights = try SkillWeights([.vocabulary: 40, .grammar: 25, .reading: 35, .listening: 0, .writing: 0, .speaking: 0, .pronunciation: 0])
        let package = ContentPackage(id: "biz", name: "Business", goal: .business, levelLower: "B1", levelUpper: "B2", skillWeights: weights)
        package.units = (0..<2).map { u in
            let unit = Unit(id: "u\(u)", theme: "T", order: u)
            unit.lessons = (0..<3).map { l in
                Lesson(id: "u\(u)-l\(l)", order: l, estimatedDurationMinutes: 10, title: "L", skill: .vocabulary)
            }
            return unit
        }
        return package
    }

    func defaults() -> UserDefaults {
        let name = "PackageIntroTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func test_facts_comeFromThePackage() throws {
        let facts = PackageIntroFacts(package: try makePackage(), dailyMinutes: 20)
        XCTAssertEqual(facts.focusSkills, [.vocabulary, .reading, .grammar], "weight > 0, largest first")
        XCTAssertEqual(facts.skippedSkills, [.listening, .writing, .speaking, .pronunciation])
        XCTAssertEqual(facts.units, 2)
        XCTAssertEqual(facts.lessons, 6)
        XCTAssertEqual(facts.averageLessonMinutes, 10)
        XCTAssertEqual(facts.dailyMinutes, 20)
        XCTAssertEqual(facts.percent(of: .vocabulary), 40)
    }

    func test_estimatedWeeks_usesSixtyPercentOfDailyTimeForNewLessons() throws {
        // 60 lesson minutes / (20 × 0.6 = 12 a day) = 5 days -> 1 week (rounded up).
        XCTAssertEqual(PackageIntroFacts(package: try makePackage(), dailyMinutes: 20).estimatedWeeks, 1)
        // 60 / (10 × 0.6 = 6) = 10 days -> 2 weeks.
        XCTAssertEqual(PackageIntroFacts(package: try makePackage(), dailyMinutes: 10).estimatedWeeks, 2)
        XCTAssertEqual(PackageIntroFacts.estimatedWeeks(totalMinutes: 0, dailyMinutes: 20), 1, "never below one week")
        XCTAssertEqual(PackageIntroFacts.estimatedWeeks(totalMinutes: 1260, dailyMinutes: 30), 10)
    }

    func test_introIsShownOncePerPackage() {
        let store = defaults()
        XCTAssertEqual(PackageIntroStore.packageToIntroduce(activePackageID: "biz", onboardingDone: true, defaults: store), "biz")
        PackageIntroStore.markSeen("biz", defaults: store)
        XCTAssertTrue(PackageIntroStore.hasSeen("biz", defaults: store))
        XCTAssertNil(PackageIntroStore.packageToIntroduce(activePackageID: "biz", onboardingDone: true, defaults: store))
    }

    func test_switchingPackages_showsOnlyUnseenOnes() {
        let store = defaults()
        PackageIntroStore.markSeen("biz", defaults: store)
        XCTAssertEqual(PackageIntroStore.packageToIntroduce(activePackageID: "day", onboardingDone: true, defaults: store), "day")
        PackageIntroStore.markSeen("day", defaults: store)
        XCTAssertNil(PackageIntroStore.packageToIntroduce(activePackageID: "biz", onboardingDone: true, defaults: store), "back to a seen package")
    }

    func test_notShownBeforeOnboardingEnds() {
        XCTAssertNil(PackageIntroStore.packageToIntroduce(activePackageID: "biz", onboardingDone: false, defaults: defaults()))
        XCTAssertNil(PackageIntroStore.packageToIntroduce(activePackageID: nil, onboardingDone: true, defaults: defaults()))
    }
}
