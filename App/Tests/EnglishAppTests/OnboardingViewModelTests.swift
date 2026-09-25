import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class OnboardingViewModelTests: XCTestCase {
    let userID = "u"
    lazy var now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext(richContent: Bool = false) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if richContent {
            _ = try ContentSeeder.seed(bundledData: RichLevelTestPackageJSON.make(), into: context)
        } else {
            _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        }
        return context
    }

    @MainActor
    func test_advance_movesThroughLinearSteps() throws {
        let vm = OnboardingViewModel(context: try makeContext(), userID: userID, clock: { self.now })
        XCTAssertEqual(vm.step, .goalSelection)
        vm.advance()
        XCTAssertEqual(vm.step, .examDate)
        vm.advance()
        XCTAssertEqual(vm.step, .dailyDuration)
        vm.advance()
        XCTAssertEqual(vm.step, .reminder)
        vm.advance()
        XCTAssertEqual(vm.step, .levelTestIntro)
    }

    @MainActor
    func test_goBack_returnsToPreviousStep() throws {
        let vm = OnboardingViewModel(context: try makeContext(), userID: userID, clock: { self.now })
        vm.advance() // examDate
        vm.advance() // dailyDuration
        vm.goBack()
        XCTAssertEqual(vm.step, .examDate)
    }

    @MainActor
    func test_quittingMidFlow_persistsNoProfile() throws {
        let context = try makeContext()
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.advance()
        vm.advance()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearnerProfile>()), 0)
    }

    @MainActor
    func test_notEnoughVocabularyCandidates_autoSkipsLevelTest() throws {
        // TestPackageJSON has only 8 vocabulary items, below LevelTestEngine.questionCount (12).
        let context = try makeContext()
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.dailyMinutes = 25
        vm.advance() // examDate
        vm.advance() // dailyDuration
        vm.advance() // reminder
        vm.advance() // levelTestIntro — prepares levelTestViewModel
        vm.startLevelTest()
        XCTAssertEqual(vm.step, .done)
        XCTAssertTrue(vm.isOnboardingComplete)

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertTrue(profile.hasSkippedLevelTest)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LevelTestResult>()), 0)
    }

    @MainActor
    func test_skipLevelTest_persistsProfileWithoutResult() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.examDate = now
        vm.dailyMinutes = 30
        vm.advance()
        vm.advance()
        vm.advance()
        vm.advance()
        vm.skipLevelTest()

        XCTAssertEqual(vm.step, .done)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 30)
        XCTAssertEqual(profile.examDate, now)
        XCTAssertEqual(profile.onboardingCompletedAt, now)
        XCTAssertTrue(profile.hasSkippedLevelTest)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LevelTestResult>()), 0)
    }

    @MainActor
    func test_completingLevelTest_persistsProfileAndResult() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.advance()
        vm.advance()
        vm.advance()
        vm.advance()
        vm.startLevelTest()
        XCTAssertEqual(vm.step, .levelTest)

        var iterations = 0
        while let question = vm.levelTestViewModel?.currentQuestion, iterations < LevelTestEngine.questionCount {
            vm.answerLevelTestQuestion(selectedIndex: question.correctIndex)
            iterations += 1
        }
        XCTAssertEqual(vm.step, .levelTestResult)
        vm.finishFromResult()
        XCTAssertEqual(vm.step, .done)
        XCTAssertTrue(vm.isOnboardingComplete)

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertFalse(profile.hasSkippedLevelTest)
        let result = try XCTUnwrap(context.fetch(FetchDescriptor<LevelTestResult>()).first)
        XCTAssertEqual(result.userID, userID)
        XCTAssertEqual(result.vocabularyScore, 1.0, accuracy: 1e-9)
    }

    @MainActor
    func test_noInstalledPackages_hasNoPackagesAndCannotAdvance() throws {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let vm = OnboardingViewModel(context: ModelContext(container), userID: userID, clock: { self.now })
        XCTAssertTrue(vm.hasNoPackages)
        XCTAssertNil(vm.selectedPackageID)
        vm.advance()
        XCTAssertEqual(vm.step, .goalSelection)
    }

    func test_rootGate_fallsThroughToTabsWhenNoPackageInstalled() {
        XCTAssertTrue(RootTabView.shouldShowOnboarding(hasCompletedOnboarding: false, hasInstalledPackage: true))
        XCTAssertFalse(RootTabView.shouldShowOnboarding(hasCompletedOnboarding: false, hasInstalledPackage: false))
        XCTAssertFalse(RootTabView.shouldShowOnboarding(hasCompletedOnboarding: true, hasInstalledPackage: true))
    }

    // MARK: Trial offer

    @MainActor
    func test_skip_withTrialOffer_savesTheProfileButFinishesOnlyAfterTheOffer() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.offersTrial = true
        for _ in 0..<4 { vm.advance() }
        vm.skipLevelTest()

        XCTAssertEqual(vm.step, .trialOffer)
        XCTAssertFalse(vm.isOnboardingComplete)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first, "saved before the offer, so a cancelled purchase loses nothing")
        XCTAssertNil(profile.onboardingCompletedAt, "the app switches to the tabs only after the offer")

        vm.finishTrialOffer()
        XCTAssertEqual(vm.step, .done)
        XCTAssertTrue(vm.isOnboardingComplete)
        XCTAssertEqual(profile.onboardingCompletedAt, now)
    }

    @MainActor
    func test_levelTestResult_withTrialOffer_goesToTheOffer() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.offersTrial = true
        for _ in 0..<4 { vm.advance() }
        vm.startLevelTest()
        while let question = vm.levelTestViewModel?.currentQuestion {
            vm.answerLevelTestQuestion(selectedIndex: question.correctIndex)
        }
        vm.finishFromResult()
        XCTAssertEqual(vm.step, .trialOffer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LevelTestResult>()), 1)
    }

    @MainActor
    func test_goBack_fromLevelTestIntro_returnsToTheReminderStep() throws {
        let vm = OnboardingViewModel(context: try makeContext(), userID: userID, clock: { self.now })
        for _ in 0..<4 { vm.advance() }
        XCTAssertEqual(vm.step, .levelTestIntro)
        vm.goBack()
        XCTAssertEqual(vm.step, .reminder)
    }
}

final class TeaserPolicyTests: XCTestCase {
    func test_teaser_hiddenForSevenDaysAfterDismissal() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(TeaserPolicy.shouldShow(lastDismissed: nil, now: now))
        XCTAssertFalse(TeaserPolicy.shouldShow(lastDismissed: now.addingTimeInterval(-6 * 86_400), now: now))
        XCTAssertTrue(TeaserPolicy.shouldShow(lastDismissed: now.addingTimeInterval(-7 * 86_400), now: now))
    }
}

