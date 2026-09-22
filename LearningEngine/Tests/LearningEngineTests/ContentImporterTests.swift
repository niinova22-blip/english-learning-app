import XCTest
import SwiftData
@testable import LearningEngine

final class ContentImporterTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self, Question.self, Passage.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    /// Builds a minimal valid package JSON. `lessonExtra`/`packageExtra` let
    /// individual tests break exactly one field.
    func packageJSON(
        version: String = "1",
        skillWeights: String = #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#,
        lessonSkill: String = "vocabulary",
        goal: String = "yds",
        itemType: String = "vocabulary",
        storeProductID: String? = nil
    ) -> Data {
        let storeLine = storeProductID.map { #""storeProductID": "\#($0)","# } ?? ""
        return """
        {
          "id": "test-package", "name": "Test Package", "goal": "\(goal)",
          "levelLower": "B2", "levelUpper": "C1",
          \(storeLine)
          "version": \(version),
          "skillWeights": \(skillWeights),
          "units": [
            { "id": "test-unit-1", "theme": "Test Theme", "order": 0,
              "lessons": [
                { "id": "test-lesson-1", "order": 0, "estimatedDurationMinutes": 5,
                  "title": "Test Theme · 1", "skill": "\(lessonSkill)",
                  "items": [
                    { "id": "test-item-economy", "type": "\(itemType)", "headword": "economy",
                      "frequencyRank": 100, "baseDifficulty": 0.3,
                      "definition": "the system of production and trade",
                      "exampleSentences": ["The economy grew."],
                      "translationTR": "ekonomi", "collocations": ["global economy"] }
                  ] }
              ] }
          ]
        }
        """.data(using: .utf8)!
    }

    func test_importPackage_validJSON_buildsFullHierarchyWithWiredRelationships() throws {
        let json = """
        {
          "id": "test-package",
          "name": "Test Package",
          "goal": "yds",
          "levelLower": "B2",
          "levelUpper": "C1",
          "version": 1,
          "skillWeights": {"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [
            {
              "id": "test-unit-1",
              "theme": "Test Theme",
              "order": 0,
              "lessons": [
                {
                  "id": "test-lesson-1",
                  "order": 0,
                  "estimatedDurationMinutes": 5,
                  "title": "Test Theme · 1",
                  "skill": "vocabulary",
                  "items": [
                    {
                      "id": "test-item-economy",
                      "type": "vocabulary",
                      "headword": "economy",
                      "frequencyRank": 100,
                      "baseDifficulty": 0.3,
                      "definition": "the system of production and trade",
                      "exampleSentences": ["The economy grew."],
                      "translationTR": "ekonomi",
                      "collocations": ["global economy"]
                    },
                    {
                      "id": "test-item-finance",
                      "type": "vocabulary",
                      "headword": "finance",
                      "frequencyRank": 101,
                      "baseDifficulty": 0.3,
                      "definition": "the management of money",
                      "exampleSentences": ["She works in finance."],
                      "translationTR": "finans",
                      "collocations": ["personal finance"]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: json, into: context)
        try context.save()

        XCTAssertEqual(package.goal, .yds)
        XCTAssertEqual(package.units.count, 1)
        let unit = package.units[0]
        XCTAssertEqual(unit.package?.id, package.id)
        let lesson = unit.lessons[0]
        XCTAssertEqual(lesson.unit?.id, unit.id)
        XCTAssertEqual(lesson.items.count, 2)
        for item in lesson.items {
            XCTAssertNotNil(item.content)
            XCTAssertEqual(item.lesson?.id, lesson.id)
            XCTAssertEqual(item.content?.item?.id, item.id)
        }
    }

    func test_importPackage_unrecognizedGoal_throwsInvalidGoal() throws {
        let json = """
        {"id":"p","name":"P","goal":"not-a-real-goal","levelLower":"B2","levelUpper":"C1","version":1,"skillWeights":{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},"units":[]}
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.invalidGoal(let value) = error else {
                return XCTFail("expected invalidGoal, got \(error)")
            }
            XCTAssertEqual(value, "not-a-real-goal")
        }
    }

    func test_importPackage_unrecognizedItemType_throwsInvalidItemType() throws {
        let json = """
        {
          "id": "p", "name": "P", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "version": 1,
          "skillWeights": {"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [{
            "id": "u", "theme": "T", "order": 0,
            "lessons": [{
              "id": "l", "order": 0, "estimatedDurationMinutes": 5,
              "title": "T · 1", "skill": "vocabulary",
              "items": [{
                "id": "i", "type": "not-a-real-type", "headword": "x", "frequencyRank": 1,
                "baseDifficulty": 0.1, "definition": "d", "exampleSentences": ["e"],
                "translationTR": "t", "collocations": []
              }]
            }]
          }]
        }
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.invalidItemType(let value) = error else {
                return XCTFail("expected invalidItemType, got \(error)")
            }
            XCTAssertEqual(value, "not-a-real-type")
        }
    }

    func test_importPackage_malformedJSON_throwsDecodingFailed() throws {
        let json = "{ this is not valid json".data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.decodingFailed = error else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
        }
    }

    func test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion() throws {
        guard let url = Bundle.module.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("Fixture file not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.version, 8)
        XCTAssertEqual(package.storeProductID, "com.niinova22.englishapp.package.yds")
        XCTAssertEqual(package.units.count, 22)
        let allLessons = package.units.flatMap(\.lessons)
        let allItems = allLessons.flatMap(\.items)
        XCTAssertEqual(allItems.count, 568)
        XCTAssertEqual(Set(allItems.map(\.id)).count, 568, "duplicate item ids found")
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
        XCTAssertEqual(allItems.filter { $0.type == .vocabulary }.count, 480)
        XCTAssertEqual(allItems.filter { $0.type == .grammarPoint }.count, 50)
        XCTAssertEqual(allItems.filter { $0.type == .practiceSet }.count, 38)

        let allQuestions = allLessons.flatMap(\.questions)
        XCTAssertEqual(allQuestions.count, 701)
        XCTAssertEqual(Set(allQuestions.map(\.id)).count, 701, "duplicate question ids found")
        XCTAssertTrue(allQuestions.allSatisfy { $0.options.count == 5 })
        XCTAssertTrue(allQuestions.allSatisfy { (0...4).contains($0.correctIndex) })
        XCTAssertTrue(allQuestions.allSatisfy { !$0.explanationTR.isEmpty })

        // Every practice lesson sits in the free-preview unit, so a preview
        // user can actually reach this slice.
        let firstUnit = try XCTUnwrap(package.units.first { $0.order == 0 })
        XCTAssertEqual(firstUnit.lessons.count, 10)
        XCTAssertEqual(
            firstUnit.lessons.sorted { $0.order < $1.order }.map(\.skill),
            [.vocabulary, .vocabulary, .vocabulary, .grammar, .grammar, .reading, .reading, .reading, .grammar, .reading]
        )

        let tenses = try XCTUnwrap(allLessons.first { $0.id == "yds-practice-lesson-tenses" })
        XCTAssertEqual(tenses.questions.count, 8)
        XCTAssertEqual(tenses.items.first?.type, .grammarPoint)
        XCTAssertTrue((tenses.items.first?.content?.explanationTR ?? "").contains("Past perfect"))

        let reading1 = try XCTUnwrap(allLessons.first { $0.id == "yds-practice-lesson-reading-1" })
        XCTAssertEqual(reading1.passage?.id, "yds-practice-passage-reading-1")
        XCTAssertTrue(reading1.questions.allSatisfy { $0.passage?.id == "yds-practice-passage-reading-1" })
        XCTAssertTrue(reading1.questions.allSatisfy { $0.kind == .reading })

        // Regression guard for the mangled-Turkish-characters bug (UTF-8-as-Windows-1252
        // double-encoding, e.g. "ş" -> "ÅŸ") that a prior manual content-assembly step
        // introduced in 91/120 items. A bare `content != nil` check does not catch this,
        // since garbled-but-non-empty strings still pass it.
        let economyItem = allItems.first { $0.id == "yds-vocab1-item-economy" }
        XCTAssertEqual(economyItem?.content?.translationTR, "ekonomi")

        let mojibakeMarkers = ["Ã", "Å", "â€"]
        for item in allItems {
            guard let content = item.content else { continue }
            let fields = [content.translationTR, content.definition, content.explanationTR ?? ""]
                + content.exampleSentences + content.collocations
            for field in fields {
                for marker in mojibakeMarkers {
                    XCTAssertFalse(field.contains(marker), "possible mojibake ('\(marker)') in item \(item.id): \(field)")
                }
            }
        }
        for question in allQuestions {
            for field in [question.prompt, question.explanationTR] + question.options {
                for marker in mojibakeMarkers {
                    XCTAssertFalse(field.contains(marker), "possible mojibake ('\(marker)') in question \(question.id): \(field)")
                }
            }
        }
    }

    func test_importPackage_storesVersionWeightsTitleAndSkill() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: packageJSON(version: "2", skillWeights: #"{"vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)
        try context.save()

        XCTAssertEqual(package.version, 2)
        XCTAssertEqual(package.skillWeights.share(of: .reading), 0.35, accuracy: 1e-9)
        let lesson = package.units[0].lessons[0]
        XCTAssertEqual(lesson.title, "Test Theme · 1")
        XCTAssertEqual(lesson.skill, .vocabulary)
    }

    func test_importPackage_missingSkillInWeights_throwsAndInsertsNothing() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("missing pronunciation"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_unknownSkillKeyInWeights_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0, "dancing": 1}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("unknown dancing"))
        }
    }

    func test_importPackage_negativeWeight_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": -2, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("negative grammar"))
        }
    }

    func test_importPackage_zeroTotalWeights_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 0, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("zero total"))
        }
    }

    func test_importPackage_invalidLessonSkill_throwsAndInsertsNothing() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: packageJSON(lessonSkill: "juggling"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkill("juggling"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_versionBelowOne_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: packageJSON(version: "0"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidVersion(0))
        }
    }

    func test_importPackage_storeProductID_isStoredWhenPresent() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: packageJSON(storeProductID: "com.example.package"), into: context
        )
        XCTAssertEqual(package.storeProductID, "com.example.package")
    }

    func test_importPackage_storeProductID_absentIsNil() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: packageJSON(), into: context)
        XCTAssertNil(package.storeProductID)
    }

    func test_importPackage_blankStoreProductID_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(
            try ContentImporter.importPackage(from: packageJSON(storeProductID: "   "), into: context)
        ) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidStoreProductID)
        }
    }

    /// A one-lesson package with a practice lesson. Every parameter exists so
    /// a single test can break exactly one rule.
    func practiceJSON(
        lessonSkill: String = "grammar",
        itemType: String = "grammarPoint",
        itemExplanation: String = #""explanationTR": "Past perfect, daha önce biten eylemi anlatır.","#,
        questionKind: String = "grammar",
        options: String = #"["a", "b", "c", "d", "e"]"#,
        correctIndex: String = "1",
        questionExplanation: String = "Doğru yanıt ikinci seçenektir.",
        secondQuestionID: String = "test-question-2",
        passage: String = "",
        passageID: String = "null"
    ) -> Data {
        """
        {
          "id": "test-package", "name": "Test Package", "goal": "yds",
          "levelLower": "B2", "levelUpper": "C1", "version": 4,
          "skillWeights": {"vocabulary": 1, "grammar": 1, "reading": 1, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [
            { "id": "test-unit-1", "theme": "Test Theme", "order": 0,
              "lessons": [
                { "id": "test-lesson-1", "order": 0, "estimatedDurationMinutes": 8,
                  "title": "Test Topic", "skill": "\(lessonSkill)",
                  \(passage)
                  "items": [
                    { "id": "test-card-1", "type": "\(itemType)", "headword": "Tenses",
                      "frequencyRank": 1000, "baseDifficulty": 0.5,
                      "definition": "d", "exampleSentences": [], "translationTR": "Zamanlar",
                      "collocations": [], \(itemExplanation) "unused": 0 }
                  ],
                  "questions": [
                    { "id": "test-question-1", "kind": "\(questionKind)", "order": 0,
                      "prompt": "Q1 ----.", "options": \(options), "correctIndex": \(correctIndex),
                      "explanationTR": "\(questionExplanation)", "passageID": \(passageID) },
                    { "id": "\(secondQuestionID)", "kind": "\(questionKind)", "order": 1,
                      "prompt": "Q2 ----.", "options": ["a", "b", "c", "d", "e"], "correctIndex": 0,
                      "explanationTR": "Doğru yanıt birinci seçenektir.", "passageID": null }
                  ] }
              ] }
          ]
        }
        """.data(using: .utf8)!
    }

    func test_importPackage_practiceLesson_buildsQuestionsPassageAndTopicExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: practiceJSON(
                lessonSkill: "reading", itemType: "practiceSet", itemExplanation: "",
                questionKind: "reading",
                passage: #""passage": { "id": "test-passage-1", "title": "Carbon Pricing", "body": "Body." },"#,
                passageID: #""test-passage-1""#
            ),
            into: context)
        try context.save()

        let lesson = package.units[0].lessons[0]
        XCTAssertEqual(lesson.questions.sorted { $0.order < $1.order }.map(\.id), ["test-question-1", "test-question-2"])
        XCTAssertEqual(lesson.passage?.title, "Carbon Pricing")
        let first = try XCTUnwrap(lesson.questions.first { $0.id == "test-question-1" })
        XCTAssertEqual(first.kind, .reading)
        XCTAssertEqual(first.correctIndex, 1)
        XCTAssertEqual(first.options.count, 5)
        XCTAssertEqual(first.passage?.id, "test-passage-1")
        XCTAssertEqual(lesson.items.first?.type, .practiceSet)
    }

    func test_importPackage_grammarLesson_storesTheTurkishTopicExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: practiceJSON(), into: context)
        try context.save()
        XCTAssertEqual(
            package.units[0].lessons[0].items.first?.content?.explanationTR,
            "Past perfect, daha önce biten eylemi anlatır."
        )
    }

    func test_importPackage_vocabularyItem_hasNilExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: packageJSON(), into: context)
        try context.save()
        XCTAssertNil(package.units[0].lessons[0].items.first?.content?.explanationTR)
    }

    func test_importPackage_wrongOptionCount_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(options: #"["a", "b", "c", "d"]"#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidOptionCount("test-question-1", 4))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_correctIndexOutOfRange_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(correctIndex: "5"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .correctIndexOutOfRange("test-question-1", 5))
        }
    }

    func test_importPackage_emptyQuestionExplanation_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(questionExplanation: "   "), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .emptyExplanation("test-question-1"))
        }
    }

    func test_importPackage_emptyGrammarTopicExplanation_throwsForTheLesson() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(itemExplanation: #""explanationTR": "","#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .emptyExplanation("test-lesson-1"))
        }
    }

    func test_importPackage_duplicateQuestionID_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(secondQuestionID: "test-question-1"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .duplicateQuestionID("test-question-1"))
        }
    }

    func test_importPackage_practiceLessonWithoutQuestions_throws() throws {
        let json = """
        {
          "id": "p", "name": "P", "goal": "yds", "levelLower": "B2", "levelUpper": "C1", "version": 4,
          "skillWeights": {"vocabulary": 1, "grammar": 1, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [{ "id": "u", "theme": "T", "order": 0, "lessons": [
            { "id": "grammar-lesson", "order": 0, "estimatedDurationMinutes": 8, "title": "T", "skill": "grammar",
              "items": [{ "id": "c", "type": "grammarPoint", "headword": "h", "frequencyRank": 1,
                          "baseDifficulty": 0.5, "definition": "d", "exampleSentences": [],
                          "translationTR": "t", "collocations": [], "explanationTR": "Açıklama." }] }
          ]}]
        }
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingQuestions("grammar-lesson"))
        }
    }

    func test_importPackage_practiceLessonWithoutACard_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(itemType: "vocabulary", itemExplanation: ""), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingPracticeCard("test-lesson-1"))
        }
    }

    func test_importPackage_questionReferencingAMissingPassage_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(passageID: #""no-such-passage""#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingPassage("test-question-1", "no-such-passage"))
        }
    }

    func test_importPackage_acceptsEveryExtendedQuestionKind() throws {
        for kind in ["paragraphCompletion", "irrelevantSentence", "dialogueCompletion", "restatement", "strategy"] {
            let context = try makeInMemoryContext()
            let package = try ContentImporter.importPackage(from: practiceJSON(questionKind: kind), into: context)
            let questions = package.units.flatMap(\.lessons).flatMap(\.questions)
            XCTAssertEqual(questions.map { $0.kind.rawValue }, [kind, kind], kind)
        }
    }

    func test_importPackage_unknownQuestionKind_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(questionKind: "essay"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidQuestionKind("essay"))
        }
    }
}
