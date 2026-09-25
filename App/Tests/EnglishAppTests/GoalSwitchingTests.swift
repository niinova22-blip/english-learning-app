import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class PackageOrderingTests: XCTestCase {
    let yds = ContentPackage(id: "yds", name: "YDS Academic", goal: .yds, levelLower: "B2", levelUpper: "C1", audience: "tr")
    let business = ContentPackage(id: "business", name: "Business English", goal: .business, levelLower: "B1", levelUpper: "B2")
    let everyday = ContentPackage(id: "everyday", name: "Everyday English", goal: .conversational, levelLower: "A2", levelUpper: "B1")

    func test_turkishUI_putsTurkishPackagesFirst_thenEveryoneByName() {
        let sorted = PackageOrdering.sorted([everyday, business, yds], for: .turkish).map(\.id)
        XCTAssertEqual(sorted, ["yds", "business", "everyday"])
    }

    func test_englishUI_putsPackagesForEveryoneFirst_andTurkishPackagesLast() {
        let sorted = PackageOrdering.sorted([yds, everyday, business], for: .english).map(\.id)
        XCTAssertEqual(sorted, ["business", "everyday", "yds"])
    }

    func test_visible_hidesTurkishPackagesOnEnglishUI_unlessActiveOrOwned() {
        let all = [yds, business, everyday]
        XCTAssertEqual(PackageOrdering.visible(all, language: .english, activeID: nil, ownedIDs: []).map(\.id), ["business", "everyday"])
        XCTAssertEqual(PackageOrdering.visible(all, language: .english, activeID: "yds", ownedIDs: []).map(\.id), ["yds", "business", "everyday"])
        XCTAssertEqual(PackageOrdering.visible(all, language: .english, activeID: nil, ownedIDs: ["yds"]).map(\.id), ["yds", "business", "everyday"])
        XCTAssertEqual(PackageOrdering.visible(all, language: .turkish, activeID: nil, ownedIDs: []).map(\.id), ["yds", "business", "everyday"])
    }

    func test_localizedNames_followTheUILanguage() {
        let pkg = ContentPackage(id: "b", name: "Business English", goal: .business, levelLower: "B1", levelUpper: "C1")
        pkg.nameTR = "İş İngilizcesi"
        XCTAssertEqual(PackageOption(pkg, language: .turkish).name, "İş İngilizcesi")
        XCTAssertEqual(PackageOption(pkg, language: .english).name, "Business English")
    }

    func test_turkishSpeakersNote_onlyOnEnglishUIForTurkishPackages() {
        XCTAssertTrue(PackageOrdering.showsTurkishSpeakersNote(yds, language: .english))
        XCTAssertFalse(PackageOrdering.showsTurkishSpeakersNote(yds, language: .turkish))
        XCTAssertFalse(PackageOrdering.showsTurkishSpeakersNote(business, language: .english))
    }
}

