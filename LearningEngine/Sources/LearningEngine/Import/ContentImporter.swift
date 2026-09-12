import Foundation
import SwiftData

public enum ContentImportError: Error, Equatable {
    case invalidGoal(String)
    case invalidItemType(String)
    case decodingFailed(String)
}

public enum ContentImporter {
    public static func importPackage(from data: Data, into context: ModelContext) throws -> ContentPackage {
        let document: ContentPackageDocument
        do {
            document = try JSONDecoder().decode(ContentPackageDocument.self, from: data)
        } catch {
            throw ContentImportError.decodingFailed(error.localizedDescription)
        }

        guard let goal = LearningGoal(rawValue: document.goal) else {
            throw ContentImportError.invalidGoal(document.goal)
        }

        let package = ContentPackage(id: document.id, name: document.name, goal: goal, levelLower: document.levelLower, levelUpper: document.levelUpper)

        var units: [Unit] = []
        for unitDoc in document.units {
            let unit = Unit(id: unitDoc.id, theme: unitDoc.theme, order: unitDoc.order)
            var lessons: [Lesson] = []
            for lessonDoc in unitDoc.lessons {
                let lesson = Lesson(id: lessonDoc.id, order: lessonDoc.order, estimatedDurationMinutes: lessonDoc.estimatedDurationMinutes)
                var items: [LearningItem] = []
                for itemDoc in lessonDoc.items {
                    guard let type = LearningItemType(rawValue: itemDoc.type) else {
                        throw ContentImportError.invalidItemType(itemDoc.type)
                    }
                    let item = LearningItem(id: itemDoc.id, type: type, frequencyRank: itemDoc.frequencyRank, baseDifficulty: itemDoc.baseDifficulty)
                    let content = ItemContent(
                        id: "\(itemDoc.id)-content",
                        headword: itemDoc.headword,
                        definition: itemDoc.definition,
                        exampleSentences: itemDoc.exampleSentences,
                        translationTR: itemDoc.translationTR,
                        collocations: itemDoc.collocations
                    )
                    item.content = content
                    content.item = item
                    item.lesson = lesson
                    items.append(item)
                }
                lesson.items = items
                lesson.unit = unit
                lessons.append(lesson)
            }
            unit.lessons = lessons
            unit.package = package
            units.append(unit)
        }
        package.units = units

        context.insert(package)
        return package
    }
}
