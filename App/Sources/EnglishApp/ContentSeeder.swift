import Foundation
import SwiftData
import LearningEngine

enum SeedOutcome: Equatable {
    case imported
    case upgraded(from: Int, to: Int)
    case upToDate
}

enum ContentSeeder {
    private struct Header: Decodable {
        let id: String
        let version: Int
    }

    /// Imports the bundled package, or replaces a stored older version.
    /// User state (UserItemState, ReviewLog, LessonProgress) is keyed by
    /// stable string IDs and is never touched.
    static func seed(bundledData data: Data, into context: ModelContext) throws -> SeedOutcome {
        let header: Header
        do {
            header = try JSONDecoder().decode(Header.self, from: data)
        } catch {
            throw ContentImportError.decodingFailed(error.localizedDescription)
        }

        let packageID = header.id
        let existing = try context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first
        if let existing, existing.version >= header.version {
            return .upToDate
        }

        // Validate the whole document in a throwaway store first, so invalid
        // content can never delete what is already installed.
        let scratchSchema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self])
        let scratch = try ModelContainer(for: scratchSchema, configurations: [ModelConfiguration(schema: scratchSchema, isStoredInMemoryOnly: true)])
        _ = try ContentImporter.importPackage(from: data, into: ModelContext(scratch))

        let previousVersion = existing?.version
        if let existing {
            context.delete(existing)
            try context.save()
        }
        do {
            _ = try ContentImporter.importPackage(from: data, into: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return previousVersion.map { .upgraded(from: $0, to: header.version) } ?? .imported
    }
}
