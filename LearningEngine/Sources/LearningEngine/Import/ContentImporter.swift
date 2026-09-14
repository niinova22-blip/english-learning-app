import Foundation
import SwiftData

public enum ContentImportError: Error, Equatable {
    case invalidGoal(String)
    case invalidItemType(String)
    case decodingFailed(String)
    case invalidSkillWeights(String)
    case invalidSkill(String)
    case invalidVersion(Int)
}

public enum ContentImporter {
    static func validatedWeights(_ raw: [String: Double]) throws -> SkillWeights {
        let known = Set(Skill.allCases.map(\.rawValue))
        if let unknown = raw.keys.sorted().first(where: { !known.contains($0) }) {
            throw ContentImportError.invalidSkillWeights("unknown \(unknown)")
        }
        var values: [Skill: Double] = [:]
        for (key, value) in raw { values[Skill(rawValue: key)!] = value }
        do {
            return try SkillWeights(values)
        } catch SkillWeightsError.missingSkill(let skill) {
            throw ContentImportError.invalidSkillWeights("missing \(skill.rawValue)")
        } catch SkillWeightsError.negativeWeight(let skill) {
            throw ContentImportError.invalidSkillWeights("negative \(skill.rawValue)")
        } catch {
            throw ContentImportError.invalidSkillWeights("zero total")
        }
    }

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

        guard document.version >= 1 else {
            throw ContentImportError.invalidVersion(document.version)
        }
        let weights = try validatedWeights(document.skillWeights)
        for unitDoc in document.units {
            for lessonDoc in unitDoc.lessons where Skill(rawValue: lessonDoc.skill) == nil {
                throw ContentImportError.invalidSkill(lessonDoc.skill)
            }
        }

        let package = ContentPackage(
            id: document.id, name: document.name, goal: goal,
            levelLower: document.levelLower, levelUpper: document.levelUpper,
            version: document.version, skillWeights: weights
        )

        var units: [Unit] = []
        for unitDoc in document.units {
            let unit = Unit(id: unitDoc.id, theme: unitDoc.theme, order: unitDoc.order)
            var lessons: [Lesson] = []
            for lessonDoc in unitDoc.lessons {
                let lesson = Lesson(
                    id: lessonDoc.id, order: lessonDoc.order,
                    estimatedDurationMinutes: lessonDoc.estimatedDurationMinutes,
                    title: lessonDoc.title, skill: Skill(rawValue: lessonDoc.skill)!
                )
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