final class GoalSwitcherViewModelTests: XCTestCase {
    let userID = "u"
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    struct OwnsOnly: PackageAccessProvider {
        let id: String
        func accessLevel(forPackageID id: String) -> PackageAccessLevel { id == self.id ? .owned : .preview }
    }

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(ContentPackage(id: "yds", name: "YDS Academic", goal: .yds, levelLower: "B2", levelUpper: "C1", audience: "tr", summary: "YDS'ye hazırlık"))
        context.insert(ContentPackage(id: "business", name: "Business English", goal: .business, levelLower: "B1", levelUpper: "B2", summary: "Meetings and email"))
        context.insert(LearnerProfile(userID: userID, activePackageID: "yds", createdAt: now, onboardingCompletedAt: now))
        let ydsLesson = LessonProgress(userID: userID, lessonID: "yds-lesson", startedAt: now)
        ydsLesson.completedAt = now
        context.insert(ydsLesson)
        context.insert(LessonProgress(userID: userID, lessonID: "business-lesson", startedAt: now))
        try context.save()
        return context
    }

    @MainActor
    func test_listsPackagesInUIOrder_withAccessAndActiveGoal() throws {
        let vm = GoalSwitcherViewModel(context: try makeContext(), userID: userID, accessProvider: OwnsOnly(id: "yds"), language: .english)
        XCTAssertEqual(vm.options.map(\.id), ["business", "yds"])
        XCTAssertEqual(vm.options.last?.isForTurkishSpeakers, true)
        XCTAssertEqual(vm.options.first?.summary, "Meetings and email")
        XCTAssertEqual(vm.ownedPackageIDs, ["yds"])
        XCTAssertEqual(vm.activePackageID, "yds")
    }

    @MainActor
    func test_select_switchesActivePackage_andKeepsEveryPackagesProgress() throws {
        let context = try makeContext()
        let vm = GoalSwitcherViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview), language: .turkish)
        XCTAssertTrue(try vm.select("business"))
        XCTAssertEqual(vm.activePackageID, "business")

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.activePackageID, "business")
        let coordinator = TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview))
        XCTAssertEqual(try coordinator.activePackage()?.id, "business")

        let progress = try context.fetch(FetchDescriptor<LessonProgress>())
        XCTAssertEqual(Set(progress.map(\.lessonID)), ["yds-lesson", "business-lesson"])
        XCTAssertNotNil(progress.first { $0.lessonID == "yds-lesson" }?.completedAt)
    }

    @MainActor
    func test_englishUI_keepsAPackageTheLearnerHasProgressIn() throws {
        let context = try makeContext()
        let ydsUnit = LearningEngine.Unit(id: "yds-unit", theme: "t", order: 0)
        let ydsLesson = Lesson(id: "yds-lesson", order: 0, estimatedDurationMinutes: 5)
        ydsUnit.lessons = [ydsLesson]
        let yds = try XCTUnwrap(context.fetch(FetchDescriptor<ContentPackage>()).first { $0.id == "yds" })
        yds.units = [ydsUnit]
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        profile.activePackageID = "business"
        try context.save()
        let vm = GoalSwitcherViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview), language: .english)
        XCTAssertEqual(Set(vm.options.map(\.id)), ["business", "yds"], "switching away must not strand YDS progress")
    }

    @MainActor
    func test_englishUI_hidesYDSWhenNeitherActiveNorOwned() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        profile.activePackageID = "business"
        try context.save()
        let vm = GoalSwitcherViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview), language: .english)
        XCTAssertEqual(vm.options.map(\.id), ["business"])
    }

    @MainActor
    func test_select_sameOrUnknownPackage_changesNothing() throws {
        let context = try makeContext()
        let vm = GoalSwitcherViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview))
        XCTAssertFalse(try vm.select("yds"))
        XCTAssertFalse(try vm.select("missing"))
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearnerProfile>()).first?.activePackageID, "yds")
    }
}

final class OnboardingPackagePickerTests: XCTestCase {
    @MainActor
    func test_englishUI_offersPackagesForEveryoneFirst_andUsesTargetWording() throws {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(ContentPackage(id: "yds", name: "YDS Academic", goal: .yds, levelLower: "B2", levelUpper: "C1", audience: "tr"))
        context.insert(ContentPackage(id: "everyday", name: "Everyday English", goal: .conversational, levelLower: "A2", levelUpper: "B1"))
        try context.save()

        let vm = OnboardingViewModel(context: context, userID: "u", language: .english)
        XCTAssertEqual(vm.goalOptions.map(\.id), ["everyday"], "YDS is written for Turkish speakers: hidden on English UI")
        XCTAssertEqual(vm.selectedPackageID, "everyday")
        XCTAssertFalse(vm.selectedGoalIsExam)

        let owner = OnboardingViewModel(context: context, userID: "u", language: .english, ownedPackageIDs: ["yds"])
        XCTAssertEqual(owner.goalOptions.map(\.id), ["everyday", "yds"], "a bought package stays visible")
        owner.selectedPackageID = "yds"
        XCTAssertTrue(owner.selectedGoalIsExam)

        let turkish = OnboardingViewModel(context: context, userID: "u", language: .turkish)
        XCTAssertEqual(turkish.goalOptions.map(\.id), ["yds", "everyday"])
    }

    func test_dateWording_followsTheGoal() {
        XCTAssertEqual(DateWording(isExam: true).title, "Exam date")
        XCTAssertEqual(DateWording(isExam: false).title, "Target date")
        XCTAssertEqual(DateWording(isExam: false).question, "Do you have a target date?")
    }
}

