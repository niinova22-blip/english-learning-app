import XCTest
import SwiftData
@testable import LearningEngine

final class LocalizedTitlesTests: XCTestCase {
    func test_pick_returnsTheRequestedLanguage_elseTheBase() {
        XCTAssertEqual(LocalizedTitles.pick(base: "Base", en: "English", tr: "Türkçe", languageCode: "tr"), "Türkçe")
        XCTAssertEqual(LocalizedTitles.pick(base: "Base", en: "English", tr: "Türkçe", languageCode: "en"), "English")
        XCTAssertEqual(LocalizedTitles.pick(base: "Base", en: nil, tr: "", languageCode: "tr"), "Base")
        XCTAssertEqual(LocalizedTitles.pick(base: "Base", en: "  ", tr: nil, languageCode: "en"), "Base")
        XCTAssertEqual(LocalizedTitles.pick(base: "Base", en: "English", tr: "Türkçe", languageCode: "de"), "Base")
    }

    func makeContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self, Question.self, Passage.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func json(localized: Bool) -> Data {
        let pkg = localized ? #""nameLocalized": {"en": "Pack", "tr": "Paket"}, "summaryLocalized": {"en": "Sum", "tr": "Özet"},"# : ""
        let unit = localized ? #""themeLocalized": {"en": "Theme", "tr": "Tema"},"# : ""
        let lesson = localized ? #""titleLocalized": {"en": "Lesson", "tr": "Ders"},"# : ""
        return """
        { "id": "p", "name": "Base pack", "summary": "Base sum", "goal": "yds", "levelLower": "B2", "levelUpper": "C1", \(pkg)
          "version": 1,
          "skillWeights": {"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [ { "id": "u", "theme": "Base theme", "order": 0, \(unit)
            "lessons": [ { "id": "l", "order": 0, "estimatedDurationMinutes": 5, "title": "Base lesson", "skill": "vocabulary", \(lesson)
              "items": [ { "id": "i", "type": "vocabulary", "headword": "economy", "frequencyRank": 1, "baseDifficulty": 0.3,
                "definition": "d", "exampleSentences": ["e"], "translationTR": "t", "collocations": [] } ] } ] } ] }
        """.data(using: .utf8)!
    }

    func test_importer_copiesEveryLocalizedTitle() throws {
        let package = try ContentImporter.importPackage(from: json(localized: true), into: try makeContext())
        XCTAssertEqual(package.name(for: "tr"), "Paket")
        XCTAssertEqual(package.name(for: "en"), "Pack")
        XCTAssertEqual(package.summary(for: "tr"), "Özet")
        let unit = try XCTUnwrap(package.units.first)
        XCTAssertEqual(unit.theme(for: "tr"), "Tema")
        XCTAssertEqual(unit.theme(for: "en"), "Theme")
        let lesson = try XCTUnwrap(unit.lessons.first)
        XCTAssertEqual(lesson.title(for: "tr"), "Ders")
        XCTAssertEqual(lesson.title(for: "en"), "Lesson")
    }

    func test_packageWithoutLocalizedTitles_fallsBackToBaseFields() throws {
        let package = try ContentImporter.importPackage(from: json(localized: false), into: try makeContext())
        XCTAssertNil(package.nameTR)
        XCTAssertEqual(package.name(for: "tr"), "Base pack")
        XCTAssertEqual(package.summary(for: "en"), "Base sum")
        XCTAssertEqual(package.units.first?.theme(for: "tr"), "Base theme")
        XCTAssertEqual(package.units.first?.lessons.first?.title(for: "en"), "Base lesson")
    }
}
