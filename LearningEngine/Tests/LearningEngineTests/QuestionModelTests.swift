import XCTest
import SwiftData
@testable import LearningEngine

final class QuestionModelTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([
            ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
            Question.self, Passage.self, QuestionAttempt.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_lessonOwnsQuestionsAndPassage_withWiredInverses() throws {
        let context = try makeContext()
        let lesson = Lesson(id: "l1", order: 0, estimatedDurationMinutes: 8, title: "Okuma", skill: .reading)
        let passage = Passage(id: "p1", title: "Carbon Pricing", body: "Body text.")
        let question = Question(
            id: "q1", prompt: "According to the passage, ----.",
            options: ["a", "b", "c", "d", "e"], correctIndex: 1,
            explanationTR: "Metinde ikinci seçenek açıkça belirtiliyor.", kind: .reading, order: 0
        )
        question.lesson = lesson
        question.passage = passage
        passage.lesson = lesson
        context.insert(lesson)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Lesson>()).first)
        XCTAssertEqual(fetched.questions.map(\.id), ["q1"])
        XCTAssertEqual(fetched.passage?.id, "p1")
        XCTAssertEqual(fetched.questions.first?.passage?.title, "Carbon Pricing")
        XCTAssertEqual(fetched.questions.first?.options.count, 5)
        XCTAssertEqual(fetched.questions.first?.kind, .reading)
    }

    func test_deletingLesson_cascadesToQuestionsAndPassage() throws {
        let context = try makeContext()
        let lesson = Lesson(id: "l1", order: 0, estimatedDurationMinutes: 8, title: "Okuma", skill: .reading)
        let passage = Passage(id: "p1", title: "T", body: "B")
        let question = Question(id: "q1", prompt: "p", options: ["a", "b", "c", "d", "e"], correctIndex: 0, explanationTR: "x", kind: .reading, order: 0)
        question.lesson = lesson
        question.passage = passage
        passage.lesson = lesson
        context.insert(lesson)
        try context.save()

        context.delete(lesson)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Question>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Passage>()), 0)
    }

    func test_questionAttempt_roundTripsEveryField() throws {
        let context = try makeContext()
        let answeredAt = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(QuestionAttempt(userID: "u1", questionID: "q1", wasCorrect: false, answeredAt: answeredAt, selectedIndex: 3))
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<QuestionAttempt>()).first)
        XCTAssertEqual(fetched.userID, "u1")
        XCTAssertEqual(fetched.questionID, "q1")
        XCTAssertFalse(fetched.wasCorrect)
        XCTAssertEqual(fetched.answeredAt, answeredAt)
        XCTAssertEqual(fetched.selectedIndex, 3)
    }

    func test_skillForItem_prefersTheOwningLessonsSkill_andFallsBackToTheItemType() {
        XCTAssertEqual(Skill.forItem(type: .practiceSet, lessonSkill: .reading), .reading)
        XCTAssertEqual(Skill.forItem(type: .grammarPoint, lessonSkill: .reading), .reading)
        XCTAssertEqual(Skill.forItem(type: .vocabulary, lessonSkill: nil), .vocabulary)
        XCTAssertEqual(Skill.forItem(type: .grammarPoint, lessonSkill: nil), .grammar)
    }

    func test_isVocabularyCard_isFalseForTopicAndPracticeCards() {
        XCTAssertTrue(LearningItemType.vocabulary.isVocabularyCard)
        XCTAssertTrue(LearningItemType.phrase.isVocabularyCard)
        XCTAssertTrue(LearningItemType.collocation.isVocabularyCard)
        XCTAssertFalse(LearningItemType.grammarPoint.isVocabularyCard)
        XCTAssertFalse(LearningItemType.practiceSet.isVocabularyCard)
    }
}
