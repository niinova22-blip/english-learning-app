import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

/// Runtime smoke test: `EnglishAppTests` is hosted by the `EnglishApp`
/// application (XcodeGen wires this up automatically via TEST_HOST because
/// this test target depends on the `EnglishApp` target), so `Bundle.main`
/// here resolves to the actual app bundle rather than the test bundle.
///
/// This exercises the exact resource-resolution path
/// `AppModelContainer.seedRealContentIfNeeded` uses in production
/// (`Bundle.main.url(forResource:withExtension:)`), which the
/// LearningEngine-side `ContentImporterTests` cannot cover because it loads
/// the fixture from `Bundle.module`, not from an app bundle produced by the
/// `App/project.yml` `resources:` entry. This is the only thing that would
/// catch a resource-bundling misconfiguration that compiles fine but fails
/// at runtime.
final class RealContentSeedingTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsEveryItem() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle — check App/project.yml's resources: entry")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()

        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.units.count, 9)
        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertEqual(allItems.count, 157)
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })

        // Regression guard for the mangled-Turkish-characters bug (Task 6): a bare
        // `content != nil` check would not catch garbled-but-non-empty strings.
        let economyItem = allItems.first { $0.id == "yds-vocab1-item-economy" }
        XCTAssertEqual(economyItem?.content?.translationTR, "ekonomi")

        XCTAssertEqual(package.version, 6)
        XCTAssertEqual(package.storeProductID, "com.niinova22.englishapp.package.yds")
        XCTAssertEqual(package.skillWeights.activeSkills, [.vocabulary, .grammar, .reading])
        XCTAssertEqual(package.skillWeights.share(of: .pronunciation), 0)
        let scienceUnit = package.units.first { $0.id == "yds-vocab1-unit-science-research" }
        let secondLesson = scienceUnit?.lessons.first { $0.order == 1 }
        XCTAssertEqual(secondLesson?.title, "Science & Research Methods · 2")

        XCTAssertEqual(package.units.flatMap(\.lessons).flatMap(\.questions).count, 335)
        XCTAssertEqual(package.units.flatMap(\.lessons).compactMap(\.passage).count, 3)
        XCTAssertEqual(Set(package.units.flatMap(\.lessons).map(\.skill)), [.vocabulary, .grammar, .reading])
    }

    /// Structure gate for the Slice 7b grammar curriculum, read from the
    /// shipped app resource. Content correctness is the per-unit review
    /// gate's job; this asserts the mechanical contract the Ders Yolu and
    /// practice screens rely on.
    func test_bundledPackage_grammarUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        XCTAssertEqual(
            units.prefix(4).map(\.id),
            [
                "yds-vocab1-unit-business-economics",
                "yds-vocab1-unit-science-research",
                "yds-vocab1-unit-law-policy-society",
                "yds-vocab1-unit-academic-writing",
            ],
            "the four vocabulary units keep orders 0-3"
        )
        XCTAssertEqual(Array(units.dropFirst(4).map(\.id)), [
                "yds-grammar-unit-verbs-and-tenses",
                "yds-grammar-unit-sentence-structures",
                "yds-grammar-unit-verbals-and-linkers",
                "yds-grammar-unit-exam-level-structures",
                "yds-grammar-unit-word-level-grammar",
            ]
        )
        XCTAssertEqual(Array(units.dropFirst(4).map(\.theme)), 
            ["Fiil ve zaman", "Cümle yapıları", "Fiilimsiler ve bağlantılar", "Sınav düzeyi yapılar", "Kelime düzeyinde gramer"]
        )

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 30)
        XCTAssertEqual(
            units[4].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-tenses-2",
                "yds-grammar-modals-1",
                "yds-grammar-modals-2",
                "yds-grammar-passive-voice-1",
                "yds-grammar-passive-voice-2",
            ]
        )
        XCTAssertEqual(
            units[5].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-conditionals-2",
                "yds-grammar-relative-clauses-1",
                "yds-grammar-relative-clauses-2",
                "yds-grammar-noun-clauses-1",
                "yds-grammar-noun-clauses-2",
                "yds-grammar-reported-speech-1",
                "yds-grammar-reported-speech-2",
            ]
        )
        XCTAssertEqual(
            units[6].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-gerunds-infinitives-1",
                "yds-grammar-gerunds-infinitives-2",
                "yds-grammar-participle-clauses-1",
                "yds-grammar-participle-clauses-2",
                "yds-grammar-conjunctions-linkers-1",
                "yds-grammar-conjunctions-linkers-2",
            ]
        )
        XCTAssertEqual(
            units[7].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-inversion-1",
                "yds-grammar-inversion-2",
                "yds-grammar-subjunctive-1",
                "yds-grammar-subjunctive-2",
            ]
        )
        XCTAssertEqual(
            units[8].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-prepositions-1",
                "yds-grammar-prepositions-2",
                "yds-grammar-comparatives-1",
                "yds-grammar-comparatives-2",
                "yds-grammar-determiners-1",
                "yds-grammar-determiners-2",
                "yds-grammar-articles-1",
                "yds-grammar-articles-2",
            ]
        )

        for lesson in grammarLessons {
            XCTAssertEqual(lesson.skill, .grammar, lesson.id)
            XCTAssertNil(lesson.passage, "\(lesson.id) must not carry a passage")
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .grammarPoint, lesson.id)
            XCTAssertEqual(
                card.id,
                "yds-grammar-card-" + String(lesson.id.dropFirst("yds-grammar-".count)),
                lesson.id
            )
            XCTAssertFalse(
                (card.content?.explanationTR ?? "").isEmpty,
                "\(lesson.id) card has an empty explanationTR"
            )
            let isFirstLesson = lesson.id.hasSuffix("-1")
            XCTAssertEqual(lesson.questions.count, isFirstLesson ? 8 : 10, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, isFirstLesson ? 8 : 10, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, .grammar, question.id)
                XCTAssertEqual(question.options.count, 5, question.id)
                XCTAssertTrue((0...4).contains(question.correctIndex), question.id)
                XCTAssertFalse(question.explanationTR.isEmpty, question.id)
                XCTAssertNil(question.passage, question.id)
            }
        }
    }

    func test_seedRealContentIfNeeded_populatesEmptyStore_andIsIdempotent() throws {
        let context = try makeInMemoryContext()

        AppModelContainer.seedRealContentIfNeeded(in: context)

        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.count, 1)
        let allItems = packages.flatMap { $0.units.flatMap { $0.lessons.flatMap { $0.items } } }
        XCTAssertEqual(allItems.count, 157)

        // Calling again must not duplicate content.
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let packagesAfterSecondCall = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packagesAfterSecondCall.count, 1)
    }
}
