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

    func test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsAll120ItemsAcrossFourUnits() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle — check App/project.yml's resources: entry")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()

        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.units.count, 4)
        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertEqual(allItems.count, 120)
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })

        // Regression guard for the mangled-Turkish-characters bug (Task 6): a bare
        // `content != nil` check would not catch garbled-but-non-empty strings.
        let economyItem = allItems.first { $0.id == "yds-vocab1-item-economy" }
        XCTAssertEqual(economyItem?.content?.translationTR, "ekonomi")

        XCTAssertEqual(package.version, 3)
        XCTAssertEqual(package.skillWeights.activeSkills, [.vocabulary, .grammar, .reading])
        XCTAssertEqual(package.skillWeights.share(of: .pronunciation), 0)
        let scienceUnit = package.units.first { $0.id == "yds-vocab1-unit-science-research" }
        let secondLesson = scienceUnit?.lessons.first { $0.order == 1 }
        XCTAssertEqual(secondLesson?.title, "Science & Research Methods · 2")
        XCTAssertTrue(package.units.flatMap(\.lessons).allSatisfy { $0.skill == .vocabulary })
    }

    func test_seedRealContentIfNeeded_populatesEmptyStore_andIsIdempotent() throws {
        let context = try makeInMemoryContext()

        AppModelContainer.seedRealContentIfNeeded(in: context)

        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.count, 1)
        let allItems = packages.flatMap { $0.units.flatMap { $0.lessons.flatMap { $0.items } } }
        XCTAssertEqual(allItems.count, 120)

        // Calling again must not duplicate content.
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let packagesAfterSecondCall = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packagesAfterSecondCall.count, 1)
    }
}
