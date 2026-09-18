import Foundation
import Observation
import SwiftData
import LearningEngine

enum OnboardingStep: Equatable {
    case goalSelection, examDate, dailyDuration, levelTestIntro, levelTest, levelTestResult, done
}

@MainActor
@Observable
final class OnboardingViewModel {
    struct GoalOption: Identifiable, Equatable {
        let id: String
        let name: String
        let levelLower: String
        let levelUpper: String
    }

    private(set) var step: OnboardingStep = .goalSelection
    private(set) var goalOptions: [GoalOption] = []
    var selectedPackageID: String?
    var examDate: Date?
    var dailyMinutes: Int = LearnerProfile.defaultDailyMinutes
    private(set) var levelTestViewModel: LevelTestViewModel?
    private(set) var isOnboardingComplete = false
    private(set) var loadError: String?

    private let context: ModelContext
    private let userID: String
    private let clock: () -> Date

    init(context: ModelContext, userID: String, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.userID = userID
        self.clock = clock
        loadGoalOptions()
    }

    private func loadGoalOptions() {
        let packages = (try? context.fetch(FetchDescriptor<ContentPackage>(sortBy: [SortDescriptor(\.id)]))) ?? []
        goalOptions = packages.map { GoalOption(id: $0.id, name: $0.name, levelLower: $0.levelLower, levelUpper: $0.levelUpper) }
        selectedPackageID = goalOptions.first?.id
    }

    func advance() {
        switch step {
        case .goalSelection: step = .examDate
        case .examDate: step = .dailyDuration
        case .dailyDuration:
            prepareLevelTest()
            step = .levelTestIntro
        case .levelTestIntro, .levelTest, .levelTestResult, .done: break
        }
    }

    func goBack() {
        switch step {
        case .goalSelection, .done: break
        case .examDate: step = .goalSelection
        case .dailyDuration: step = .examDate
        case .levelTestIntro: step = .dailyDuration
        case .levelTest: step = .levelTestIntro
        case .levelTestResult: step = .levelTestIntro
        }
    }

    /// Fraction complete across the 5 user-visible stops (levelTest itself
    /// counts as still "on" levelTestIntro for progress display purposes).
    var progressFraction: Double {
        let order: [OnboardingStep] = [.goalSelection, .examDate, .dailyDuration, .levelTestIntro, .levelTestResult]
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
            profile.onboardingCompletedAt = clock()
            profile.hasSkippedLevelTest = skippedLevelTest

            if let outcome {
                if let existingResult = try context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userIDValue })).first {
                    existingResult.cefrLevel = outcome.cefrLevel
                    existingResult.vocabularyScore = outcome.vocabularyScore
                    existingResult.completedAt = clock()
                } else {
                    context.insert(LevelTestResult(userID: userID, cefrLevel: outcome.cefrLevel, vocabularyScore: outcome.vocabularyScore, completedAt: clock()))
                }
            }
            try context.save()
            step = .done
            isOnboardingComplete = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
