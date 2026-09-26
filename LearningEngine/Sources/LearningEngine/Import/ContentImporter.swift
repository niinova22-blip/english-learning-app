import Foundation
import SwiftData

public enum ContentImportError: Error, Equatable {
    case invalidGoal(String)
    case invalidItemType(String)
    case decodingFailed(String)
    case invalidSkillWeights(String)
    case invalidSkill(String)
    case invalidVersion(Int)
    /// `storeProductID` is present but blank.
    case invalidStoreProductID
    /// Unknown `kind` on a question. Payload: the raw string.
    case invalidQuestionKind(String)
    /// Options count != 5. Payload: question id, actual count.
    case invalidOptionCount(String, Int)
    /// `correctIndex` outside 0...4. Payload: question id, the index.
    case correctIndexOutOfRange(String, Int)
    /// An empty `explanationTR`. Payload: the question id, or the lesson id
    /// for an empty grammar-topic explanation.
    case emptyExplanation(String)
    /// The same question id appears twice anywhere in the package.
    case duplicateQuestionID(String)
    /// A lesson whose skill is not `vocabulary` has no questions. Payload: lesson id.
    case missingQuestions(String)
    /// A question references a passage the lesson does not have.
    /// Payload: question id, referenced passage id.
    case missingPassage(String, String)
    /// A lesson whose skill is not `vocabulary` does not own exactly one
    /// `grammarPoint`/`practiceSet` item to act as its FSRS card. Payload: lesson id.
    case missingPracticeCard(String)
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
        if let productID = document.storeProductID,
           productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ContentImportError.invalidStoreProductID
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
            version: document.version, skillWeights: weights,
            storeProductID: document.storeProductID,
            audience: document.audience, summary: document.summary
        )
        package.nameEN = document.nameLocalized?.en
        package.nameTR = document.nameLocalized?.tr
        package.summaryEN = document.summaryLocalized?.en
        package.summaryTR = document.summaryLocalized?.tr
        package.introEN = document.introLocalized?.en
        package.introTR = document.introLocalized?.tr

        var seenQuestionIDs = Set<String>()
        var units: [Unit] = []
        for unitDoc in document.units {
            let unit = Unit(id: unitDoc.id, theme: unitDoc.theme, order: unitDoc.order)
            unit.themeEN = unitDoc.themeLocalized?.en
            unit.themeTR = unitDoc.themeLocalized?.tr
            var lessons: [Lesson] = []
            for lessonDoc in unitDoc.lessons {
                let lesson = Lesson(
                    id: lessonDoc.id, order: lessonDoc.order,
                    estimatedDurationMinutes: lessonDoc.estimatedDurationMinutes,
                    title: lessonDoc.title, skill: Skill(rawValue: lessonDoc.skill)!
                )
                lesson.titleEN = lessonDoc.titleLocalized?.en
                lesson.titleTR = lessonDoc.titleLocalized?.tr
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
                        collocations: itemDoc.collocations,
                        explanationTR: itemDoc.explanationTR
                    )
                    if let cards = itemDoc.lessonCards,
                       let encoded = try? JSONEncoder().encode(cards) {
                        content.lessonCardsJSON = String(data: encoded, encoding: .utf8)
                    }
                    item.content = content
                    content.item = item
                    item.lesson = lesson
                    items.append(item)
                }
                lesson.items = items

                let lessonSkill = Skill(rawValue: lessonDoc.skill)!
                let questionDocs = lessonDoc.questions ?? []

                if lessonSkill != .vocabulary {
                    guard !questionDocs.isEmpty else {
                        throw ContentImportError.missingQuestions(lessonDoc.id)
                    }
                    let cards = items.filter { $0.type == .grammarPoint || $0.type == .practiceSet }
                    guard cards.count == 1 else {
                        throw ContentImportError.missingPracticeCard(lessonDoc.id)
                    }
                    if cards[0].type == .grammarPoint,
                       (cards[0].content?.explanationTR ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw ContentImportError.emptyExplanation(lessonDoc.id)
                    }
                }

                var passage: Passage?
                if let passageDoc = lessonDoc.passage {
                    let built = Passage(id: passageDoc.id, title: passageDoc.title, body: passageDoc.body)
                    built.bodyTR = passageDoc.bodyTR
                    built.lesson = lesson
                    lesson.passage = built
                    passage = built
                }

                var questions: [Question] = []
                for questionDoc in questionDocs {
                    guard let kind = QuestionKind(rawValue: questionDoc.kind) else {
                        throw ContentImportError.invalidQuestionKind(questionDoc.kind)
                    }
                    guard questionDoc.options.count == 5 else {
                        throw ContentImportError.invalidOptionCount(questionDoc.id, questionDoc.options.count)
                    }
                    guard (0...4).contains(questionDoc.correctIndex) else {
                        throw ContentImportError.correctIndexOutOfRange(questionDoc.id, questionDoc.correctIndex)
                    }
                    guard !questionDoc.explanationTR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw ContentImportError.emptyExplanation(questionDoc.id)
                    }
                    guard seenQuestionIDs.insert(questionDoc.id).inserted else {
                        throw ContentImportError.duplicateQuestionID(questionDoc.id)
                    }
                    let question = Question(
                        id: questionDoc.id, prompt: questionDoc.prompt, options: questionDoc.options,
                        correctIndex: questionDoc.correctIndex, explanationTR: questionDoc.explanationTR,
                        kind: kind, order: questionDoc.order
                    )
                    question.explanationEN = questionDoc.explanationLocalized?.en
                    question.explanationTRText = questionDoc.explanationLocalized?.tr
                    if let passageID = questionDoc.passageID {
                        guard let passage, passage.id == passageID else {
                            throw ContentImportError.missingPassage(questionDoc.id, passageID)
                        }
                        question.passage = passage
                    }
                    question.lesson = lesson
                    questions.append(question)
                }
                lesson.questions = questions
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
