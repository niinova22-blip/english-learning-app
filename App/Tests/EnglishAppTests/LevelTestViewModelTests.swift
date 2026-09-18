import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class LevelTestViewModelTests: XCTestCase {
    func makeCandidates(count: Int = 15) -> [LevelTestCandidate] {
        (0..<count).map { i in
            LevelTestCandidate(itemID: "item-\(i)", headword: "word\(i)", translationTR: "anlam\(i)", baseDifficulty: 0.15 + Double(i) * (0.45 / Double(count - 1)))
        }
    }

    @MainActor
    func test_isReady_falseWhenFewerThanQuestionCount() {
        let vm = LevelTestViewModel(candidates: makeCandidates(count: 5))
        XCTAssertFalse(vm.isReady)
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
        XCTAssertEqual(vm.outcome?.vocabularyScore, 1.0, accuracy: 1e-9)
        XCTAssertNil(vm.currentQuestion)
    }

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_candidateFetcher_returnsOnlyVocabularyItemsFromThePackage() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(id: "pkg-a"), into: context)
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(id: "pkg-b"), into: context)

        let candidates = LevelTestCandidateFetcher.fetch(packageID: "pkg-a", in: context)
        XCTAssertEqual(candidates.count, 8) // TestPackageJSON: 2 units × 2 lessons × 2 items
        XCTAssertTrue(candidates.allSatisfy { $0.itemID.hasPrefix("item-") })
    }
}
