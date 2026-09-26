import XCTest
import SwiftData
@testable import LearningEngine

final class LessonCardsTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self, Question.self, Passage.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    static let cardsJSON = #"""
    { "topics": [ {
        "title": {"en": "Present simple for habits", "tr": "Alışkanlıklar için geniş zaman"},
        "purpose": {"en": "Use it for routines.", "tr": "Düzenli yaptığın şeyler için."},
        "pattern": [{"text": "he / she / it", "role": "subject"}, {"text": "verb + s", "role": "verb"}],
        "patternNote": {"en": "Add -s after he, she, it.", "tr": "-s sadece he, she, it ile."},
        "examples": [
          {"en": "I drink coffee.", "tr": "Kahve içerim.", "highlight": "drink"},
          {"en": "She works here.", "tr": "Burada çalışır.", "highlight": "works"},
          {"en": "We walk to school.", "tr": "Okula yürürüz.", "highlight": "walk"} ],
        "mistake": {"wrong": "He work.", "right": "He works.", "note": {"en": "Add -s.", "tr": "-s ekle."}} } ],
      "check": {"prompt": "She ---- tea.", "options": ["drink", "drinks", "drinking"], "correctIndex": 1,
        "explanation": {"en": "She takes -s.", "tr": "She ile -s gelir."}},
      "examTip": {"en": "Watch the subject.", "tr": "Özneye dikkat."} }
    """#

    func json(withNewFields: Bool) -> Data {
        let intro = withNewFields ? #""introLocalized": {"en": "Intro", "tr": "Tanıtım"},"# : ""
        let cards = withNewFields ? #""lessonCards": \#(Self.cardsJSON),"# : ""
        let explanation = withNewFields ? #""explanationLocalized": {"en": "Because she.", "tr": "Çünkü she."},"# : ""
        let bodyTR = withNewFields ? #", "bodyTR": "Türkçe metin""# : ""
        return """
        { "id": "p", "name": "Pack", "goal": "yds", "levelLower": "B1", "levelUpper": "B2", "version": 1, \(intro)
          "skillWeights": {"vocabulary": 1, "grammar": 1, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [ { "id": "u", "theme": "T", "order": 0,
            "lessons": [ { "id": "l", "order": 0, "estimatedDurationMinutes": 5, "title": "L", "skill": "grammar",
              "items": [ { "id": "g", "type": "grammarPoint", "headword": "Present simple", "frequencyRank": 1, "baseDifficulty": 0.3,
                "definition": "d", "exampleSentences": [], "translationTR": "", "collocations": [], \(cards)
                "explanationTR": "Old explanation" } ],
              "passage": { "id": "pa", "title": "Text", "body": "English text"\(bodyTR) },
              "questions": [ { "id": "q", "kind": "grammar", "order": 0, "prompt": "She ---- tea.", \(explanation)
                "options": ["a", "b", "c", "d", "e"], "correctIndex": 1, "explanationTR": "Base explanation", "passageID": "pa" } ] } ] } ] }
        """.data(using: .utf8)!
    }

    func test_importer_storesCardsExplanationsPassageTranslationAndIntro() throws {
        let package = try ContentImporter.importPackage(from: json(withNewFields: true), into: try makeContext())
        let lesson = try XCTUnwrap(package.units.first?.lessons.first)
        let expected = try JSONDecoder().decode(LessonCards.self, from: Data(Self.cardsJSON.utf8))
        XCTAssertEqual(lesson.items.first?.content?.lessonCards, expected)
        XCTAssertEqual(expected.topics.first?.examples.count, 3)
        XCTAssertEqual(expected.check.correctIndex, 1)
        XCTAssertEqual(expected.examTip?.text(for: "tr"), "Özneye dikkat.")
        let question = try XCTUnwrap(lesson.questions.first)
        XCTAssertEqual(question.explanation(for: "en"), "Because she.")
        XCTAssertEqual(question.explanation(for: "tr"), "Çünkü she.")
        XCTAssertEqual(lesson.passage?.bodyTR, "Türkçe metin")
        XCTAssertEqual(package.intro(for: "tr"), "Tanıtım")
        XCTAssertEqual(package.intro(for: "en"), "Intro")
    }

    func test_oldJSONWithoutNewFields_importsUnchanged() throws {
        let package = try ContentImporter.importPackage(from: json(withNewFields: false), into: try makeContext())
        let lesson = try XCTUnwrap(package.units.first?.lessons.first)
        let content = try XCTUnwrap(lesson.items.first?.content)
        XCTAssertNil(content.lessonCards)
        XCTAssertNil(content.lessonCardsJSON)
        XCTAssertEqual(content.explanationTR, "Old explanation")
        let question = try XCTUnwrap(lesson.questions.first)
        XCTAssertNil(question.explanationEN)
        XCTAssertNil(question.explanationTRText)
        XCTAssertEqual(question.explanation(for: "tr"), "Base explanation")
        XCTAssertEqual(question.explanation(for: "en"), "Base explanation")
        XCTAssertNil(lesson.passage?.bodyTR)
        XCTAssertNil(package.intro(for: "tr"))
    }

    func test_textFor_fallsBackToTheOtherSide_thenEmpty() {
        XCTAssertEqual(LocalizedTextDocument(en: "E", tr: "T").text(for: "tr"), "T")
        XCTAssertEqual(LocalizedTextDocument(en: "E", tr: "T").text(for: "en"), "E")
        XCTAssertEqual(LocalizedTextDocument(en: "E", tr: nil).text(for: "tr"), "E")
        XCTAssertEqual(LocalizedTextDocument(en: " ", tr: "T").text(for: "en"), "T")
        XCTAssertEqual(LocalizedTextDocument(en: nil, tr: "").text(for: "en"), "")
    }

    func test_questionExplanation_usesOneLocalizedSide_elseBase() {
        let question = Question(id: "q", prompt: "p", options: [], correctIndex: 0, explanationTR: "Base", kind: .grammar, order: 0)
        question.explanationEN = "English"
        XCTAssertEqual(question.explanation(for: "en"), "English")
        XCTAssertEqual(question.explanation(for: "tr"), "Base")
    }

    func test_intro_fallsBackToTheOtherSide() {
        let package = ContentPackage(id: "p", name: "P", goal: .business, levelLower: "A2", levelUpper: "B1")
        package.introEN = "Intro"
        XCTAssertEqual(package.intro(for: "tr"), "Intro")
    }
}
