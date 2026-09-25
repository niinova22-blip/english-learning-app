import Foundation
import SwiftData
import LearningEngine

enum AppModelContainer {
    static let schema = Schema([
        ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
        Question.self, Passage.self, QuestionAttempt.self,
        ReviewLog.self, UserItemState.self, LearnerProfile.self, LessonProgress.self, LevelTestResult.self
    ])

    static private(set) var containerCreationError: String?

    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: ScreenshotMode.isOn)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // If the on-disk store can't be opened (e.g. a schema mismatch from
            // an old install with no console access to diagnose), fall back to
            // an in-memory store so the app is at least launchable, rather than
            // permanently fatal-erroring on every future launch. Record the
            // error so Settings can surface the degraded state to the user.
            containerCreationError = error.localizedDescription
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                return fallback
            }
            fatalError("Failed to create ModelContainer, including in-memory fallback: \(error)")
        }
    }

    // Retained for reference / LearningEngine test use only — the app itself seeds real content via
    // seedRealContentIfNeeded; SampleContent remains LearningEngine's internal test fixture (also used
    // directly by App/Tests/EnglishAppTests/TodaySessionCoordinatorTests.swift).
    static func seedSampleContentIfNeeded(in context: ModelContext) {
        let existingCount = (try? context.fetchCount(FetchDescriptor<ContentPackage>())) ?? 0
        guard existingCount == 0 else { return }
        let package = SampleContent.ydsStarterPackage()
        context.insert(package)
        try? context.save()
    }

    /// Seeds every bundled package independently: a missing or broken file
    /// never blocks the others. The first failure is recorded for Profile.
    static func seedRealContentIfNeeded(in context: ModelContext, bundle: Bundle = .main) {
        for failure in BundledPackages.seedAll(from: bundle, into: context) {
            assertionFailure(failure)
            if containerCreationError == nil { containerCreationError = failure }
        }
    }
}
