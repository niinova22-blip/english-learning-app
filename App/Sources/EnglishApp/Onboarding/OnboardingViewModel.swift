import Foundation
import Observation
import SwiftData
import LearningEngine

enum OnboardingStep: Equatable {
    case goalSelection, examDate, dailyDuration, reminder, levelTestIntro, levelTest, levelTestResult, trialOffer, done
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .goalSelection
    private(set) var goalOptions: [PackageOption] = []
    var selectedPackageID: String?
    var examDate: Date?
    var dailyMinutes: Int = LearnerProfile.defaultDailyMinutes
    private(set) var levelTestViewModel: LevelTestViewModel?
    private(set) var isOnboardingComplete = false
    /// Length of the AI Premium trial this learner can still start, set by the
    /// view once known; adds the offer step after the level test.
    var trialDays: Int?
    var offersTrial: Bool { trialDays != nil }
    private(set) var loadError: String?

    private let context: ModelContext
    private let userID: String
    private let clock: () -> Date

    init(
        context: ModelContext, userID: String, language: AppLanguage = .current,
        ownedPackageIDs: Set<String> = [], clock: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.userID = userID
        self.clock = clock
        loadGoalOptions(language: language, ownedPackageIDs: ownedPackageIDs)
    }

    private func loadGoalOptions(language: AppLanguage, ownedPackageIDs: Set<String>) {
        let all = (try? context.fetch(FetchDescriptor<ContentPackage>())) ?? []
        let packages = PackageOrdering.visible(all, language: language, activeID: nil, ownedIDs: ownedPackageIDs)
        goalOptions = PackageOrdering.sorted(packages, for: language).map { PackageOption($0, language: language) }
        selectedPackageID = goalOptions.first?.id
    }

    /// Exam goals ask for an exam date; the others for a target date.
    var selectedGoalIsExam: Bool {
        goalOptions.first { $0.id == selectedPackageID }?.isExam ?? true
    }

    /// True when no content package is installed, so there is nothing to pick.
    var hasNoPackages: Bool { goalOptions.isEmpty }

    func advance() {
        switch step {
        case .goalSelection:
            guard !hasNoPackages else { return }
            step = .examDate
        case .examDate: step = .dailyDuration
        case .dailyDuration: step = .reminder
        case .reminder:
            prepareLevelTest()
            step = .levelTestIntro
        case .levelTestIntro, .levelTest, .levelTestResult, .trialOffer, .done: break
        }
    }

    func goBack() {
        switch step {
        case .goalSelection, .trialOffer, .done: break
        case .examDate: step = .goalSelection
        case .dailyDuration: step = .examDate
        case .reminder: step = .dailyDuration
        case .levelTestIntro: step = .reminder
        case .levelTest: step = .levelTestIntro
        case .levelTestResult: step = .levelTestIntro
        }
    }

    /// Fraction complete across the 5 user-visible stops (levelTest itself
    /// counts as still "on" levelTestIntro for progress display purposes).
    var progressFraction: Double {
        let order: [OnboardingStep] = [.goalSelection, .examDate, .dailyDuration, .reminder, .levelTestIntro, .levelTestResult]
        let effective = step == .levelTest ? .levelTestIntro : step
        guard let index = order.firstIndex(of: effective) else { return 1 }
        return Double(index + 1) / Double(order.count)
    }

    private func prepareLevelTest() {
        guard let packageID = selectedPackageID else { return }
        let candidates = LevelTestCandidateFetcher.fetch(packageID: packageID, in: context)
        levelTestViewModel = LevelTestViewModel(candidates: candidates)
    }

    func startLevelTest() {
        guard let levelTestViewModel, levelTestViewModel.isReady else {
            skipLevelTest()
            return
        }
        levelTestViewModel.start()
        step = .levelTest
    }

    func answerLevelTestQuestion(selectedIndex: Int) {
        guard let levelTestViewModel else { return }
        levelTestViewModel.answer(selectedIndex: selectedIndex)
        if levelTestViewModel.outcome != nil {
            step = .levelTestResult
        }
    }

    func skipLevelTest() {
        persist(outcome: nil, skippedLevelTest: true)
    }

    func finishFromResult() {
        persist(outcome: levelTestViewModel?.outcome, skippedLevelTest: false)
    }

    private func persist(outcome: LevelTestOutcome?, skippedLevelTest: Bool) {
        do {
            let userIDValue = userID
            let existingProfile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first
            let profile: LearnerProfile
            if let existingProfile {
                profile = existingProfile
            } else {
                profile = LearnerProfile(userID: userID, activePackageID: selectedPackageID ?? "", createdAt: clock())
                context.insert(profile)
            }
            if let selectedPackageID { profile.activePackageID = selectedPackageID }
            profile.dailyMinutes = dailyMinutes
            profile.examDate = examDate
            profile.hasSkippedLevelTest = skippedLevelTest
            // With the trial offer still to show, completion waits: the root
            // view switches to the tabs as soon as this date is set.
            if !offersTrial { profile.onboardingCompletedAt = clock() }

            if let outcome {
                try LevelTestResultStore.save(outcome, in: context, userID: userID, now: clock())
            } else {
                try context.save()
            }
            if offersTrial {
                step = .trialOffer
            } else {
                step = .done
                isOnboardingComplete = true
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Leaves the trial offer (trial started or "Not now") and enters the app.
    func finishTrialOffer() {
        let userIDValue = userID
        do {
            if let profile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first {
                profile.onboardingCompletedAt = clock()
                try context.save()
            }
            step = .done
            isOnboardingComplete = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
