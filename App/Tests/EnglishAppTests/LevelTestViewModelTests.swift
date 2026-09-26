import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class LevelTestViewModelTests: XCTestCase {
    func makeCandidates(count: Int = 15) -> [LevelTestCandidate] {
        (0..<count).map { i in
            LevelTestCandidate(itemID: "item-\(i)", headword: "word\(i)", meaning: "anlam\(i)", baseDifficulty: 0.15 + Double(i) * (0.45 / Double(count - 1)))
        }
    }

    @MainActor
    func test_isReady_falseWhenFewerThanQuestionCount() {
        let vm = LevelTestViewModel(candidates: makeCandidates(count: 5))
        XCTAssertFalse(vm.isReady)
    }

    @MainActor
    func test_isReady_requiresQuestionCountPlusThreeCandidates() {
        XCTAssertEqual(LevelTestEngine.minimumCandidates, LevelTestEngine.questionCount + 3)
        for count in 12...14 {
            XCTAssertFalse(LevelTestViewModel(candidates: makeCandidates(count: count)).isReady, "\(count) candidates")
        }
        XCTAssertTrue(LevelTestViewModel(candidates: makeCandidates(count: 15)).isReady)
    }

    @MainActor
    func test_start_loadsFirstQuestion() {
        let vm = LevelTestViewModel(candidates: makeCandidates())
        XCTAssertTrue(vm.isReady)
        vm.start()
        XCTAssertNotNil(vm.currentQuestion)
        XCTAssertEqual(vm.questionNumber, 1)
        XCTAssertNil(vm.outcome)
    }

    @MainActor
    func test_answeringAllQuestions_producesOutcome() {
        let vm = LevelTestViewModel(candidates: makeCandidates())
        vm.start()
        var iterations = 0
        while let question = vm.currentQuestion, iterations < LevelTestEngine.questionCount {
            vm.answer(selectedIndex: question.correctIndex)
            iterations += 1
        }
        XCTAssertEqual(iterations, LevelTestEngine.questionCount)
        XCTAssertNotNil(vm.outcome)
        XCTAssertEqual(vm.outcome!.vocabularyScore, 1.0, accuracy: 1e-9)
        XCTAssertNil(vm.currentQuestion)
    }

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_candidateFetcher_returnsOnlyVocabularyItemsFromThePackage() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)

        // A second package built by hand with guaranteed-distinct ids — a second
        // TestPackageJSON.make(id:) call would collide, since its Unit/Lesson ids
        // ("unit-0", "lesson-u0-l0", ...) are hardcoded, not parameterized by id.
        let otherPackage = ContentPackage(id: "other-pkg", name: "Other", goal: .yds, levelLower: "B1", levelUpper: "B2")
        let otherUnit = Unit(id: "other-unit", theme: "Other", order: 0)
        let otherLesson = Lesson(id: "other-lesson", order: 0, estimatedDurationMinutes: 5, title: "Other", skill: .vocabulary)
        let otherItem = LearningItem(id: "other-item", type: .vocabulary, frequencyRank: 1, baseDifficulty: 0.3)
        otherItem.content = ItemContent(id: "other-content", headword: "other", definition: "d", exampleSentences: ["e"], translationTR: "t", collocations: [])
        otherLesson.items = [otherItem]
        otherUnit.lessons = [otherLesson]
        otherPackage.units = [otherUnit]
        context.insert(otherPackage)
        try context.save()

        let candidates = LevelTestCandidateFetcher.fetch(packageID: "pkg", in: context)
        XCTAssertEqual(candidates.count, 8) // TestPackageJSON: 2 units × 2 lessons × 2 items
        XCTAssertTrue(candidates.allSatisfy { $0.itemID.hasPrefix("item-") })
    }

    func test_candidateFetcher_usesTurkishMeaningsOnlyOnTheTurkishUI() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        let items = try context.fetch(FetchDescriptor<LearningItem>()).filter { $0.type == .vocabulary }
        for item in items {
            item.content?.translationTR = "anlam"
            item.content?.definition = "a meaning"
        }
        items.first?.content?.translationTR = ""
        try context.save()

        let english = LevelTestCandidateFetcher.fetch(packageID: "pkg", in: context, language: .english)
        XCTAssertTrue(english.allSatisfy { $0.meaning == "a meaning" }, "English UI never shows Turkish")
        let turkish = LevelTestCandidateFetcher.fetch(packageID: "pkg", in: context, language: .turkish)
        XCTAssertEqual(turkish.filter { $0.meaning == "anlam" }.count, items.count - 1)
        XCTAssertEqual(turkish.filter { $0.meaning == "a meaning" }.count, 1, "missing translation falls back to the definition")
    }
}
