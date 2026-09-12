import Foundation
import SwiftData
import LearningEngine

enum AppModelContainer {
    static let schema = Schema([
        ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
        ReviewLog.self, UserItemState.self
    ])

    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static func seedSampleContentIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)
        let existingCount = (try? context.fetchCount(FetchDescriptor<ContentPackage>())) ?? 0
        guard existingCount == 0 else { return }
        let package = SampleContent.ydsStarterPackage()
        context.insert(package)
        try? context.save()
    }
}
