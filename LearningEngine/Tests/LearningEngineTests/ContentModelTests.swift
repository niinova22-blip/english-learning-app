import XCTest
import SwiftData
@testable import LearningEngine

final class ContentModelTests: XCTestCase {
    func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func test_contentHierarchy_roundTripsThroughSwiftData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let package = ContentPackage(id: "yds", name: "YDS Hazırlık", goal: .yds, levelLower: "B2", levelUpper: "C1")
        let unit = Unit(id: "yds-unit-1", theme: "Business & Finance", order: 0)
        let lesson = Lesson(id: "yds-unit-1-lesson-1", order: 0, estimatedDurationMinutes: 4)
        let item = LearningItem(id: "item-serendipity", type: .vocabulary, frequencyRank: 4821, baseDifficulty: 0.6)
        let content = ItemContent(
            id: "content-serendipity",
            definition: "a pleasant surprise found by chance",
            exampleSentences: ["Meeting her was pure serendipity."],
            translationTR: "tesadüfi mutluluk",
            collocations: ["pure serendipity", "sheer serendipity"]
        )

        item.content = content
        lesson.items.append(item)
        unit.lessons.append(lesson)
        package.units.append(unit)
        context.insert(package)
        try context.save()

        let descriptor = FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == "yds" })
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.units.first?.lessons.first?.items.first?.id, "item-serendipity")
        XCTAssertEqual(fetched.first?.units.first?.lessons.first?.items.first?.content?.translationTR, "tesadüfi mutluluk")
    }
}
