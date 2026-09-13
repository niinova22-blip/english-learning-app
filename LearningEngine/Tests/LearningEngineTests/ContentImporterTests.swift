import XCTest
import SwiftData
@testable import LearningEngine

final class ContentImporterTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_importPackage_validJSON_buildsFullHierarchyWithWiredRelationships() throws {
        let json = """
        {
          "id": "test-package",
          "name": "Test Package",
          "goal": "yds",
          "levelLower": "B2",
          "levelUpper": "C1",
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
        {"id":"p","name":"P","goal":"not-a-real-goal","levelLower":"B2","levelUpper":"C1","units":[]}
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
          "units": [{
            "id": "u", "theme": "T", "order": 0,
            "lessons": [{
              "id": "l", "order": 0, "estimatedDurationMinutes": 5,
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

    func test_importPackage_realYDSVocabularyBatch_importsAll120ItemsAcrossFourUnits() throws {
        guard let url = Bundle.module.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("Fixture file not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.units.count, 4)
        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertEqual(allItems.count, 120)
        let uniqueIDs = Set(allItems.map(\.id))
        XCTAssertEqual(uniqueIDs.count, 120, "duplicate item ids found")
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
    }
}
