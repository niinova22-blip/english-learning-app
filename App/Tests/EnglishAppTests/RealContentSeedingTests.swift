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

        XCTAssertEqual(package.units.count, 24)
        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertEqual(allItems.count, 688)
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })

        // Regression guard for the mangled-Turkish-characters bug (Task 6): a bare
        // `content != nil` check would not catch garbled-but-non-empty strings.
        let economyItem = allItems.first { $0.id == "yds-vocab1-item-economy" }
        XCTAssertEqual(economyItem?.content?.translationTR, "ekonomi")

        XCTAssertEqual(package.version, 8)
        XCTAssertEqual(package.storeProductID, "com.niinova22.englishapp.package.yds")
        XCTAssertEqual(package.skillWeights.activeSkills, [.vocabulary, .grammar, .reading])
        XCTAssertEqual(package.skillWeights.share(of: .pronunciation), 0)
        let scienceUnit = package.units.first { $0.id == "yds-vocab1-unit-science-research" }
        let secondLesson = scienceUnit?.lessons.first { $0.order == 1 }
        XCTAssertEqual(secondLesson?.title, "Science & Research Methods · 2")

        XCTAssertEqual(package.units.flatMap(\.lessons).flatMap(\.questions).count, 701)
        XCTAssertEqual(package.units.flatMap(\.lessons).compactMap(\.passage).count, 15)
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
        XCTAssertEqual(Array(units[4..<9].map(\.id)), [
                "yds-grammar-unit-verbs-and-tenses",
                "yds-grammar-unit-sentence-structures",
                "yds-grammar-unit-verbals-and-linkers",
                "yds-grammar-unit-exam-level-structures",
                "yds-grammar-unit-word-level-grammar",
            ]
        )
        XCTAssertEqual(Array(units[4..<9].map(\.theme)), 
            ["Fiil ve zaman", "Cümle yapıları", "Fiilimsiler ve bağlantılar", "Sınav düzeyi yapılar", "Kelime düzeyinde gramer"]
        )

        let grammarLessons = units[4..<9].flatMap(\.lessons)
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

    private struct ExamShape {
        let kind: QuestionKind
        let skill: Skill
        let hasPassage: Bool
        let questions: Int
        let minutes: Int
    }

    private static let examShapes: [String: ExamShape] = [
        "reading": ExamShape(kind: .reading, skill: .reading, hasPassage: true, questions: 5, minutes: 10),
        "cloze": ExamShape(kind: .cloze, skill: .reading, hasPassage: true, questions: 8, minutes: 10),
        "sentence": ExamShape(kind: .sentenceCompletion, skill: .grammar, hasPassage: false, questions: 10, minutes: 9),
        "paragraph": ExamShape(kind: .paragraphCompletion, skill: .reading, hasPassage: false, questions: 8, minutes: 10),
        "irrelevant": ExamShape(kind: .irrelevantSentence, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "dialogue": ExamShape(kind: .dialogueCompletion, skill: .grammar, hasPassage: false, questions: 8, minutes: 8),
        "translation-en-tr": ExamShape(kind: .translation, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "translation-tr-en": ExamShape(kind: .translation, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "restatement": ExamShape(kind: .restatement, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
    ]

    /// Structure gate for the Slice 7c exam units, read from the shipped app
    /// resource. Content correctness is the per-unit review gate's job.
    func test_bundledPackage_examUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let examUnits = Array(units[9..<13])
        XCTAssertEqual(
            examUnits.map(\.id),
            [
                "yds-exam-unit-reading", "yds-exam-unit-cloze-sentence",
                "yds-exam-unit-paragraph", "yds-exam-unit-translation-restatement",
            ]
        )
        XCTAssertEqual(
            examUnits.map(\.theme),
            ["Okuma anlama", "Cloze ve cümle tamamlama", "Paragraf soruları", "Çeviri ve yeniden ifade"]
        )
        XCTAssertEqual(examUnits.map(\.order), [9, 10, 11, 12])
        XCTAssertEqual(
            units[9].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-reading-1", "yds-exam-reading-2", "yds-exam-reading-3", "yds-exam-reading-4",
                "yds-exam-reading-5", "yds-exam-reading-6", "yds-exam-reading-7", "yds-exam-reading-8",
            ]
        )
        XCTAssertEqual(
            units[10].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-cloze-1", "yds-exam-cloze-2", "yds-exam-cloze-3", "yds-exam-cloze-4",
                "yds-exam-sentence-1", "yds-exam-sentence-2", "yds-exam-sentence-3", "yds-exam-sentence-4",
            ]
        )
        XCTAssertEqual(
            units[11].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-paragraph-1", "yds-exam-paragraph-2", "yds-exam-paragraph-3",
                "yds-exam-irrelevant-1", "yds-exam-irrelevant-2", "yds-exam-irrelevant-3",
                "yds-exam-dialogue-1", "yds-exam-dialogue-2",
            ]
        )
        XCTAssertEqual(
            units[12].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-translation-en-tr-1", "yds-exam-translation-en-tr-2", "yds-exam-translation-en-tr-3",
                "yds-exam-translation-tr-en-1", "yds-exam-translation-tr-en-2", "yds-exam-translation-tr-en-3",
                "yds-exam-restatement-1", "yds-exam-restatement-2", "yds-exam-restatement-3",
            ]
        )

        for lesson in examUnits.flatMap(\.lessons) {
            let rest = String(lesson.id.dropFirst("yds-exam-".count))
            let type = String(rest[..<rest.lastIndex(of: "-")!])
            let shape = try XCTUnwrap(Self.examShapes[type], lesson.id)
            XCTAssertEqual(lesson.skill, shape.skill, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, shape.minutes, lesson.id)
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .practiceSet, lesson.id)
            XCTAssertEqual(card.id, "yds-exam-card-" + rest, lesson.id)
            XCTAssertTrue((card.content?.explanationTR ?? "").isEmpty, "\(lesson.id) practiceSet card must not carry an explanation")
            XCTAssertEqual(lesson.questions.count, shape.questions, lesson.id)
            XCTAssertEqual(lesson.passage != nil, shape.hasPassage, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, shape.kind, question.id)
                XCTAssertEqual(question.options.count, 5, question.id)
                XCTAssertTrue((0...4).contains(question.correctIndex), question.id)
                XCTAssertFalse(question.explanationTR.isEmpty, question.id)
                XCTAssertEqual(question.passage?.id, lesson.passage?.id, question.id)
            }
            if type == "cloze", let body = lesson.passage?.body {
                for k in 1...shape.questions {
                    XCTAssertTrue(body.contains("(\(k))----"), "\(lesson.id) passage is missing blank (\(k))")
                }
            }
        }
    }

    private static let techShapes: [String: (kind: QuestionKind, questions: Int, minutes: Int)] = [
        "prefixes": (.grammar, 8, 9), "suffixes": (.grammar, 8, 9),
        "context-clues": (.strategy, 8, 9), "synonyms-collocations": (.strategy, 8, 9),
        "memorisation": (.strategy, 8, 9),
    ]

    /// Structure gate for the Slice 7d technique units, read from the shipped app resource.
    func test_bundledPackage_techniqueUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let techUnits = Array(units[13..<16])
        XCTAssertEqual(
            techUnits.map(\.id),
            ["yds-tech-unit-question-strategies", "yds-tech-unit-exam-management", "yds-tech-unit-vocabulary-skills"]
        )
        XCTAssertEqual(
            techUnits.map(\.theme),
            ["Sınav soru tipi stratejileri", "Sınav yönetimi ve zaman", "Kelime öğrenme teknikleri"]
        )
        XCTAssertEqual(techUnits.map(\.order), [13, 14, 15])
        XCTAssertEqual(
            units[13].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-tech-reading", "yds-tech-cloze", "yds-tech-sentence", "yds-tech-translation",
                "yds-tech-paragraph", "yds-tech-irrelevant", "yds-tech-dialogue", "yds-tech-restatement",
                "yds-tech-vocabulary-questions", "yds-tech-grammar-questions",
            ]
        )
        XCTAssertEqual(
            units[14].lessons.sorted { $0.order < $1.order }.map(\.id),
            ["yds-tech-time-allocation", "yds-tech-elimination", "yds-tech-exam-day"]
        )
        XCTAssertEqual(
            units[15].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-tech-prefixes", "yds-tech-suffixes", "yds-tech-context-clues",
                "yds-tech-synonyms-collocations", "yds-tech-memorisation",
            ]
        )
        for lesson in techUnits.flatMap(\.lessons) {
            let shape = Self.techShapes[String(lesson.id.dropFirst("yds-tech-".count))] ?? (.strategy, 6, 7)
            let slug = String(lesson.id.dropFirst("yds-tech-".count))
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .grammarPoint, lesson.id)
            XCTAssertEqual(card.id, "yds-tech-card-" + slug, lesson.id)
            XCTAssertTrue((card.content?.explanationTR ?? "").contains("En sık düşülen tuzak:"), lesson.id)
            XCTAssertNil(lesson.passage, lesson.id)
            XCTAssertEqual(lesson.questions.count, shape.questions, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, shape.minutes, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, shape.kind, question.id)
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
        XCTAssertEqual(allItems.count, 688)

        // Calling again must not duplicate content.
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let packagesAfterSecondCall = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packagesAfterSecondCall.count, 1)
    }

    /// Structure gate for the Slice 7d vocabulary units, read from the shipped app resource.
    func test_bundledPackage_secondVocabularyUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let vocabUnits = Array(units[16...])
        XCTAssertEqual(vocabUnits.map(\.id), [
            "yds-vocab2-unit-health-medicine", "yds-vocab2-unit-environment-energy",
            "yds-vocab2-unit-technology-innovation", "yds-vocab2-unit-education-learning",
            "yds-vocab2-unit-history-culture", "yds-vocab2-unit-psychology-behaviour",
            "yds-vocab2-unit-politics-governance", "yds-vocab2-unit-media-communication",
        ])
        XCTAssertEqual(vocabUnits.map(\.theme), [
            "Health & Medicine", "Environment & Energy", "Technology & Innovation", "Education & Learning",
            "History & Culture", "Psychology & Behaviour",
            "Politics & Governance", "Media & Communication",
        ])
        XCTAssertEqual(vocabUnits.map(\.order), [16, 17, 18, 19, 20, 21, 22, 23])

        var seenHeadwords = Set<String>()
        for unit in vocabUnits {
            XCTAssertEqual(unit.lessons.count, 6, unit.id)
            let slug = String(unit.id.dropFirst("yds-vocab2-unit-".count))
            XCTAssertEqual(
                unit.lessons.sorted { $0.order < $1.order }.map(\.id),
                (1...6).map { "yds-vocab2-lesson-\(slug)-\($0)" }
            )
            for lesson in unit.lessons {
                XCTAssertEqual(lesson.skill, .vocabulary, lesson.id)
                XCTAssertEqual(lesson.estimatedDurationMinutes, 5, lesson.id)
                XCTAssertTrue(lesson.questions.isEmpty, lesson.id)
                XCTAssertEqual(lesson.items.count, 10, lesson.id)
                for item in lesson.items {
                    XCTAssertEqual(item.type, .vocabulary, item.id)
                    let content = try XCTUnwrap(item.content, item.id)
                    XCTAssertEqual(content.exampleSentences.count, 3, item.id)
                    XCTAssertEqual(content.collocations.count, 3, item.id)
                    XCTAssertFalse(content.translationTR.isEmpty, item.id)
                    XCTAssertTrue(seenHeadwords.insert(content.headword).inserted, "duplicate headword \(content.headword)")
                }
            }
        }
        XCTAssertEqual(seenHeadwords.count, vocabUnits.count * 60)
    }
}
