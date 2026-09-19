# Practice Lessons Infrastructure (Slice 7a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every non-vocabulary lesson type a real lesson screen driven by a shared question model, and ship ~63 real YDS-quality questions so slices 7b-7d become content-only work.

**Architecture:** One `Question`/`Passage`/`QuestionAttempt` SwiftData model set in LearningEngine, fed by content JSON v4 through an extended `ContentImporter` with per-rule validation. Spaced repetition stays topic-level: a grammar topic is a `LearningItem(.grammarPoint)` and every other practice lesson owns exactly one `LearningItem(.practiceSet)`, so the existing `UserItemState`/`FSRSStateStore` machinery is reused unchanged — only the *rating* is new (session score → `FSRSRating`). One `PracticeSessionViewModel` + one `PracticeSessionView` serve all five question kinds; `DailyPlanBuilder` gains a `practiceReview` task and `PlanTaskAction` routes to the new screen.

**Tech Stack:** Swift 5.10 / SwiftUI, iOS 17.0 deployment target, SwiftData, XcodeGen-generated project (`App/project.yml`), two local Swift packages (`LearningEngine`, `TutorEngine`), Python 3 content assembly (`scripts/assemble-content.py`), GitHub Actions macOS runners for all verification.

**Spec:** `docs/superpowers/specs/2026-09-19-practice-lessons-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification step is: commit, then **push and confirm both CI workflows green** — `Swift Tests` (`.github/workflows/swift-tests.yml`, via `scripts/ci-test.sh`) and `App Build` (`.github/workflows/app-build.yml`, via `scripts/ci-app-build.sh`). A task touching only `LearningEngine`/`TutorEngine` still runs both, because `App Build` compiles the App target against those packages.
- **Pushed commits are never amended.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` (blank line before it).
- **SwiftData lightweight migration:** every new stored property on an *existing* `@Model` must be optional **or** carry an **inline property default** (e.g. `public var order: Int = 0`), not just an `init` default. An earlier review caught exactly this omission. New `@Model` types are new entities, but give their non-optional stored properties inline defaults too, matching `ContentPackage`/`Lesson`.
- **All user-facing copy is Turkish, informal ("sen"), written as inline Swift string literals.** `App/Sources/EnglishApp/Resources/Localizable.xcstrings` is an *empty* catalog (`sourceLanguage: "tr"`, `"strings": {}`) — Turkish is the development language and Xcode extracts literals into it at build time. **Do not hand-write entries into the catalog**; adding them by hand would diverge from every existing screen and from the compiler-extracted set. New Turkish copy goes in as literals exactly like `TodayPlanView.swift` / `StudySummaryView.swift` do.
- **Turkish locale casing:** uppercasing uses `.uppercased(with: Locale(identifier: "tr_TR"))` (the pattern in `StudySessionViewModel.contextLine` and `TodayPlanView`). In `tr_TR`, `i` uppercases to **`İ`** (dotted), not `I`. Any test asserting uppercased Turkish must write the dotted form literally — never assume ASCII uppercasing.
- **Reuse the design system.** `Theme`, `PaperCard`, `PrimaryButtonStyle`, `ProgressBar`, `SkillBadge`, `StatTile`, `PlanTaskRow`, `Font.serifTitle(_:)`. Never signal correctness by color alone — always pair with an SF Symbol and text (spec "Screens and flow", rule 4). Support Dynamic Type, dark mode, Reduce Motion, and give options VoiceOver labels of the form `"A şıkkı: …"`.
- **Simulator cannot run MLX.** `AppState.isTutorAvailable` returns `false` under `targetEnvironment(simulator)`, so App-target CI never exercises `MLXTutorEngine`. Tutor behaviour is tested through the pure `QuestionPromptBuilder` (TutorEngine package) and fake engines; the on-device path is verified at TestFlight.
- **`userID` is always `UserIdentity.current`.** SwiftData `#Predicate` cannot close over `self.userID`, so use the established `let userIDValue = userID` local-copy pattern from `TodayPlanCoordinator.swift`.
- **Tests must assert behaviour**, not just that a call did not throw. Every new test names a concrete expected value.

---

## File Structure

**LearningEngine — new files**

| File | Responsibility |
|---|---|
| `Sources/LearningEngine/Models/Question.swift` | `QuestionKind` enum + `Question` `@Model` |
| `Sources/LearningEngine/Models/Passage.swift` | `Passage` `@Model` |
| `Sources/LearningEngine/Models/QuestionAttempt.swift` | `QuestionAttempt` `@Model` |
| `Sources/LearningEngine/Practice/PracticeScoring.swift` | score → `FSRSRating` |
| `Sources/LearningEngine/Practice/PracticeQuestionSelector.swift` | pure question selection + `SeededGenerator` |

**LearningEngine — modified**

`Models/LearningItem.swift` (`practiceSet` case, `isVocabularyCard`), `Models/ItemContent.swift` (`explanationTR`), `Models/Lesson.swift` (`questions`, `passage`), `Models/Skill.swift` (`forItem(type:lessonSkill:)`), `Import/ContentDocuments.swift`, `Import/ContentImporter.swift`, `Planning/PlanTypes.swift` (`DuePracticeCard`, `PlanTask.practiceReview`), `Planning/DailyPlanBuilder.swift`.

**TutorEngine — modified**

`Sources/TutorEngine/TutorRequest.swift` (`QuestionTutorRequest`, protocol method), new `Sources/TutorEngine/QuestionPromptBuilder.swift`.

**App — new files**

`Sources/EnglishApp/Practice/PracticeSessionViewModel.swift`, `Practice/PracticeSessionView.swift`, `Practice/PracticeExplanationView.swift`, `Practice/PracticeQuestionView.swift`, `Practice/PracticeSummaryView.swift`.

**App — modified**

`AppModelContainer.swift`, `ContentSeeder.swift`, `Profile/ProfileView.swift` (`resetAllData` only), `Today/PlanTaskAction.swift`, `Today/TodayPlanCoordinator.swift`, `Today/TodaySessionCoordinator.swift`, `Today/TodayPlanView.swift`, `CoursePath/CoursePathView.swift`, `DesignSystem/PlanTaskRow.swift`, `Study/StudySessionViewModel.swift`, `Tutor/TutorViewModel.swift`.

**Content**

New `content/yds-academic-vocab-1/practice/*.json` (7 lesson files); modified `scripts/assemble-content.py`; regenerated `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`.

---

## Task ordering note (spec "Task order")

The spec's order is preserved. Two deviations, both deliberate:

- **Task 1 and Task 2 must reach CI in that order.** Task 2's regenerated JSON contains `"type": "practiceSet"`, `questions`, `passage` and item-level `explanationTR`. Pushed *without* Task 1's importer, `ContentImporter` throws `invalidItemType("practiceSet")` and **both** workflows go red (`ContentImporterTests` and `RealContentSeedingTests` both import the shipped document). Task 1 alone is green — the new validation rules only fire on lessons whose `skill != vocabulary`, and today there are none. So: land Task 1 first, or push Tasks 1 and 2 as two commits in a **single push** so one CI run covers both. Never push Task 2 first.
- **The spec's task 2 is split into Task 2 (authoring) and Task 3 (independent review)**, because the review must be a genuinely separate gate performed by someone who did not write the questions.

---

## Task 1: Models, `practiceSet` item type, JSON v4 schema, importer validation

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Models/Question.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/Passage.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/QuestionAttempt.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/LearningItem.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/ItemContent.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/Lesson.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/Skill.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentImporter.swift`
- Modify: `App/Sources/EnglishApp/AppModelContainer.swift`
- Modify: `App/Sources/EnglishApp/ContentSeeder.swift`
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift` (only `resetAllData()`)
- Test: `LearningEngine/Tests/LearningEngineTests/QuestionModelTests.swift` (new)
- Test: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift` (extend; also update its `makeInMemoryContext()` schema)

**Interfaces:**
- Produces: `QuestionKind` (`.grammar`, `.reading`, `.cloze`, `.sentenceCompletion`, `.translation`; raw values identical to the case names); `Question` (`id`, `prompt`, `options: [String]`, `correctIndex: Int`, `explanationTR: String`, `kind: QuestionKind`, `order: Int`, `lesson: Lesson?`, `passage: Passage?`); `Passage` (`id`, `title`, `body`, `lesson: Lesson?`, `questions: [Question]`); `QuestionAttempt` (`userID`, `questionID`, `wasCorrect`, `answeredAt`, `selectedIndex`); `Lesson.questions: [Question]`, `Lesson.passage: Passage?`; `ItemContent.explanationTR: String?`; `LearningItemType.practiceSet`; `LearningItemType.isVocabularyCard: Bool`; `Skill.forItem(type:lessonSkill:) -> Skill`; `ContentImportError` cases `.invalidQuestionKind(String)`, `.invalidOptionCount(String, Int)`, `.correctIndexOutOfRange(String, Int)`, `.emptyExplanation(String)`, `.duplicateQuestionID(String)`, `.missingQuestions(String)`, `.missingPassage(String, String)`, `.missingPracticeCard(String)`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing model test**

```swift
// LearningEngine/Tests/LearningEngineTests/QuestionModelTests.swift
import XCTest
import SwiftData
@testable import LearningEngine

final class QuestionModelTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([
            ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
            Question.self, Passage.self, QuestionAttempt.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_lessonOwnsQuestionsAndPassage_withWiredInverses() throws {
        let context = try makeContext()
        let lesson = Lesson(id: "l1", order: 0, estimatedDurationMinutes: 8, title: "Okuma", skill: .reading)
        let passage = Passage(id: "p1", title: "Carbon Pricing", body: "Body text.")
        let question = Question(
            id: "q1", prompt: "According to the passage, ----.",
            options: ["a", "b", "c", "d", "e"], correctIndex: 1,
            explanationTR: "Metinde ikinci seçenek açıkça belirtiliyor.", kind: .reading, order: 0
        )
        question.lesson = lesson
        question.passage = passage
        passage.lesson = lesson
        context.insert(lesson)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Lesson>()).first)
        XCTAssertEqual(fetched.questions.map(\.id), ["q1"])
        XCTAssertEqual(fetched.passage?.id, "p1")
        XCTAssertEqual(fetched.questions.first?.passage?.title, "Carbon Pricing")
        XCTAssertEqual(fetched.questions.first?.options.count, 5)
        XCTAssertEqual(fetched.questions.first?.kind, .reading)
    }

    func test_deletingLesson_cascadesToQuestionsAndPassage() throws {
        let context = try makeContext()
        let lesson = Lesson(id: "l1", order: 0, estimatedDurationMinutes: 8, title: "Okuma", skill: .reading)
        let passage = Passage(id: "p1", title: "T", body: "B")
        let question = Question(id: "q1", prompt: "p", options: ["a", "b", "c", "d", "e"], correctIndex: 0, explanationTR: "x", kind: .reading, order: 0)
        question.lesson = lesson
        question.passage = passage
        passage.lesson = lesson
        context.insert(lesson)
        try context.save()

        context.delete(lesson)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Question>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Passage>()), 0)
    }

    func test_questionAttempt_roundTripsEveryField() throws {
        let context = try makeContext()
        let answeredAt = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(QuestionAttempt(userID: "u1", questionID: "q1", wasCorrect: false, answeredAt: answeredAt, selectedIndex: 3))
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<QuestionAttempt>()).first)
        XCTAssertEqual(fetched.userID, "u1")
        XCTAssertEqual(fetched.questionID, "q1")
        XCTAssertFalse(fetched.wasCorrect)
        XCTAssertEqual(fetched.answeredAt, answeredAt)
        XCTAssertEqual(fetched.selectedIndex, 3)
    }

    func test_skillForItem_prefersTheOwningLessonsSkill_andFallsBackToTheItemType() {
        XCTAssertEqual(Skill.forItem(type: .practiceSet, lessonSkill: .reading), .reading)
        XCTAssertEqual(Skill.forItem(type: .grammarPoint, lessonSkill: .reading), .reading)
        XCTAssertEqual(Skill.forItem(type: .vocabulary, lessonSkill: nil), .vocabulary)
        XCTAssertEqual(Skill.forItem(type: .grammarPoint, lessonSkill: nil), .grammar)
    }

    func test_isVocabularyCard_isFalseForTopicAndPracticeCards() {
        XCTAssertTrue(LearningItemType.vocabulary.isVocabularyCard)
        XCTAssertTrue(LearningItemType.phrase.isVocabularyCard)
        XCTAssertTrue(LearningItemType.collocation.isVocabularyCard)
        XCTAssertFalse(LearningItemType.grammarPoint.isVocabularyCard)
        XCTAssertFalse(LearningItemType.practiceSet.isVocabularyCard)
    }
}
```

- [ ] **Step 2: Confirm it cannot compile yet**

`Question`, `Passage`, `QuestionAttempt`, `Skill.forItem` and `LearningItemType.practiceSet` do not exist, so this is a compile failure, not a test failure. That is the expected "red" for new types — do not push a knowingly non-compiling tree to CI; go straight to Step 3.

- [ ] **Step 3: Add the three new models**

```swift
// LearningEngine/Sources/LearningEngine/Models/Question.swift
import Foundation
import SwiftData

public enum QuestionKind: String, Codable, CaseIterable, Sendable {
    case grammar, reading, cloze, sentenceCompletion, translation
}

/// One multiple-choice question. Always exactly five options (YDS format,
/// shown as A-E); `correctIndex` is 0-4. Options keep their authored order —
/// 7a deliberately does not shuffle them.
@Model
public final class Question {
    @Attribute(.unique) public var id: String
    public var prompt: String = ""
    public var options: [String] = []
    public var correctIndex: Int = 0
    public var explanationTR: String = ""
    public var kind: QuestionKind = QuestionKind.grammar
    public var order: Int = 0
    public var lesson: Lesson?
    public var passage: Passage?

    public init(
        id: String, prompt: String, options: [String], correctIndex: Int,
        explanationTR: String, kind: QuestionKind, order: Int
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.explanationTR = explanationTR
        self.kind = kind
        self.order = order
    }
}
```

```swift
// LearningEngine/Sources/LearningEngine/Models/Passage.swift
import Foundation
import SwiftData

/// A reading or cloze text. Owned by exactly one lesson; its questions point
/// back at it so the screen can keep the text pinned above the question.
@Model
public final class Passage {
    @Attribute(.unique) public var id: String
    public var title: String = ""
    public var body: String = ""
    public var lesson: Lesson?
    @Relationship(deleteRule: .nullify, inverse: \Question.passage)
    public var questions: [Question] = []

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}
```

```swift
// LearningEngine/Sources/LearningEngine/Models/QuestionAttempt.swift
import Foundation
import SwiftData

/// One answered question. Written immediately on every answer (not only on
/// session completion), so a quit-midway session still informs later
/// question selection. Deliberately has no unique id: a learner answers the
/// same question many times across reviews.
@Model
public final class QuestionAttempt {
    public var userID: String = ""
    public var questionID: String = ""
    public var wasCorrect: Bool = false
    public var answeredAt: Date = Date(timeIntervalSince1970: 0)
    public var selectedIndex: Int = 0

    public init(userID: String, questionID: String, wasCorrect: Bool, answeredAt: Date, selectedIndex: Int) {
        self.userID = userID
        self.questionID = questionID
        self.wasCorrect = wasCorrect
        self.answeredAt = answeredAt
        self.selectedIndex = selectedIndex
    }
}
```

- [ ] **Step 4: Extend the existing models**

In `Models/Lesson.swift`, add two relationships below `items`:

```swift
    @Relationship(deleteRule: .cascade, inverse: \Question.lesson)
    public var questions: [Question] = []
    @Relationship(deleteRule: .cascade, inverse: \Passage.lesson)
    public var passage: Passage?
```

In `Models/ItemContent.swift`, add the stored property (inline default — required for lightweight migration) directly after `imageURL`:

```swift
    /// Turkish topic explanation for a grammar topic card (rule, examples,
    /// common traps). Nil for vocabulary items.
    public var explanationTR: String? = nil
```

and add a defaulted parameter to `init`, after `imageURL: URL? = nil`:

```swift
        explanationTR: String? = nil
```

with `self.explanationTR = explanationTR` as the last assignment.

In `Models/LearningItem.swift`, replace the enum and add the helper:

```swift
public enum LearningItemType: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammarPoint, phrase, collocation, practiceSet

    /// Whether this item belongs in the vocabulary flashcard flow
    /// (`StudySessionViewModel` / `TodaySessionCoordinator`). Grammar topics
    /// and practice sets are FSRS cards too, but they are reviewed through
    /// the practice screen, never as flashcards.
    public var isVocabularyCard: Bool {
        switch self {
        case .vocabulary, .phrase, .collocation: return true
        case .grammarPoint, .practiceSet: return false
        }
    }
}
```

In `Models/Skill.swift`, keep `forItemType` exactly as it is apart from the new case, and add the lesson-aware accessor:

```swift
    /// Which skill a reviewed item counts toward.
    public static func forItemType(_ type: LearningItemType) -> Skill {
        switch type {
        case .vocabulary, .phrase, .collocation: return .vocabulary
        case .grammarPoint: return .grammar
        // A practice set has no intrinsic skill — the owning lesson decides.
        // This branch is only the last-resort fallback for an orphan item.
        case .practiceSet: return .reading
        }
    }

    /// Skill attribution for a reviewed item: the owning lesson's skill wins,
    /// so a reading practice set counts toward `reading` and a sentence-
    /// completion set toward `grammar`. `forItemType` remains the fallback
    /// for items with no lesson.
    public static func forItem(type: LearningItemType, lessonSkill: Skill?) -> Skill {
        lessonSkill ?? forItemType(type)
    }
```

- [ ] **Step 5: Extend the content documents (JSON v4 schema)**

```swift
// LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift
import Foundation

public struct LearningItemDocument: Decodable {
    public let id: String
    public let type: String
    public let headword: String
    public let frequencyRank: Int
    public let baseDifficulty: Double
    public let definition: String
    public let exampleSentences: [String]
    public let translationTR: String
    public let collocations: [String]
    /// Grammar topic explanation (Turkish). Absent for vocabulary items.
    public let explanationTR: String?
}

public struct PassageDocument: Decodable {
    public let id: String
    public let title: String
    public let body: String
}

public struct QuestionDocument: Decodable {
    public let id: String
    public let kind: String
    public let order: Int
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    public let explanationTR: String
    /// Set on reading and cloze questions; must match the owning lesson's
    /// passage id.
    public let passageID: String?
}

public struct LessonDocument: Decodable {
    public let id: String
    public let order: Int
    public let estimatedDurationMinutes: Int
    public let title: String
    public let skill: String
    public let items: [LearningItemDocument]
    public let passage: PassageDocument?
    public let questions: [QuestionDocument]?
}

public struct UnitDocument: Decodable {
    public let id: String
    public let theme: String
    public let order: Int
    public let lessons: [LessonDocument]
}

public struct ContentPackageDocument: Decodable {
    public let id: String
    public let name: String
    public let goal: String
    public let levelLower: String
    public let levelUpper: String
    public let version: Int
    /// Keyed by `Skill` raw value; validated and converted by `ContentImporter`.
    public let skillWeights: [String: Double]
    public let units: [UnitDocument]
}
```

`explanationTR`, `passage` and `questions` are all optional, so the 12 existing vocabulary lessons and their 120 items decode unchanged.

- [ ] **Step 6: Add the importer validation rules**

In `Import/ContentImporter.swift`, extend the error enum:

```swift
public enum ContentImportError: Error, Equatable {
    case invalidGoal(String)
    case invalidItemType(String)
    case decodingFailed(String)
    case invalidSkillWeights(String)
    case invalidSkill(String)
    case invalidVersion(Int)
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
```

Inside `importPackage`, keep everything up to and including the existing lesson-skill loop, then declare a package-wide id set before the unit loop:

```swift
        var seenQuestionIDs = Set<String>()
```

and replace the body of the `for lessonDoc in unitDoc.lessons` loop's tail (everything after `lesson.items = items`) with:

```swift
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
```

and pass the new item field through where `ItemContent` is constructed, by adding one argument after `collocations: itemDoc.collocations`:

```swift
                        explanationTR: itemDoc.explanationTR
```

- [ ] **Step 7: Register the new entities in the two schemas and the reset path**

`App/Sources/EnglishApp/AppModelContainer.swift`:

```swift
    static let schema = Schema([
        ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
        Question.self, Passage.self, QuestionAttempt.self,
        ReviewLog.self, UserItemState.self, LearnerProfile.self, LessonProgress.self, LevelTestResult.self
    ])
```

`App/Sources/EnglishApp/ContentSeeder.swift` — the throwaway validation store must know the new entities or validation-before-replace silently stops covering them:

```swift
        let scratchSchema = Schema([
            ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
            Question.self, Passage.self
        ])
```

`App/Sources/EnglishApp/Profile/ProfileView.swift`, inside `resetAllData()`, add one line after the `LessonProgress` delete (`Question`/`Passage` are cascade-deleted with `ContentPackage`, but `QuestionAttempt` is standalone user data):

```swift
            try context.delete(model: QuestionAttempt.self)
```

- [ ] **Step 8: Extend `ContentImporterTests` — schema and one test per rejection rule**

Update its `makeInMemoryContext()` schema to `Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self, Question.self, Passage.self])`, then add this helper and these tests to the existing class:

```swift
    /// A one-lesson package with a practice lesson. Every parameter exists so
    /// a single test can break exactly one rule.
    func practiceJSON(
        lessonSkill: String = "grammar",
        itemType: String = "grammarPoint",
        itemExplanation: String = #""explanationTR": "Past perfect, daha önce biten eylemi anlatır.","#,
        questionKind: String = "grammar",
        options: String = #"["a", "b", "c", "d", "e"]"#,
        correctIndex: String = "1",
        questionExplanation: String = "Doğru yanıt ikinci seçenektir.",
        secondQuestionID: String = "test-question-2",
        passage: String = "",
        passageID: String = "null"
    ) -> Data {
        """
        {
          "id": "test-package", "name": "Test Package", "goal": "yds",
          "levelLower": "B2", "levelUpper": "C1", "version": 4,
          "skillWeights": {"vocabulary": 1, "grammar": 1, "reading": 1, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [
            { "id": "test-unit-1", "theme": "Test Theme", "order": 0,
              "lessons": [
                { "id": "test-lesson-1", "order": 0, "estimatedDurationMinutes": 8,
                  "title": "Test Topic", "skill": "\(lessonSkill)",
                  \(passage)
                  "items": [
                    { "id": "test-card-1", "type": "\(itemType)", "headword": "Tenses",
                      "frequencyRank": 1000, "baseDifficulty": 0.5,
                      "definition": "d", "exampleSentences": [], "translationTR": "Zamanlar",
                      "collocations": [], \(itemExplanation) "unused": 0 }
                  ],
                  "questions": [
                    { "id": "test-question-1", "kind": "\(questionKind)", "order": 0,
                      "prompt": "Q1 ----.", "options": \(options), "correctIndex": \(correctIndex),
                      "explanationTR": "\(questionExplanation)", "passageID": \(passageID) },
                    { "id": "\(secondQuestionID)", "kind": "\(questionKind)", "order": 1,
                      "prompt": "Q2 ----.", "options": ["a", "b", "c", "d", "e"], "correctIndex": 0,
                      "explanationTR": "Doğru yanıt birinci seçenektir.", "passageID": null }
                  ] }
              ] }
          ]
        }
        """.data(using: .utf8)!
    }

    func test_importPackage_practiceLesson_buildsQuestionsPassageAndTopicExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: practiceJSON(
                lessonSkill: "reading", itemType: "practiceSet", itemExplanation: "",
                questionKind: "reading",
                passage: #""passage": { "id": "test-passage-1", "title": "Carbon Pricing", "body": "Body." },"#,
                passageID: #""test-passage-1""#
            ),
            into: context)
        try context.save()

        let lesson = package.units[0].lessons[0]
        XCTAssertEqual(lesson.questions.sorted { $0.order < $1.order }.map(\.id), ["test-question-1", "test-question-2"])
        XCTAssertEqual(lesson.passage?.title, "Carbon Pricing")
        let first = try XCTUnwrap(lesson.questions.first { $0.id == "test-question-1" })
        XCTAssertEqual(first.kind, .reading)
        XCTAssertEqual(first.correctIndex, 1)
        XCTAssertEqual(first.options.count, 5)
        XCTAssertEqual(first.passage?.id, "test-passage-1")
        XCTAssertEqual(lesson.items.first?.type, .practiceSet)
    }

    func test_importPackage_grammarLesson_storesTheTurkishTopicExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: practiceJSON(), into: context)
        try context.save()
        XCTAssertEqual(
            package.units[0].lessons[0].items.first?.content?.explanationTR,
            "Past perfect, daha önce biten eylemi anlatır."
        )
    }

    func test_importPackage_vocabularyItem_hasNilExplanation() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: packageJSON(), into: context)
        try context.save()
        XCTAssertNil(package.units[0].lessons[0].items.first?.content?.explanationTR)
    }

    func test_importPackage_wrongOptionCount_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(options: #"["a", "b", "c", "d"]"#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidOptionCount("test-question-1", 4))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_correctIndexOutOfRange_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(correctIndex: "5"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .correctIndexOutOfRange("test-question-1", 5))
        }
    }

    func test_importPackage_emptyQuestionExplanation_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(questionExplanation: "   "), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .emptyExplanation("test-question-1"))
        }
    }

    func test_importPackage_emptyGrammarTopicExplanation_throwsForTheLesson() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(itemExplanation: #""explanationTR": "","#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .emptyExplanation("test-lesson-1"))
        }
    }

    func test_importPackage_duplicateQuestionID_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(secondQuestionID: "test-question-1"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .duplicateQuestionID("test-question-1"))
        }
    }

    func test_importPackage_practiceLessonWithoutQuestions_throws() throws {
        let json = """
        {
          "id": "p", "name": "P", "goal": "yds", "levelLower": "B2", "levelUpper": "C1", "version": 4,
          "skillWeights": {"vocabulary": 1, "grammar": 1, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0},
          "units": [{ "id": "u", "theme": "T", "order": 0, "lessons": [
            { "id": "grammar-lesson", "order": 0, "estimatedDurationMinutes": 8, "title": "T", "skill": "grammar",
              "items": [{ "id": "c", "type": "grammarPoint", "headword": "h", "frequencyRank": 1,
                          "baseDifficulty": 0.5, "definition": "d", "exampleSentences": [],
                          "translationTR": "t", "collocations": [], "explanationTR": "Açıklama." }] }
          ]}]
        }
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingQuestions("grammar-lesson"))
        }
    }

    func test_importPackage_practiceLessonWithoutACard_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(itemType: "vocabulary", itemExplanation: ""), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingPracticeCard("test-lesson-1"))
        }
    }

    func test_importPackage_questionReferencingAMissingPassage_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(passageID: #""no-such-passage""#), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .missingPassage("test-question-1", "no-such-passage"))
        }
    }

    func test_importPackage_unknownQuestionKind_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: practiceJSON(questionKind: "essay"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidQuestionKind("essay"))
        }
    }
```

Note the `"unused": 0` filler in `practiceJSON`: it keeps the JSON valid when `itemExplanation` is the empty string (no trailing comma problem).

- [ ] **Step 9: Commit**

```bash
git add LearningEngine/Sources LearningEngine/Tests App/Sources
git commit -m "$(cat <<'EOF'
Add Question/Passage/QuestionAttempt models and content JSON v4 validation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Push and confirm both CI workflows green**

Run `scripts/ci-test.sh`, then `scripts/ci-app-build.sh`. Both must end green. Expected: all existing `ContentImporterTests`, `RealContentSeedingTests` and `ContentSeederTests` still pass unchanged — the shipped v3 JSON has no practice lessons, so none of the new rules fire.

---

## Task 2: Sample content — 7 practice lessons, ~63 questions, package version 4

**Files:**
- Create: `content/yds-academic-vocab-1/practice/grammar-tenses.json`
- Create: `content/yds-academic-vocab-1/practice/grammar-conditionals.json`
- Create: `content/yds-academic-vocab-1/practice/reading-climate-policy.json`
- Create: `content/yds-academic-vocab-1/practice/reading-digital-economy.json`
- Create: `content/yds-academic-vocab-1/practice/cloze-urbanisation.json`
- Create: `content/yds-academic-vocab-1/practice/sentence-completion-1.json`
- Create: `content/yds-academic-vocab-1/practice/translation-1.json`
- Modify: `scripts/assemble-content.py`
- Regenerate (never hand-edit): `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`, `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift` (the real-batch test)
- Modify: `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`

**Interfaces:**
- Consumes: Task 1's `QuestionDocument`/`PassageDocument` schema and all eight validation rules.
- Produces: package `version` **4**; unit `yds-vocab1-unit-business-economics` gains lessons at `order` 3-9; total `LearningItem` count **127** (120 vocabulary + 7 practice cards); total `Question` count **63**; a Python content lint invoked by `assemble()` so the existing CI drift-check step fails on bad content before the Swift tests even start.

### Where the content lives, and why

`LessonAccessPolicy` gives a preview user **only the unit with the lowest `order`** — today `yds-vocab1-unit-business-economics` (order 0). `DevelopmentPackageAccessProvider` returns `.preview` unless the Profil developer toggle is on, so that is what CI and everyday testing see.

- Putting the practice lessons in a *new* unit at order 4 would leave them permanently locked ("Paketi aç") — the whole slice would be unreachable.
- Putting them in a *new* unit at order 0 would push all four vocabulary units out of the preview, so a preview user could never introduce a vocabulary item and the review loop would go dead — a real regression.

So the seven practice lessons are **appended to the existing first unit** as lessons 3-9, with their own explicit Turkish titles. The unit theme ("Business & Economics") is only a section header in Ders Yolu; 7b can regroup them when the real curriculum lands.

### Lesson inventory (fixed — ids and counts are contractual)

| order | file | lesson id | skill | title | card item id / type | questions |
|---|---|---|---|---|---|---|
| 3 | `grammar-tenses.json` | `yds-practice-lesson-tenses` | `grammar` | `Zamanlar (Tenses)` | `yds-practice-card-tenses` / `grammarPoint` | 8 `grammar` |
| 4 | `grammar-conditionals.json` | `yds-practice-lesson-conditionals` | `grammar` | `Koşul Cümleleri (Conditionals)` | `yds-practice-card-conditionals` / `grammarPoint` | 8 `grammar` |
| 5 | `reading-climate-policy.json` | `yds-practice-lesson-reading-1` | `reading` | `Okuma: Karbon Fiyatlandırması` | `yds-practice-card-reading-1` / `practiceSet` | 5 `reading` |
| 6 | `reading-digital-economy.json` | `yds-practice-lesson-reading-2` | `reading` | `Okuma: Dijital Ekonomi` | `yds-practice-card-reading-2` / `practiceSet` | 5 `reading` |
| 7 | `cloze-urbanisation.json` | `yds-practice-lesson-cloze-1` | `reading` | `Cloze Test: Kentleşme` | `yds-practice-card-cloze-1` / `practiceSet` | 10 `cloze` |
| 8 | `sentence-completion-1.json` | `yds-practice-lesson-sentence-1` | `grammar` | `Cümle Tamamlama` | `yds-practice-card-sentence-1` / `practiceSet` | 15 `sentenceCompletion` |
| 9 | `translation-1.json` | `yds-practice-lesson-translation-1` | `reading` | `Çeviri: İngilizce-Türkçe` | `yds-practice-card-translation-1` / `practiceSet` | 10 `translation` |

Total **63** questions. Question ids are `<lesson id>-q<NN>` with `NN` zero-padded from `01`; `order` is 0-based and equals the id suffix minus one. `estimatedDurationMinutes`: 8 for the two grammar topics and sentence completion, 10 for the two reading lessons and cloze, 9 for translation.

**Skill assignment rationale** (a ruling the spec leaves open — there is no `examTechnique` skill): cloze and translation exercise reading comprehension, so they carry `reading`; sentence completion is structural, so it carries `grammar`. Every practice lesson therefore lands on a skill the YDS weights already fund (`grammar: 30`, `reading: 35`), which is what makes them schedulable by `DailyPlanBuilder` from day one.

**Card item fields:** `frequencyRank` = `1000 + order`, `baseDifficulty` = `0.5`, `definition` = a one-line Turkish description of the set, `exampleSentences` = `[]`, `collocations` = `[]`, `translationTR` = the Turkish title. `explanationTR` is set **only** on the two `grammarPoint` cards; `practiceSet` cards omit it.

### Content quality rules (binding on every authored question)

1. **Accuracy.** The keyed option is grammatically and factually correct under standard academic English. For a reading or cloze question the answer must be derivable from the passage text alone — no outside knowledge.
2. **Exactly one defensible option.** Every other option must be refutable in one sentence. If two options could both be argued, rewrite the stem or replace the option. This is the single most common failure mode; treat any "well, B is also sort of fine" as a defect.
3. **Plausible distractors.** Distractors are wrong for a *reason a learner would fall for* — a near-miss tense, an inverted cause/effect, a passage detail used as the wrong answer type. Never joke options, never obviously-wrong fillers, never options of wildly different length from the key.
4. **YDS register.** Academic, impersonal prose at B2-C1: economics, science, policy, technology, law. Use the YDS blank marker `----` in stems. Passages are 120-170 words.
5. **Turkish explanation explains WHY.** `explanationTR` states the rule or the textual evidence that makes the key correct, **and** says why at least two named distractors fail. 2-4 sentences, informal "sen" register where a second person is needed. Never "Doğru cevap B'dir." on its own.
6. **Options keep content order** — 7a does not shuffle. Spread `correctIndex` roughly evenly across 0-4 within each file; no three consecutive questions with the same key.
7. **Turkish typography.** Real Turkish characters (`ı İ ş ğ ü ö ç`), never ASCII substitutes. Files are UTF-8, LF, no BOM.

### Worked exemplars (ready-to-ship content, and the style bar for the rest)

These six are authored and verified. Author the remaining 57 to the same standard.

**Grammar / Tenses — `yds-practice-lesson-tenses-q01`**

```json
{
  "id": "yds-practice-lesson-tenses-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "By the time the central bank announced the new interest rate, most investors ---- their portfolios.",
  "options": [
    "have already restructured",
    "had already restructured",
    "already restructure",
    "are already restructuring",
    "will already restructure"
  ],
  "correctIndex": 1,
  "explanationTR": "«By the time» + geçmiş zaman kalıbı, ana cümledeki eylemin o andan DAHA ÖNCE bittiğini anlatır; bu yüzden past perfect gerekir: had already restructured. (A) present perfect, geçmişte belirli bir ana bağlanamaz. (C) ve (D) şimdiki zamanı, (E) ise geleceği anlatıyor; hiçbiri cümledeki geçmiş referansıyla uyuşmuyor.",
  "passageID": null
}
```

**Grammar / Conditionals — `yds-practice-lesson-conditionals-q01`**

```json
{
  "id": "yds-practice-lesson-conditionals-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "If the government ---- the subsidy last year, thousands of small firms would not have gone bankrupt.",
  "options": [
    "withdrew",
    "has not withdrawn",
    "had not withdrawn",
    "would not withdraw",
    "does not withdraw"
  ],
  "correctIndex": 2,
  "explanationTR": "Ana cümlede «would not have gone» var; bu, geçmişte gerçekleşmemiş bir durumu anlatan üçüncü tip koşul cümlesidir ve if kısmı past perfect olur: had not withdrawn. (A) ikinci tipin yapısı, (B) present perfect, (E) geniş zaman; üçü de «would have» ile eşleşmez. (D) ise if cümlesinde «would» kullanıyor, bu yapıda olmaz.",
  "passageID": null
}
```

**Reading — passage + `yds-practice-lesson-reading-1-q01`**

```json
{
  "passage": {
    "id": "yds-practice-passage-reading-1",
    "title": "Carbon Pricing in Practice",
    "body": "Carbon pricing has become the policy instrument of choice for governments that want to cut greenhouse gas emissions without dictating how firms should do it. The logic is straightforward: once emitting carbon carries a price, companies compare the cost of paying that price with the cost of cleaning up their production, and choose whichever is cheaper. In theory, emissions therefore fall wherever reduction is least expensive. In practice, the outcome depends almost entirely on the level at which the price is set. Where allowances have been distributed generously, as in the first phase of the European Union's trading scheme, prices collapsed and the incentive largely disappeared. Critics also point out that a uniform price weighs more heavily on low-income households, which spend a larger share of their income on energy. For that reason, several governments now return part of the revenue directly to citizens."
  },
  "question": {
    "id": "yds-practice-lesson-reading-1-q01",
    "kind": "reading",
    "order": 0,
    "prompt": "According to the passage, carbon pricing failed to change firms' behaviour in the first phase of the European scheme because ----.",
    "options": [
      "governments returned part of the revenue to citizens",
      "allowances were issued so freely that the price collapsed",
      "firms found cleaning up production cheaper than paying the price",
      "low-income households were exempted from the scheme",
      "the scheme covered too few industries to matter"
    ],
    "correctIndex": 1,
    "explanationTR": "Metin açıkça «izinler cömertçe dağıtıldığında fiyatlar çöktü ve teşvik büyük ölçüde ortadan kalktı» diyor; nedeni veren tek seçenek (B). (A) metinde geçiyor ama bu başarısızlığın nedeni değil, eleştirilere verilen bir yanıt. (C) metnin mantığının tam tersi. (D) ve (E) metinde hiç söylenmiyor.",
    "passageID": "yds-practice-passage-reading-1"
  }
}
```

**Cloze — passage opening + `yds-practice-lesson-cloze-1-q01`**

The cloze passage is a single text carrying numbered blanks `(1)----` … `(10)----`; each question's `prompt` is the blank number plus enough surrounding text to be readable on its own, and every cloze question sets `passageID` so the full text stays pinned above it.

```json
{
  "passage": {
    "id": "yds-practice-passage-cloze-1",
    "title": "Urbanisation in Developing Economies",
    "body": "Cities in the developing world are growing faster than at any point in recorded history. (1)---- this growth creates jobs and lifts millions of people out of poverty, it also puts enormous pressure on housing, transport and sanitation. Municipal budgets rarely expand as (2)---- as the populations they are meant to serve, ..."
  },
  "question": {
    "id": "yds-practice-lesson-cloze-1-q01",
    "kind": "cloze",
    "order": 0,
    "prompt": "(1) ---- this growth creates jobs and lifts millions of people out of poverty, it also puts enormous pressure on housing, transport and sanitation.",
    "options": ["Although", "Because", "Unless", "Therefore", "Moreover"],
    "correctIndex": 0,
    "explanationTR": "Cümlenin ilk yarısı olumlu (iş yaratıyor, yoksulluğu azaltıyor), ikinci yarısı olumsuz (konut, ulaşım ve altyapı üzerinde baskı); aradaki ilişki zıtlıktır ve iki yan cümleyi bağlayan bir bağlaç gerekir: «Although». (B) neden, (C) koşul bildirir. (D) sonuç bildirir, oysa burada zıtlık var. (E) ise bağlaç değil, cümle bağlayıcı bir zarftır; tek bir cümlede iki yan cümleyi birleştiremez.",
    "passageID": "yds-practice-passage-cloze-1"
  }
}
```

**Sentence completion — `yds-practice-lesson-sentence-1-q01`**

```json
{
  "id": "yds-practice-lesson-sentence-1-q01",
  "kind": "sentenceCompletion",
  "order": 0,
  "prompt": "Although the report was commissioned to settle the dispute, its conclusions were so ambiguous that ----.",
  "options": [
    "both sides claimed that it supported their own position",
    "the committee had refused to publish it in the first place",
    "it was written by an independent panel of economists",
    "the dispute would have been settled several years earlier",
    "the ministry commissions a similar report every year"
  ],
  "correctIndex": 0,
  "explanationTR": "«so ... that» kalıbı bir SONUÇ ister: sonuçlar o kadar belirsizdi ki ----. Belirsiz bir raporun doğal sonucu, iki tarafın da raporu kendi lehine yorumlamasıdır; bu yüzden (A). (B) zaman olarak tutarsız, raporun yazılmasından önceki bir olayı anlatıyor. (C) bir sonuç değil, ek bilgi. (D) üçüncü tip koşul yapısı gerektirir, burada koşul yok. (E) ise cümlenin konusuyla ilgisiz genel bir yargı.",
  "passageID": null
}
```

**Translation — `yds-practice-lesson-translation-1-q01`**

```json
{
  "id": "yds-practice-lesson-translation-1-q01",
  "kind": "translation",
  "order": 0,
  "prompt": "The committee argued that the new regulation would do little to curb inflation unless it was accompanied by tighter fiscal policy.",
  "options": [
    "Komisyon, yeni düzenlemenin daha sıkı bir maliye politikasıyla desteklenmedikçe enflasyonu dizginlemede pek işe yaramayacağını savundu.",
    "Komisyon, yeni düzenlemenin enflasyonu dizginlediğini ve daha sıkı bir maliye politikası gerektirdiğini savundu.",
    "Komisyon, daha sıkı bir maliye politikasının enflasyonu dizginleyeceğini, ancak yeni düzenlemenin gereksiz olduğunu savundu.",
    "Komisyona göre yeni düzenleme, daha sıkı bir maliye politikası uygulansa bile enflasyonu dizginleyemeyecekti.",
    "Komisyon, enflasyon dizginlenmedikçe yeni düzenlemenin daha sıkı bir maliye politikasına dönüşeceğini savundu."
  ],
  "correctIndex": 0,
  "explanationTR": "«unless it was accompanied by» = «...ile desteklenmedikçe», «would do little to curb» = «dizginlemede pek işe yaramayacak». Her iki öğeyi de doğru veren tek seçenek (A). (B) olumsuzluğu tümden atlıyor. (C) neden-sonucu ters çeviriyor ve metinde olmayan «gereksiz» yargısını ekliyor. (D) «unless» yerine «even if» anlamı veriyor. (E) ise cümlenin öğelerini birbirine karıştırıyor.",
  "passageID": null
}
```

### File shape

Each practice file is **one lesson document**, without `order` (the assemble script assigns it):

```json
{
  "id": "yds-practice-lesson-tenses",
  "estimatedDurationMinutes": 8,
  "title": "Zamanlar (Tenses)",
  "skill": "grammar",
  "items": [
    {
      "id": "yds-practice-card-tenses",
      "type": "grammarPoint",
      "headword": "Tenses",
      "frequencyRank": 1003,
      "baseDifficulty": 0.5,
      "definition": "İngilizcede zamanların YDS'de en sık sınanan kullanımları.",
      "exampleSentences": [],
      "translationTR": "Zamanlar",
      "collocations": [],
      "explanationTR": "YDS'de zaman soruları neredeyse her zaman cümledeki bir ZAMAN İŞARETİNE dayanır.\n\n• Present perfect (have/has + V3): «since», «for», «so far», «recently» ile; geçmişte başlayıp etkisi süren durumlar için.\n• Past simple: «in 2019», «last year», «... ago» gibi bitmiş bir zamanı gösteren ifadelerle; present perfect ile asla karışmaz.\n• Past perfect (had + V3): geçmişteki iki olaydan ÖNCE olanı için. «by the time», «before», «after», «no sooner ... than» kalıplarında beklenen zamandır.\n• Future perfect (will have + V3): «by 2030», «by the end of the year» gibi gelecekteki bir sınırdan önce bitecek eylemler için.\n\nEn sık düşülen tuzak: «by the time» görünce present perfect işaretlemek. Ana cümle geçmişteyse yan cümle past perfect olur.\n\nÖrnek: By the time the results were published, the team had already left the laboratory."
    }
  ],
  "questions": [ "... 8 questions, authored per the rules above ..." ]
}
```

Reading and cloze files add a `"passage": { "id": ..., "title": ..., "body": ... }` key between `skill` and `items`.

- [ ] **Step 1: Author the seven content files**

Write all seven files to the inventory above, applying every quality rule, starting from the six worked exemplars. Author the second grammar topic's `explanationTR` (Conditionals) to the same depth as the Tenses one: the three conditional types with their exact tense pairings, plus `unless`, `otherwise`, and the mixed conditional (`If + past perfect, would + V1`), and the most common YDS trap (a `would` inside the `if` clause). Practice-set cards (`type: "practiceSet"`) carry **no** `explanationTR`.

- [ ] **Step 2: Extend `scripts/assemble-content.py`**

Add, after `BATCH_FILES`:

```python
# The seven Slice 7a practice lessons. They are appended to the FIRST unit
# (order 0) on purpose: LessonAccessPolicy exposes only the lowest-ordered
# unit to a preview user, so a separate practice unit would be permanently
# locked, and making practice the first unit would push every vocabulary
# lesson out of the free preview and kill the review loop.
PRACTICE_UNIT_ID = "yds-vocab1-unit-business-economics"
PRACTICE_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "practice")
PRACTICE_FILES = [
    "grammar-tenses.json",
    "grammar-conditionals.json",
    "reading-climate-policy.json",
    "reading-digital-economy.json",
    "cloze-urbanisation.json",
    "sentence-completion-1.json",
    "translation-1.json",
]

QUESTION_KINDS = {"grammar", "reading", "cloze", "sentenceCompletion", "translation"}
PRACTICE_CARD_TYPES = {"grammarPoint", "practiceSet"}
```

Bump the version and update its comment:

```python
# 4: Slice 7a adds practice lessons (questions, passages, grammar topic
# explanations). Bumping this makes installed apps re-import the package.
PACKAGE_VERSION = 4
```

Replace `enrich_lessons` so it preserves the new keys (the old version rebuilt each lesson from a fixed key list and would silently drop `questions`/`passage`):

```python
def enrich_lessons(unit):
    """Adds a derived title and a default skill to every lesson, with a
    stable key order so the committed JSON diff stays readable. `passage`
    and `questions` are emitted only when present, so the twelve existing
    vocabulary lessons serialize byte-identically to before."""
    enriched = []
    for lesson in unit["lessons"]:
        skill = lesson.get("skill", "vocabulary")
        if skill not in SKILLS:
            raise ValueError(f"lesson {lesson['id']} has invalid skill {skill!r}")
        title = lesson.get("title", f"{unit['theme']} · {lesson['order'] + 1}")
        out = {
            "id": lesson["id"],
            "order": lesson["order"],
            "estimatedDurationMinutes": lesson["estimatedDurationMinutes"],
            "title": title,
            "skill": skill,
        }
        if "passage" in lesson:
            out["passage"] = lesson["passage"]
        out["items"] = lesson["items"]
        if lesson.get("questions"):
            out["questions"] = lesson["questions"]
        enriched.append(out)
    unit = dict(unit)
    unit["lessons"] = enriched
    return unit
```

Add the loader and the attach step:

```python
def load_practice_lessons():
    lessons = []
    for filename in PRACTICE_FILES:
        path = os.path.join(PRACTICE_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            lessons.append(json.load(f))
    return lessons


def attach_practice_lessons(units):
    """Appends the practice lessons to PRACTICE_UNIT_ID, numbering them
    straight after that unit's existing lessons."""
    target = next((u for u in units if u["id"] == PRACTICE_UNIT_ID), None)
    if target is None:
        raise ValueError(f"practice unit {PRACTICE_UNIT_ID} not found")
    next_order = max((l["order"] for l in target["lessons"]), default=-1) + 1
    for offset, lesson in enumerate(load_practice_lessons()):
        lesson = dict(lesson)
        lesson["order"] = next_order + offset
        target["lessons"].append(lesson)
    return units
```

Add the lint — this is what makes bad content fail fast on Windows and in CI, before any Swift runs. It mirrors the Swift importer's rules one for one:

```python
def validate_content(package):
    """Mirrors ContentImporter's validation so authors get the failure here,
    on Windows, seconds after saving -- not half an hour later in macOS CI.
    Also enforces two things the importer cannot: package-wide unique item
    ids and unique question `order` within a lesson."""
    question_ids = set()
    item_ids = set()
    for unit in package["units"]:
        for lesson in unit["lessons"]:
            lesson_id = lesson["id"]
            questions = lesson.get("questions", [])
            for item in lesson["items"]:
                if item["id"] in item_ids:
                    raise ValueError(f"duplicate item id {item['id']}")
                item_ids.add(item["id"])

            if lesson["skill"] != "vocabulary":
                if not questions:
                    raise ValueError(f"lesson {lesson_id} has a practice skill but no questions")
                cards = [i for i in lesson["items"] if i["type"] in PRACTICE_CARD_TYPES]
                if len(cards) != 1:
                    raise ValueError(
                        f"lesson {lesson_id} must own exactly one grammarPoint/practiceSet item, found {len(cards)}"
                    )
                if cards[0]["type"] == "grammarPoint" and not cards[0].get("explanationTR", "").strip():
                    raise ValueError(f"lesson {lesson_id} grammar card has an empty explanationTR")
                if cards[0]["type"] == "practiceSet" and "explanationTR" in cards[0]:
                    raise ValueError(f"lesson {lesson_id} practiceSet card must not carry explanationTR")
            elif questions:
                raise ValueError(f"vocabulary lesson {lesson_id} must not carry questions")

            passage_id = lesson.get("passage", {}).get("id")
            orders = set()
            for question in questions:
                qid = question["id"]
                if qid in question_ids:
                    raise ValueError(f"duplicate question id {qid}")
                question_ids.add(qid)
                if question["kind"] not in QUESTION_KINDS:
                    raise ValueError(f"question {qid} has unknown kind {question['kind']!r}")
                if len(question["options"]) != 5:
                    raise ValueError(f"question {qid} has {len(question['options'])} options, expected 5")
                if not 0 <= question["correctIndex"] <= 4:
                    raise ValueError(f"question {qid} correctIndex {question['correctIndex']} out of range")
                if not question["explanationTR"].strip():
                    raise ValueError(f"question {qid} has an empty explanationTR")
                if any(not option.strip() for option in question["options"]):
                    raise ValueError(f"question {qid} has an empty option")
                if question.get("passageID") is not None and question["passageID"] != passage_id:
                    raise ValueError(f"question {qid} references unknown passage {question['passageID']!r}")
                if question["order"] in orders:
                    raise ValueError(f"lesson {lesson_id} has two questions with order {question['order']}")
                orders.add(question["order"])
```

Finally wire both into `assemble`:

```python
def assemble():
    validate_weights(SKILL_WEIGHTS)
    units = attach_practice_lessons(load_units())
    package = {
        "id": "yds-academic-vocab-1",
        "name": "YDS: Academic Vocabulary I",
        "goal": "yds",
        "levelLower": "B2",
        "levelUpper": "C1",
        "version": PACKAGE_VERSION,
        "skillWeights": SKILL_WEIGHTS,
        "units": [enrich_lessons(u) for u in units],
    }
    validate_content(package)
    return package
```

**CI drift-check impact: no workflow edit is required.** The `Verify content assembly is up to date` step in `.github/workflows/swift-tests.yml` already runs `python3 scripts/assemble-content.py` and `git diff --exit-code` over both derived files. Because the practice files are now inputs to that script, editing a question without regenerating fails the diff, and a schema violation raises before the diff is reached.

- [ ] **Step 3: Regenerate and eyeball the diff**

```bash
python scripts/assemble-content.py
git diff --stat
```

Expected: exactly two files changed; inside the existing twelve vocabulary lessons, no change at all — only the version line going `3` → `4` and seven lesson objects appended to the first unit. If any existing vocabulary lesson's bytes moved, `enrich_lessons` was changed incorrectly; fix it before continuing.

- [ ] **Step 4: Update the two "real content" tests to assert the new totals**

In `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, replace `test_importPackage_realYDSVocabularyBatch_importsAll120ItemsAcrossFourUnits` with:

```swift
    func test_importPackage_realYDSPackage_imports127ItemsAnd63QuestionsAcrossFourUnits() throws {
        guard let url = Bundle.module.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("Fixture file not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.version, 4)
        XCTAssertEqual(package.units.count, 4)
        let allLessons = package.units.flatMap(\.lessons)
        let allItems = allLessons.flatMap(\.items)
        XCTAssertEqual(allItems.count, 127)
        XCTAssertEqual(Set(allItems.map(\.id)).count, 127, "duplicate item ids found")
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
        XCTAssertEqual(allItems.filter { $0.type == .vocabulary }.count, 120)
        XCTAssertEqual(allItems.filter { $0.type == .grammarPoint }.count, 2)
        XCTAssertEqual(allItems.filter { $0.type == .practiceSet }.count, 5)

        let allQuestions = allLessons.flatMap(\.questions)
        XCTAssertEqual(allQuestions.count, 63)
        XCTAssertEqual(Set(allQuestions.map(\.id)).count, 63, "duplicate question ids found")
        XCTAssertTrue(allQuestions.allSatisfy { $0.options.count == 5 })
        XCTAssertTrue(allQuestions.allSatisfy { (0...4).contains($0.correctIndex) })
        XCTAssertTrue(allQuestions.allSatisfy { !$0.explanationTR.isEmpty })

        // Every practice lesson sits in the free-preview unit, so a preview
        // user can actually reach this slice.
        let firstUnit = try XCTUnwrap(package.units.first { $0.order == 0 })
        XCTAssertEqual(firstUnit.lessons.count, 10)
        XCTAssertEqual(
            firstUnit.lessons.sorted { $0.order < $1.order }.map(\.skill),
            [.vocabulary, .vocabulary, .vocabulary, .grammar, .grammar, .reading, .reading, .reading, .grammar, .reading]
        )

        let tenses = try XCTUnwrap(allLessons.first { $0.id == "yds-practice-lesson-tenses" })
        XCTAssertEqual(tenses.questions.count, 8)
        XCTAssertEqual(tenses.items.first?.type, .grammarPoint)
        XCTAssertTrue((tenses.items.first?.content?.explanationTR ?? "").contains("Past perfect"))

        let reading1 = try XCTUnwrap(allLessons.first { $0.id == "yds-practice-lesson-reading-1" })
        XCTAssertEqual(reading1.passage?.id, "yds-practice-passage-reading-1")
        XCTAssertTrue(reading1.questions.allSatisfy { $0.passage?.id == "yds-practice-passage-reading-1" })
        XCTAssertTrue(reading1.questions.allSatisfy { $0.kind == .reading })

        // Regression guard for the mangled-Turkish-characters bug (UTF-8-as-Windows-1252
        // double-encoding, e.g. "ş" -> "ÅŸ") that a prior manual content-assembly step
        // introduced in 91/120 items. A bare `content != nil` check does not catch this,
        // since garbled-but-non-empty strings still pass it.
        let economyItem = allItems.first { $0.id == "yds-vocab1-item-economy" }
        XCTAssertEqual(economyItem?.content?.translationTR, "ekonomi")

        let mojibakeMarkers = ["Ã", "Å", "â€"]
        for item in allItems {
            guard let content = item.content else { continue }
            let fields = [content.translationTR, content.definition, content.explanationTR ?? ""]
                + content.exampleSentences + content.collocations
            for field in fields {
                for marker in mojibakeMarkers {
                    XCTAssertFalse(field.contains(marker), "possible mojibake ('\(marker)') in item \(item.id): \(field)")
                }
            }
        }
        for question in allQuestions {
            for field in [question.prompt, question.explanationTR] + question.options {
                for marker in mojibakeMarkers {
                    XCTAssertFalse(field.contains(marker), "possible mojibake ('\(marker)') in question \(question.id): \(field)")
                }
            }
        }
    }
```

In `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`: replace `XCTAssertEqual(allItems.count, 120)` with `XCTAssertEqual(allItems.count, 127)` in **both** tests, replace `XCTAssertEqual(package.version, 3)` with `XCTAssertEqual(package.version, 4)`, delete the now-false `XCTAssertTrue(package.units.flatMap(\.lessons).allSatisfy { $0.skill == .vocabulary })`, and add to the first test:

```swift
        XCTAssertEqual(package.units.flatMap(\.lessons).flatMap(\.questions).count, 63)
        XCTAssertEqual(package.units.flatMap(\.lessons).compactMap(\.passage).count, 3)
        XCTAssertEqual(Set(package.units.flatMap(\.lessons).map(\.skill)), [.vocabulary, .grammar, .reading])
```

(Three passages: the two reading lessons plus the cloze lesson.)

- [ ] **Step 5: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests LearningEngine/Sources App/Tests
git commit -m "$(cat <<'EOF'
Add seven YDS practice lessons with 63 questions, package version 4

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`. The Swift Tests run also re-executes `assemble-content.py` and diffs the derived files, so a green run proves the committed JSON is exactly what the script produces from the authored sources.

---

## Task 3: Independent content review

**Files:**
- Modify (only if defects are found): the seven files under `content/yds-academic-vocab-1/practice/`, then regenerate the two derived JSON documents.

**Interfaces:**
- Consumes: Task 2's 63 questions.
- Produces: no code surface. The deliverable is a corrected question bank plus a written verdict.

This task exists because a question bank reviewed by its own author is not reviewed. **Whoever performs this task must not have authored the content in Task 2** — under subagent-driven execution, dispatch a fresh subagent with no Task 2 context; under inline execution, this is the human's gate.

- [ ] **Step 1: Read the content cold**

Read the seven files under `content/yds-academic-vocab-1/practice/` and the spec's "Product decisions" item 4. Do **not** read Task 2's exemplars first — the point is to judge each question on its own.

- [ ] **Step 2: Score every question against the checklist**

For each of the 63 questions record `ok`, `fix` or `replace` on each point below, with a one-line reason for anything not `ok`:

1. **Key is correct.** Independently solve the question *before* looking at `correctIndex`. Disagreement is a `replace`.
2. **Exactly one defensible option.** Try to argue each distractor into correctness. If you succeed for any of them it is a `fix` (rewrite the distractor or tighten the stem).
3. **Distractors are plausible.** Any option obviously wrong at a glance, or of a different length/register from the others, is a `fix`.
4. **Reading/cloze answerability.** The key is supported by the passage text, not by world knowledge, and you can quote the supporting sentence. Otherwise `replace`.
5. **`explanationTR` explains why.** States the rule or the textual evidence, *and* refutes at least two named distractors. A bare restatement of the answer is a `fix`.
6. **Register and typography.** B2-C1 academic English, `----` blank marker, real Turkish characters, informal "sen" wherever a second person appears.
7. **Key distribution.** Per file: no key used for more than ~40% of that file's questions, and no three consecutive questions sharing a key.

Also check the two grammar-topic `explanationTR` cards: is the rule stated correctly, are the examples grammatical, and is the named "trap" one a real YDS candidate falls into?

- [ ] **Step 3: Apply fixes at the source, never in the derived JSON**

Edit only files under `content/yds-academic-vocab-1/practice/`, then regenerate:

```bash
python scripts/assemble-content.py
```

- [ ] **Step 4: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the YDS practice question bank

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Push, confirm both CI workflows green, and record the verdict**

Run `scripts/ci-test.sh` and `scripts/ci-app-build.sh`. Then report: questions reviewed, counts of `ok`/`fix`/`replace`, and every defect with its resolution. If more than five questions needed `replace`, stop and re-open Task 2 rather than patching — a bank failing at that rate has a systemic authoring problem.

---

## Task 4: Score-to-rating mapping and question selection (pure)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Practice/PracticeScoring.swift`
- Create: `LearningEngine/Sources/LearningEngine/Practice/PracticeQuestionSelector.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/PracticeScoringTests.swift` (new)
- Test: `LearningEngine/Tests/LearningEngineTests/PracticeQuestionSelectorTests.swift` (new)

**Interfaces:**
- Consumes: `FSRSRating`, `Skill` from Task 1's package.
- Produces:
  - `PracticeScoring.rating(correct: Int, total: Int) -> FSRSRating`
  - `PracticeScoring.selectionSize(poolCount: Int, skill: Skill) -> Int`
  - `QuestionCandidate(id: String, order: Int, lastAttemptedAt: Date?, lastWasCorrect: Bool?)`
  - `PracticeQuestionSelector.select(from:size:using:) -> [String]`
  - `SeededGenerator(seed: UInt64)` conforming to `RandomNumberGenerator`

Pure and SwiftData-free: no `ModelContext`, no clock reads, no `Date()`.

- [ ] **Step 1: Write the failing scoring test**

```swift
// LearningEngine/Tests/LearningEngineTests/PracticeScoringTests.swift
import XCTest
@testable import LearningEngine

final class PracticeScoringTests: XCTestCase {
    func test_belowFiftyPercent_isAgain() {
        XCTAssertEqual(PracticeScoring.rating(correct: 0, total: 8), .again)
        XCTAssertEqual(PracticeScoring.rating(correct: 3, total: 8), .again)   // 37.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 2, total: 5), .again)   // 40%
    }

    func test_exactlyFiftyPercent_isHard() {
        XCTAssertEqual(PracticeScoring.rating(correct: 4, total: 8), .hard)
        XCTAssertEqual(PracticeScoring.rating(correct: 5, total: 10), .hard)
    }

    func test_betweenFiftyAndSeventyFive_isHard() {
        XCTAssertEqual(PracticeScoring.rating(correct: 5, total: 8), .hard)    // 62.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 7, total: 10), .hard)   // 70%
    }

    func test_exactlySeventyFivePercent_isGood() {
        XCTAssertEqual(PracticeScoring.rating(correct: 6, total: 8), .good)
        XCTAssertEqual(PracticeScoring.rating(correct: 3, total: 4), .good)
    }

    func test_betweenSeventyFiveAndOneHundred_isGood() {
        XCTAssertEqual(PracticeScoring.rating(correct: 7, total: 8), .good)    // 87.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 9, total: 10), .good)
    }

    func test_allCorrect_isEasy() {
        XCTAssertEqual(PracticeScoring.rating(correct: 8, total: 8), .easy)
        XCTAssertEqual(PracticeScoring.rating(correct: 1, total: 1), .easy)
    }

    func test_emptySession_isAgain_andNeverDividesByZero() {
        XCTAssertEqual(PracticeScoring.rating(correct: 0, total: 0), .again)
    }

    func test_selectionSize_isEightForGrammarAndFiveOtherwise_cappedByThePool() {
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 20, skill: .grammar), 8)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 20, skill: .reading), 5)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 3, skill: .grammar), 3)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 2, skill: .reading), 2)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 0, skill: .grammar), 0)
    }
}
```

- [ ] **Step 2: Confirm it cannot compile**

`PracticeScoring` does not exist. Do not push; go to Step 3.

- [ ] **Step 3: Implement `PracticeScoring`**

```swift
// LearningEngine/Sources/LearningEngine/Practice/PracticeScoring.swift
import Foundation

/// Maps a finished practice session onto the FSRS vocabulary the rest of the
/// engine already speaks. Topic-level review (spec "Spaced repetition"): the
/// whole lesson is one card, so the session's score — not any single answer —
/// decides the rating, and the rating is applied only on completion.
public enum PracticeScoring {
    /// Grammar topics serve up to 8 questions per session, every other
    /// practice type up to 5, always capped by what the pool actually holds.
    public static func selectionSize(poolCount: Int, skill: Skill) -> Int {
        let target = skill == .grammar ? 8 : 5
        return min(max(poolCount, 0), target)
    }

    /// `< 50%` Again, `50-74%` Hard, `75-99%` Good, `100%` Easy. Boundaries
    /// are inclusive downward: exactly 50% is Hard, exactly 75% is Good.
    /// A session with no questions rates Again — it proves nothing was learned
    /// and must never divide by zero.
    public static func rating(correct: Int, total: Int) -> FSRSRating {
        guard total > 0 else { return .again }
        if correct >= total { return .easy }
        let share = Double(correct) / Double(total)
        if share < 0.5 { return .again }
        if share < 0.75 { return .hard }
        return .good
    }
}
```

- [ ] **Step 4: Write the failing selection test**

```swift
// LearningEngine/Tests/LearningEngineTests/PracticeQuestionSelectorTests.swift
import XCTest
@testable import LearningEngine

final class PracticeQuestionSelectorTests: XCTestCase {
    let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    func at(_ days: Int) -> Date { epoch.addingTimeInterval(Double(days) * 86_400) }

    func fresh(_ id: String, order: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: nil, lastWasCorrect: nil)
    }

    func wrong(_ id: String, order: Int, day: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: at(day), lastWasCorrect: false)
    }

    func right(_ id: String, order: Int, day: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: at(day), lastWasCorrect: true)
    }

    func test_neverAttemptedComeFirst_thenWrong_thenCorrect() {
        let candidates = [right("c", order: 0, day: 5), wrong("b", order: 1, day: 5), fresh("a", order: 2)]
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["a", "b", "c"]
        )
    }

    func test_withinATier_leastRecentlyAttemptedComesFirst() {
        let candidates = [wrong("recent", order: 0, day: 9), wrong("old", order: 1, day: 1), wrong("mid", order: 2, day: 5)]
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["old", "mid", "recent"]
        )
    }

    func test_neverAttemptedTier_keepsAuthoredOrder() {
        let candidates = [fresh("q3", order: 2), fresh("q1", order: 0), fresh("q2", order: 1)]
        var rng = SeededGenerator(seed: 99)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["q1", "q2", "q3"]
        )
    }

    func test_sameSeedProducesTheSameSelection_andDifferentSeedsMayDiffer() {
        // Six candidates attempted at the SAME instant with the same outcome:
        // every tie-break but the RNG is exhausted.
        let candidates = (0..<6).map { QuestionCandidate(id: "q\($0)", order: $0, lastAttemptedAt: at(3), lastWasCorrect: true) }
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let first = PracticeQuestionSelector.select(from: candidates, size: 3, using: &a)
        let second = PracticeQuestionSelector.select(from: candidates, size: 3, using: &b)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, 3)
        XCTAssertTrue(first.allSatisfy { candidates.map(\.id).contains($0) })
    }

    func test_poolSmallerThanTheRequestedSize_returnsEverything() {
        let candidates = [fresh("a", order: 0), fresh("b", order: 1)]
        var rng = SeededGenerator(seed: 7)
        XCTAssertEqual(PracticeQuestionSelector.select(from: candidates, size: 8, using: &rng), ["a", "b"])
    }

    func test_emptyPool_returnsEmpty() {
        var rng = SeededGenerator(seed: 7)
        XCTAssertEqual(PracticeQuestionSelector.select(from: [], size: 5, using: &rng), [])
    }

    func test_selectionRespectsTheRequestedSize() {
        let candidates = (0..<12).map { fresh("q\($0)", order: $0) }
        var rng = SeededGenerator(seed: 3)
        XCTAssertEqual(PracticeQuestionSelector.select(from: candidates, size: 5, using: &rng).count, 5)
    }

    func test_seededGenerator_isDeterministicAndNotConstant() {
        var a = SeededGenerator(seed: 12345)
        var b = SeededGenerator(seed: 12345)
        let first = (0..<4).map { _ in a.next() }
        let second = (0..<4).map { _ in b.next() }
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, 4, "generator must not repeat itself immediately")
    }
}
```

- [ ] **Step 5: Implement the selector**

```swift
// LearningEngine/Sources/LearningEngine/Practice/PracticeQuestionSelector.swift
import Foundation

/// A deterministic `RandomNumberGenerator` (splitmix64) so question selection
/// can be varied between sessions without becoming untestable: the caller
/// seeds it, the test pins the seed.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // A zero state would make splitmix64 start from a fixed, degenerate
        // point; substitute the golden-ratio constant it uses as its stride.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// SwiftData-free snapshot of one question's attempt history, as far as
/// selection cares about it.
public struct QuestionCandidate: Sendable, Equatable {
    public let id: String
    /// The authored order within the lesson; the tie-break for never-attempted
    /// questions, so a first session always runs front to back.
    public let order: Int
    public let lastAttemptedAt: Date?
    /// Outcome of the most recent attempt; nil when never attempted.
    public let lastWasCorrect: Bool?

    public init(id: String, order: Int, lastAttemptedAt: Date?, lastWasCorrect: Bool?) {
        self.id = id
        self.order = order
        self.lastAttemptedAt = lastAttemptedAt
        self.lastWasCorrect = lastWasCorrect
    }
}

/// Picks which questions a practice session serves (spec "Spaced repetition").
/// Priority: never attempted, then last answered wrong, then answered
/// correctly; within every tier, least recently attempted first. Fully
/// deterministic for a given candidate list and RNG state.
public enum PracticeQuestionSelector {
    private static func tier(_ candidate: QuestionCandidate) -> Int {
        guard let wasCorrect = candidate.lastWasCorrect else { return 0 }
        return wasCorrect ? 2 : 1
    }

    public static func select(
        from candidates: [QuestionCandidate],
        size: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        guard size > 0, !candidates.isEmpty else { return [] }

        // A per-call random key breaks ties that tier/recency/order cannot,
        // so two identical-history questions don't always appear in the same
        // relative position across sessions. Drawn once per candidate, before
        // sorting, so the comparator stays a pure function of the keys.
        var keyed: [(candidate: QuestionCandidate, key: UInt64)] = []
        keyed.reserveCapacity(candidates.count)
        for candidate in candidates {
            keyed.append((candidate, generator.next()))
        }

        let sorted = keyed.sorted { lhs, rhs in
            let lt = tier(lhs.candidate), rt = tier(rhs.candidate)
            if lt != rt { return lt < rt }
            // Never-attempted questions have no date; authored order decides.
            let ld = lhs.candidate.lastAttemptedAt, rd = rhs.candidate.lastAttemptedAt
            if let ld, let rd, ld != rd { return ld < rd }
            if lhs.candidate.order != rhs.candidate.order {
                return lhs.candidate.order < rhs.candidate.order
            }
            if lhs.key != rhs.key { return lhs.key < rhs.key }
            return lhs.candidate.id < rhs.candidate.id
        }

        return sorted.prefix(size).map(\.candidate.id)
    }
}
```

> The RNG only settles ties that tier, recency and authored order all leave open. With distinct `order` values — which the Task 2 content lint guarantees — selection is fully reproducible regardless of seed; the RNG exists so that 7b/7c content with duplicate ordering still varies. `test_sameSeedProducesTheSameSelection_andDifferentSeedsMayDiffer` pins reproducibility; nothing asserts that two *different* seeds differ, because with distinct `order` values they legitimately do not.

- [ ] **Step 6: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Practice LearningEngine/Tests/LearningEngineTests/PracticeScoringTests.swift LearningEngine/Tests/LearningEngineTests/PracticeQuestionSelectorTests.swift
git commit -m "$(cat <<'EOF'
Add practice score-to-FSRS-rating mapping and question selection

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`.

---

## Task 5: `practiceReview` plan task, coordinator snapshots, and routing

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Planning/PlanTypes.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift`
- Modify: `App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift`
- Modify: `App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift`
- Modify: `App/Sources/EnglishApp/Today/PlanTaskAction.swift`
- Modify: `App/Sources/EnglishApp/DesignSystem/PlanTaskRow.swift`
- Modify: `App/Sources/EnglishApp/Study/StudySessionViewModel.swift` (one line in `card(from:)`)
- Test: `LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift` (extend)
- Test: `App/Tests/EnglishAppTests/PlanTaskActionTests.swift` (extend)
- Test: `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift` (extend)

**Interfaces:**
- Consumes: Task 1's `LearningItemType.isVocabularyCard`, `Skill.forItem(type:lessonSkill:)`.
- Produces:
  - `DuePracticeCard(itemID:lessonID:title:skill:dueDate:)`
  - `PlanTask.practiceReview(itemID: String, lessonID: String, title: String, skill: Skill, minutes: Double, isDone: Bool)`
  - `DailyPlanInput.duePracticeCards: [DuePracticeCard]` (new **last** init parameter, defaulted to `[]`)
  - `DailyPlanBuilder.minutesPerPracticeReview = 3.0`, `DailyPlanBuilder.maxPracticeReviewsPerDay = 2`
  - `PlanTaskAction.startPractice(lessonID: String)`, `PlanTaskAction.startPracticeReview(itemID: String, lessonID: String)`

### The three leaks this task must close

Practice cards are `UserItemState` rows exactly like vocabulary items, so without explicit filtering they would silently contaminate the vocabulary flow:

1. `TodayPlanCoordinator.buildPlanInput`'s `dueNowCount` would count due practice cards, inflating the "Kelime tekrarı" task.
2. `TodaySessionCoordinator.buildTodaySession` would hand a practice card to `StudySessionViewModel`, which would render a grammar topic as a flashcard.
3. `TodayPlanCoordinator.stats().wordsSeen` would count practice cards as learned words.

Plus one attribution bug: `pastWeekSkillMinutes` credits review minutes via `Skill.forItemType`, which sends every practice-set review to `reading` regardless of the owning lesson.

- [ ] **Step 1: Write the failing planner tests**

Add to `LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift`:

```swift
    func card(_ id: String, _ skill: Skill, day: Int = 0) -> DuePracticeCard {
        DuePracticeCard(
            itemID: id, lessonID: "lesson-\(id)", title: "T-\(id)", skill: skill,
            dueDate: startOfToday.addingTimeInterval(Double(day) * 86_400)
        )
    }

    func practiceIDs(_ plan: DailyPlan) -> [String] {
        plan.tasks.compactMap { if case .practiceReview(let id, _, _, _, _, _) = $0 { return id } else { return nil } }
    }

    func test_practiceReview_isCappedAtTwoPerDay_earliestDueFirst() {
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 30,
            practice: [card("p3", .grammar, day: 3), card("p1", .reading, day: 1), card("p2", .grammar, day: 2)]
        ))
        XCTAssertEqual(practiceIDs(plan), ["p1", "p2"])
    }

    func test_practiceReview_sitsAfterTheVocabularyReviewTask_andBeforeLessons() {
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 30, lessons: [lesson("v1", .vocabulary)], due: 5,
            practice: [card("p1", .grammar)]
        ))
        guard case .review = plan.tasks[0] else { return XCTFail("expected review first, got \(plan.tasks[0])") }
        guard case .practiceReview(let itemID, _, _, let skill, let minutes, let isDone) = plan.tasks[1] else {
            return XCTFail("expected practiceReview second, got \(plan.tasks[1])")
        }
        XCTAssertEqual(itemID, "p1")
        XCTAssertEqual(skill, .grammar)
        XCTAssertEqual(minutes, 3, accuracy: 1e-9)
        XCTAssertFalse(isDone)
        guard case .lesson = plan.tasks[2] else { return XCTFail("expected lesson third, got \(plan.tasks[2])") }
    }

    func test_practiceReviewMinutes_countTowardTheDailyTotalAndSqueezeLessons() {
        // Budget 20; review 5 due cards = 2 min; two practice reviews = 6 min;
        // that leaves room for exactly one 8-minute lesson before the budget
        // is exceeded.
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 20, lessons: [lesson("v1", .vocabulary), lesson("v2", .vocabulary)], due: 5,
            practice: [card("p1", .grammar), card("p2", .reading)]
        ))
        XCTAssertEqual(practiceIDs(plan), ["p1", "p2"])
        XCTAssertEqual(lessonIDs(plan), ["v1"])
        XCTAssertEqual(plan.totalMinutes, 2 + 6 + 8, accuracy: 1e-9)
    }

    func test_practiceReview_isSkippedOnceTheBudgetIsSpent() {
        // Budget 4; review cap is half of it, 5 cards = 2 min. 2 < 4 so one
        // practice review is added (2 + 3 = 5), and the second is not.
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 4, due: 5, practice: [card("p1", .grammar), card("p2", .grammar)]
        ))
        XCTAssertEqual(practiceIDs(plan), ["p1"])
    }

    func test_aDonePracticeReview_keepsTheTaskButDoesNotBlockPlanCompletion() {
        let done = DuePracticeCard(itemID: "p1", lessonID: "l1", title: "T", skill: .grammar, dueDate: startOfToday, isDone: true)
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 30, practice: [done]))
        XCTAssertEqual(practiceIDs(plan), ["p1"])
        XCTAssertTrue(plan.isComplete)
    }

    func test_noDuePracticeCards_producesNoPracticeTask() {
        let plan = DailyPlanBuilder().build(input(lessons: [lesson("v1", .vocabulary)]))
        XCTAssertTrue(practiceIDs(plan).isEmpty)
    }
```

and extend the existing `input(...)` helper with one more defaulted parameter, `practice: [DuePracticeCard] = []`, passed through as `duePracticeCards: practice`.

- [ ] **Step 2: Add the plan types**

In `Planning/PlanTypes.swift`, add the snapshot type:

```swift
/// A practice card (grammar topic or practice set) that FSRS says is due.
/// `isDone` is true when this user already reviewed it today.
public struct DuePracticeCard: Sendable, Equatable {
    public let itemID: String
    public let lessonID: String
    public let title: String
    public let skill: Skill
    public let dueDate: Date
    public let isDone: Bool

    public init(itemID: String, lessonID: String, title: String, skill: Skill, dueDate: Date, isDone: Bool = false) {
        self.itemID = itemID
        self.lessonID = lessonID
        self.title = title
        self.skill = skill
        self.dueDate = dueDate
        self.isDone = isDone
    }
}
```

add the case to `PlanTask`:

```swift
public enum PlanTask: Sendable, Equatable {
    case review(cardCount: Int, minutes: Double, isDone: Bool)
    case lesson(id: String, title: String, skill: Skill, minutes: Double, isDone: Bool)
    /// A due grammar topic / practice set, re-served as a fresh selection of
    /// questions from its lesson's pool.
    case practiceReview(itemID: String, lessonID: String, title: String, skill: Skill, minutes: Double, isDone: Bool)
    case locked(id: String, title: String)
}
```

extend `DailyPlanInput` with a stored property `public let duePracticeCards: [DuePracticeCard]`, a matching `self.duePracticeCards = duePracticeCards` assignment and a **last**, defaulted init parameter `duePracticeCards: [DuePracticeCard] = []` (defaulted so the existing `DailyPlanBuilderTests` helper and `TodayPlanCoordinator` keep compiling), and update `DailyPlan.isComplete`:

```swift
    public var isComplete: Bool {
        tasks.allSatisfy { task in
            switch task {
            case .review(_, _, let isDone),
                 .lesson(_, _, _, _, let isDone),
                 .practiceReview(_, _, _, _, _, let isDone):
                return isDone
            case .locked: return true
            }
        }
    }
```

- [ ] **Step 3: Build the task in `DailyPlanBuilder`**

Add the two constants beside the existing ones:

```swift
    public static let minutesPerPracticeReview = 3.0
    public static let maxPracticeReviewsPerDay = 2
```

and insert this block immediately after the "1. Review task" block, before "2. Lesson selection":

```swift
        // 1b. Practice reviews: at most two a day, earliest due first, placed
        // right after the vocabulary review and inside the same budget.
        var practiceMinutes = 0.0
        let duePractice = input.duePracticeCards
            .sorted { ($0.dueDate, $0.itemID) < ($1.dueDate, $1.itemID) }
            .prefix(Self.maxPracticeReviewsPerDay)
        for practiceCard in duePractice where reviewMinutes + practiceMinutes < budget {
            tasks.append(.practiceReview(
                itemID: practiceCard.itemID, lessonID: practiceCard.lessonID,
                title: practiceCard.title, skill: practiceCard.skill,
                minutes: Self.minutesPerPracticeReview, isDone: practiceCard.isDone
            ))
            practiceMinutes += Self.minutesPerPracticeReview
        }
```

then change the lesson loop's budget test and the returned total so practice minutes count:

```swift
        while reviewMinutes + practiceMinutes + plannedLessonMinutes < budget, let lesson = nextLesson() {
            add(lesson)
        }
```

```swift
        return DailyPlan(
            tasks: tasks,
            totalMinutes: reviewMinutes + practiceMinutes + plannedLessonMinutes,
            weeklyBalance: balance
        )
```

- [ ] **Step 4: Run the planner tests**

Once Step 7's push happens these run in CI. Expected: the six new tests pass and every pre-existing `DailyPlanBuilderTests` case still passes unchanged (with no practice cards supplied, the new block is a no-op).

- [ ] **Step 5: Snapshot due practice cards in `TodayPlanCoordinator`, and stop the three leaks**

In `App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift`:

Add a helper that indexes practice items once:

```swift
    /// itemID → (lesson id, lesson title, lesson skill) for every grammar
    /// topic / practice set in the installed content.
    private func practiceItemIndex() throws -> [String: (lessonID: String, title: String, skill: Skill)] {
        var index: [String: (lessonID: String, title: String, skill: Skill)] = [:]
        for item in try context.fetch(FetchDescriptor<LearningItem>()) where !item.type.isVocabularyCard {
            guard let lesson = item.lesson else { continue }
            index[item.id] = (lesson.id, lesson.title, Skill.forItem(type: item.type, lessonSkill: lesson.skill))
        }
        return index
    }
```

In `buildPlanInput()`, replace the `dueNowCount` / `reviewedTodayCount` block with a version that separates the two populations, and pass the new input through:

```swift
        let existingItemIDs = try existingItemIDs()
        let practiceIndex = try practiceItemIndex()
        let dueNowRows = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue && $0.dueDate <= nowValue }))
        let todaysLogs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.userID == userIDValue && $0.reviewedAt >= startOfToday }))
        let reviewedTodayIDs = Set(todaysLogs.filter { existingItemIDs.contains($0.itemID) }.map(\.itemID))

        // Practice cards live in UserItemState exactly like vocabulary items,
        // so the vocabulary review task must exclude them explicitly or it
        // would count grammar topics as due words.
        let dueVocabularyRows = dueNowRows.filter { existingItemIDs.contains($0.itemID) && practiceIndex[$0.itemID] == nil }
        let dueNowCount = dueVocabularyRows.count
        let reviewedTodayCount = reviewedTodayIDs.subtracting(practiceIndex.keys).count

        let duePracticeCards: [DuePracticeCard] = dueNowRows.compactMap { state in
            guard let entry = practiceIndex[state.itemID] else { return nil }
            return DuePracticeCard(
                itemID: state.itemID, lessonID: entry.lessonID, title: entry.title,
                skill: entry.skill, dueDate: state.dueDate,
                isDone: reviewedTodayIDs.contains(state.itemID)
            )
        }

        return DailyPlanInput(
            weights: package.skillWeights,
            dailyMinutes: profile.dailyMinutes,
            lessonsInPathOrder: planLessons,
            dueNowCount: dueNowCount,
            reviewedTodayCount: reviewedTodayCount,
            pastWeekSkillMinutes: try pastWeekSkillMinutes(startOfToday: startOfToday, lessons: lessons),
            startOfToday: startOfToday,
            duePracticeCards: duePracticeCards
        )
```

In `stats()`, exclude practice cards from `wordsSeen`:

```swift
        let practiceIndex = try practiceItemIndex()
        let itemStates = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue }))
        let wordsSeen = itemStates.filter { existingItemIDs.contains($0.itemID) && practiceIndex[$0.itemID] == nil }.count
```

In `pastWeekSkillMinutes(startOfToday:lessons:)`, attribute review minutes by the owning lesson's skill:

```swift
        if !logs.isEmpty {
            let items = try context.fetch(FetchDescriptor<LearningItem>())
            let skillByID = Dictionary(
                items.map { ($0.id, Skill.forItem(type: $0.type, lessonSkill: $0.lesson?.skill)) },
                uniquingKeysWith: { first, _ in first }
            )
            for log in logs {
                guard let skill = skillByID[log.itemID] else { continue }
                minutes[skill, default: 0] += DailyPlanBuilder.minutesPerReviewCard
            }
        }
```

In `App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift`, keep practice cards out of the flashcard queue by adding one predicate to the `seenItems` filter:

```swift
        let seenItems = try context.fetch(FetchDescriptor<LearningItem>())
            .filter { seenIDs.contains($0.id) && $0.content != nil && $0.type.isVocabularyCard }
```

In `App/Sources/EnglishApp/Study/StudySessionViewModel.swift`, make the card's skill lesson-aware (last argument of `Card(...)` in `card(from:)`):

```swift
            collocations: content.collocations,
            skill: Skill.forItem(type: item.type, lessonSkill: item.lesson?.skill)
```

- [ ] **Step 6: Route the new tasks**

`App/Sources/EnglishApp/Today/PlanTaskAction.swift`:

```swift
import Foundation
import LearningEngine

/// What tapping a plan row does. Vocabulary lessons open the flashcard
/// session; grammar and reading lessons open the practice session (Slice 7a
/// ships content for both). `.comingSoon` now means only "this skill has no
/// content yet" — listening, writing, speaking, pronunciation.
enum PlanTaskAction: Equatable {
    case startReview(cardCount: Int)
    case startLesson(id: String)
    case startPractice(lessonID: String)
    case startPracticeReview(itemID: String, lessonID: String)
    case comingSoon(title: String)
    case locked(title: String)
    case none

    /// Skills that have shipped practice content. Everything else still shows
    /// "Bu ders türü yakında".
    static let skillsWithPracticeContent: Set<Skill> = [.grammar, .reading]

    static func action(for task: PlanTask) -> PlanTaskAction {
        switch task {
        case .review(let count, _, let isDone):
            return isDone ? .none : .startReview(cardCount: count)
        case .lesson(let id, let title, let skill, _, let isDone):
            if isDone { return .none }
            if skill == .vocabulary { return .startLesson(id: id) }
            if skillsWithPracticeContent.contains(skill) { return .startPractice(lessonID: id) }
            return .comingSoon(title: title)
        case .practiceReview(let itemID, let lessonID, _, _, _, let isDone):
            return isDone ? .none : .startPracticeReview(itemID: itemID, lessonID: lessonID)
        case .locked(_, let title):
            return .locked(title: title)
        }
    }
}
```

`App/Sources/EnglishApp/DesignSystem/PlanTaskRow.swift` — four non-exhaustive switches now fail to compile. Update each:

```swift
    static func title(_ task: PlanTask) -> String {
        switch task {
        case .review: return "Kelime tekrarı"
        case .lesson(_, let title, _, _, _),
             .practiceReview(_, _, let title, _, _, _),
             .locked(_, let title): return title
        }
    }

    static func subtitle(_ task: PlanTask) -> String {
        switch task {
        case .review(let count, let minutes, let isDone):
            return isDone ? "\(count) kart · bitti" : "\(count) kart · \(self.minutes(minutes)) dk"
        case .lesson(_, _, let skill, let minutes, let isDone):
            return isDone ? "\(skill.displayName) · bitti" : "Yeni ders · \(skill.displayName) · \(self.minutes(minutes)) dk"
        case .practiceReview(_, _, _, let skill, let minutes, let isDone):
            return isDone ? "\(skill.displayName) tekrarı · bitti" : "Konu tekrarı · \(skill.displayName) · \(self.minutes(minutes)) dk"
        case .locked:
            return "Paketi aç"
        }
    }
```

and in `PlanTaskRow` itself:

```swift
    private var isDone: Bool {
        switch task {
        case .review(_, _, let done),
             .lesson(_, _, _, _, let done),
             .practiceReview(_, _, _, _, _, let done): return done
        case .locked: return false
        }
    }
```

```swift
    private var iconName: String {
        if isDone { return "checkmark" }
        switch task {
        case .review: return "arrow.triangle.2.circlepath"
        case .lesson: return "text.book.closed"
        case .practiceReview: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .locked: return "lock.fill"
        }
    }

    private var tint: Color {
        switch task {
        case .review: return Theme.primary
        case .lesson(_, _, let skill, _, _), .practiceReview(_, _, _, let skill, _, _): return skill.color
        case .locked: return Theme.secondaryInk
        }
    }
```

and add one preview row inside the existing `#Preview("Plan rows")` block:

```swift
        PlanTaskRow(task: .practiceReview(itemID: "i", lessonID: "l", title: "Zamanlar (Tenses)", skill: .grammar, minutes: 3, isDone: false), isHighlighted: false) {}
```

- [ ] **Step 7: Extend the routing and coordinator tests**

Replace the body of `App/Tests/EnglishAppTests/PlanTaskActionTests.swift`'s `test_actions` and add a second test:

```swift
    func test_actions() {
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: false)), .startReview(cardCount: 12))
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: false)), .startLesson(id: "l1"))
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .locked(id: "x", title: "Law · 1")), .locked(title: "Law · 1"))
    }

    func test_lessonsWithShippedPracticeContent_openThePracticeSession() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "g1", title: "Zamanlar (Tenses)", skill: .grammar, minutes: 8, isDone: false)),
            .startPractice(lessonID: "g1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "r1", title: "Okuma", skill: .reading, minutes: 10, isDone: false)),
            .startPractice(lessonID: "r1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "r1", title: "Okuma", skill: .reading, minutes: 10, isDone: true)),
            .none
        )
    }

    func test_skillsWithoutContent_stillShowComingSoon() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "d1", title: "Dinleme 1", skill: .listening, minutes: 8, isDone: false)),
            .comingSoon(title: "Dinleme 1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "w1", title: "Yazma 1", skill: .writing, minutes: 8, isDone: false)),
            .comingSoon(title: "Yazma 1")
        )
    }

    func test_practiceReviewRouting() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .practiceReview(itemID: "i1", lessonID: "l1", title: "Zamanlar", skill: .grammar, minutes: 3, isDone: false)),
            .startPracticeReview(itemID: "i1", lessonID: "l1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .practiceReview(itemID: "i1", lessonID: "l1", title: "Zamanlar", skill: .grammar, minutes: 3, isDone: true)),
            .none
        )
    }
```

Add to `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift` (these use the real bundled package, so they need the `AppModelContainer.schema` context with real content seeded — add a `makeRealContentContext()` helper alongside the existing `makeContext`):

```swift
    func makeRealContentContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    /// A due practice card must produce a practiceReview task and must NOT be
    /// counted as a due vocabulary word.
    func test_duePracticeCard_becomesAPracticeReviewTask_andIsNotCountedAsAVocabularyReview() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(
            userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5,
            dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past
        ))
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.dueNowCount, 0, "a due grammar topic must not inflate the vocabulary review task")
        XCTAssertEqual(input.duePracticeCards.map(\.itemID), ["yds-practice-card-tenses"])
        XCTAssertEqual(input.duePracticeCards.first?.skill, .grammar)
        XCTAssertEqual(input.duePracticeCards.first?.lessonID, "yds-practice-lesson-tenses")
        XCTAssertEqual(input.duePracticeCards.first?.title, "Zamanlar (Tenses)")
        XCTAssertFalse(input.duePracticeCards.first?.isDone ?? true)

        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        XCTAssertTrue(plan.tasks.contains { if case .practiceReview(let id, _, _, _, _, _) = $0 { return id == "yds-practice-card-tenses" } else { return false } })
    }

    func test_practiceCards_areNotCountedAsWordsSeen() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        context.insert(UserItemState(userID: userID, itemID: "yds-vocab1-item-economy", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        try context.save()

        XCTAssertEqual(try coordinator(context).stats().wordsSeen, 1)
    }

    func test_aPracticeCardReviewedToday_marksTheTaskDone() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        context.insert(ReviewLog(userID: userID, itemID: "yds-practice-card-tenses", rating: .good, reviewedAt: past, reactionTimeMs: 0))
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.reviewedTodayCount, 0, "a practice review must not count as a vocabulary review")
        XCTAssertTrue(input.duePracticeCards.first?.isDone ?? false)
    }
```

- [ ] **Step 8: Commit**

```bash
git add LearningEngine App/Sources App/Tests
git commit -m "$(cat <<'EOF'
Add practiceReview plan task and route practice lessons away from the flashcard flow

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`. `TodayPlanView` and `CoursePathView` still compile because both `switch` on `PlanTaskAction`, not on `PlanTask` — but their `switch`es are now non-exhaustive on the two new actions. Task 9 gives them real behaviour; until then add `case .startPractice, .startPracticeReview: break` to both so this task compiles on its own, and delete those placeholders in Task 9.

---

## Task 6: `PracticeSessionViewModel`

**Files:**
- Create: `App/Sources/EnglishApp/Practice/PracticeSessionViewModel.swift`
- Test: `App/Tests/EnglishAppTests/PracticeSessionViewModelTests.swift` (new)

**Interfaces:**
- Consumes: `Question`, `Passage`, `QuestionAttempt`, `LessonProgress`, `LearningItemType.isVocabularyCard` (Task 1); `PracticeScoring`, `PracticeQuestionSelector`, `QuestionCandidate`, `SeededGenerator` (Task 4); existing `FSRSStateStore`, `FSRSScheduler`, `RatingIntervalFormatter`.
- Produces, for Tasks 7-9:
  - `PracticeSessionViewModel.Mode` — `.lesson(id: String)`, `.review(lessonID: String, itemID: String)`
  - `PracticeSessionViewModel.Step` — `.loading`, `.explanation(String)`, `.question`, `.summary`, `.unavailable`
  - `PracticeSessionViewModel.QuestionVM` — `id`, `prompt`, `options: [String]`, `correctIndex`, `explanationTR`
  - `PracticeSessionViewModel.Summary` — `correctCount`, `total`, `percent: Int`, `missedPrompts: [String]`, `nextReviewText: String?`
  - properties `step`, `questions`, `currentIndex`, `selectedIndex`, `saveError`, `lessonTitle`, `skill`, `passage: PassageVM?`, `contextLine`, `progress`, `progressText`, `current`, `isAnswered`
  - methods `start() throws`, `beginQuestions()`, `select(_:)`, `next()`, `retrySave()`, `clearSaveError()`, `summary()`

### Behaviour contract

| Situation | Behaviour |
|---|---|
| Lesson has a non-empty `explanationTR` topic card | `start()` lands on `.explanation(text)`; `beginQuestions()` moves to `.question` |
| Lesson has no explanation (every practice set) | `start()` lands directly on `.question` |
| Lesson missing, or no questions after selection | `step == .unavailable`; nothing is written |
| Answer tapped | `QuestionAttempt` written **immediately**; `selectedIndex` set; feedback shown |
| Answer tapped again while already answered | ignored |
| Attempt save fails | `saveError` set, `selectedIndex` stays nil, the answer is not registered; `retrySave()` retries the same answer |
| `next()` on the last question | rating applied, `LessonProgress.completedAt` set, `step == .summary` |
| Rating/progress save fails | `saveError` set, `step` stays `.question`; **no** half-complete lesson; `retrySave()` retries the whole finish |
| Quit mid-way (view dismissed) | nothing extra happens — the lesson stays incomplete, and the attempts already written still steer the next selection |

- [ ] **Step 1: Write the failing tests**

```swift
// App/Tests/EnglishAppTests/PracticeSessionViewModelTests.swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

@MainActor
final class PracticeSessionViewModelTests: XCTestCase {
    let userID = "u"
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    func viewModel(_ context: ModelContext, mode: PracticeSessionViewModel.Mode) -> PracticeSessionViewModel {
        PracticeSessionViewModel(mode: mode, context: context, userID: userID, clock: { self.now }, seed: 7)
    }

    /// Answers every served question, choosing the key for the first
    /// `correctCount` of them and a deliberately wrong option for the rest.
    func answerAll(_ vm: PracticeSessionViewModel, correctCount: Int) {
        for index in vm.questions.indices {
            guard let question = vm.current else { return XCTFail("ran out of questions at \(index)") }
            let wrong = question.correctIndex == 0 ? 1 : 0
            vm.select(index < correctCount ? question.correctIndex : wrong)
            vm.next()
        }
    }

    func test_grammarLesson_startsOnTheTurkishExplanation_thenGoesToQuestions() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-tenses"))
        try vm.start()

        guard case .explanation(let text) = vm.step else { return XCTFail("expected .explanation, got \(vm.step)") }
        XCTAssertTrue(text.contains("Past perfect"))
        XCTAssertEqual(vm.lessonTitle, "Zamanlar (Tenses)")
        XCTAssertEqual(vm.skill, .grammar)

        vm.beginQuestions()
        XCTAssertEqual(vm.step, .question)
        XCTAssertEqual(vm.questions.count, 8, "grammar lessons serve up to 8 questions")
        XCTAssertEqual(vm.progressText, "1/8")
        XCTAssertEqual(vm.current?.options.count, 5)
    }

    func test_readingLesson_skipsTheExplanation_andExposesThePassage() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()

        XCTAssertEqual(vm.step, .question)
        XCTAssertEqual(vm.questions.count, 5, "non-grammar lessons serve up to 5 questions")
        XCTAssertEqual(vm.passage?.title, "Carbon Pricing in Practice")
        XCTAssertFalse(vm.passage?.body.isEmpty ?? true)
    }

    func test_selectingAnOption_writesAnAttemptImmediately_andShowsFeedback() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)

        vm.select(question.correctIndex)

        XCTAssertEqual(vm.selectedIndex, question.correctIndex)
        XCTAssertTrue(vm.isAnswered)
        let attempts = try context.fetch(FetchDescriptor<QuestionAttempt>())
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.questionID, question.id)
        XCTAssertEqual(attempts.first?.selectedIndex, question.correctIndex)
        XCTAssertTrue(attempts.first?.wasCorrect ?? false)
        XCTAssertEqual(attempts.first?.answeredAt, now)
    }

    func test_selectingTwice_isIgnored() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)

        vm.select(question.correctIndex)
        vm.select(question.correctIndex == 0 ? 1 : 0)

        XCTAssertEqual(vm.selectedIndex, question.correctIndex)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 1)
    }

    func test_completingWithEveryAnswerCorrect_ratesEasy_marksTheLessonDone_andSummarises() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        answerAll(vm, correctCount: 5)

        XCTAssertEqual(vm.step, .summary)
        let summary = vm.summary()
        XCTAssertEqual(summary.correctCount, 5)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.percent, 100)
        XCTAssertTrue(summary.missedPrompts.isEmpty)
        XCTAssertNotNil(summary.nextReviewText)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.map(\.itemID), ["yds-practice-card-reading-1"])
        XCTAssertEqual(logs.first?.rating, .easy)

        let progressID = LessonProgress.makeID(userID: userID, lessonID: "yds-practice-lesson-reading-1")
        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first)
        XCTAssertEqual(progress.completedAt, now)
    }

    func test_scoringUnderFiftyPercent_ratesAgain_andListsTheMissedQuestions() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        answerAll(vm, correctCount: 2)   // 2/5 = 40%

        let summary = vm.summary()
        XCTAssertEqual(summary.correctCount, 2)
        XCTAssertEqual(summary.percent, 40)
        XCTAssertEqual(summary.missedPrompts.count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLog>()).first?.rating, .again)
    }

    func test_quittingMidway_leavesTheLessonIncomplete_butKeepsTheAttempts() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)
        vm.select(question.correctIndex)
        // The view is dismissed here; no further calls.

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 0)
        let progressID = LessonProgress.makeID(userID: userID, lessonID: "yds-practice-lesson-reading-1")
        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first)
        XCTAssertNil(progress.completedAt, "a half-finished session must never mark the lesson complete")
    }

    func test_reopeningAfterAQuit_startsFromTheBeginning_butPrefersUnattemptedQuestions() throws {
        let context = try makeContext()
        // Tenses has 8 questions and serves 8, so instead use sentence
        // completion: 15 authored, 5 served — selection actually has a choice.
        let first = viewModel(context, mode: .lesson(id: "yds-practice-lesson-sentence-1"))
        try first.start()
        let firstIDs = first.questions.map(\.id)
        XCTAssertEqual(firstIDs.count, 5)
        answerAll(first, correctCount: 5)

        let second = viewModel(context, mode: .lesson(id: "yds-practice-lesson-sentence-1"))
        try second.start()
        XCTAssertEqual(second.currentIndex, 0)
        XCTAssertEqual(second.progressText, "1/5")
        XCTAssertTrue(
            second.questions.map(\.id).allSatisfy { !firstIDs.contains($0) },
            "never-attempted questions outrank already-answered ones"
        )
    }

    func test_reviewMode_reSelectsFromTheSameLessonsPool() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .review(lessonID: "yds-practice-lesson-sentence-1", itemID: "yds-practice-card-sentence-1"))
        try vm.start()

        XCTAssertEqual(vm.questions.count, 5)
        XCTAssertEqual(vm.lessonTitle, "Cümle Tamamlama")
        XCTAssertEqual(vm.contextLine, "KONU TEKRARI · CÜMLE TAMAMLAMA")
        answerAll(vm, correctCount: 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLog>()).first?.itemID, "yds-practice-card-sentence-1")
    }

    func test_poolSmallerThanTheSelectionSize_asksEveryQuestion() throws {
        let context = try makeContext()
        // Reading lesson 1 has exactly 5 questions and the target is 5.
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        XCTAssertEqual(vm.questions.count, 5)
    }

    func test_missingLesson_isUnavailable_andWritesNothing() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "no-such-lesson"))
        try vm.start()

        XCTAssertEqual(vm.step, .unavailable)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LessonProgress>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 0)
    }

    func test_saveFailureOnFinish_surfacesAnError_keepsTheLessonIncomplete_andRetrySucceeds() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        vm.failNextSaveForTesting = true
        answerAll(vm, correctCount: 5)

        XCTAssertNotNil(vm.saveError)
        XCTAssertEqual(vm.step, .question, "the screen stays open — no half-complete 'lesson done' state")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 0)

        vm.retrySave()

        XCTAssertNil(vm.saveError)
        XCTAssertEqual(vm.step, .summary)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 1)
    }

    func test_contextLine_usesTurkishUppercasing_withADottedCapitalI() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        // tr_TR uppercases "i" to the dotted "İ": "Karbon Fiyatlandırması" has
        // none, but the "Okuma:" prefix and the word "İngilizce" elsewhere do.
        XCTAssertEqual(vm.contextLine, "YENİ DERS · OKUMA: KARBON FİYATLANDIRMASI")
    }
}
```

> `test_contextLine_...` is the tr_TR trap in test form: `"Yeni ders"` uppercases to `"YENİ DERS"`, never `"YENI DERS"`. Assert the literal dotted form.

- [ ] **Step 2: Confirm it cannot compile**

`PracticeSessionViewModel` does not exist. Go to Step 3.

- [ ] **Step 3: Implement the view model**

```swift
// App/Sources/EnglishApp/Practice/PracticeSessionViewModel.swift
import Foundation
import Observation
import SwiftData
import LearningEngine

/// Drives every practice lesson type from one place. The screen only ever
/// reads `step`, `current`, `selectedIndex` and `summary()`; all SwiftData
/// access lives here (spec "Screens and flow").
@MainActor
@Observable
final class PracticeSessionViewModel {
    enum Mode: Equatable {
        /// Opened from Bugün or Ders Yolu.
        case lesson(id: String)
        /// Opened from a due practice card: same lesson, fresh selection.
        case review(lessonID: String, itemID: String)

        var lessonID: String {
            switch self {
            case .lesson(let id): return id
            case .review(let lessonID, _): return lessonID
            }
        }
    }

    enum Step: Equatable {
        case loading
        case explanation(String)
        case question
        case summary
        /// The lesson is gone, or has no questions to serve.
        case unavailable
    }

    struct QuestionVM: Equatable, Identifiable {
        let id: String
        let prompt: String
        let options: [String]
        let correctIndex: Int
        let explanationTR: String
    }

    struct PassageVM: Equatable {
        let title: String
        let body: String
    }

    struct Summary: Equatable {
        let correctCount: Int
        let total: Int
        let percent: Int
        let missedPrompts: [String]
        /// "3 gün" — nil only if the FSRS update has not run yet.
        let nextReviewText: String?
    }

    let mode: Mode
    private(set) var step: Step = .loading
    private(set) var questions: [QuestionVM] = []
    private(set) var currentIndex = 0
    private(set) var selectedIndex: Int?
    private(set) var saveError: String?
    private(set) var lessonTitle = ""
    private(set) var skill: Skill = .grammar
    private(set) var passage: PassageVM?

    /// Test seam: makes the next `context.save()` throw, so the save-failure
    /// path can be exercised without a broken store.
    var failNextSaveForTesting = false

    private let context: ModelContext
    private let userID: String
    private let scheduler: FSRSScheduler
    private let clock: () -> Date
    private let seed: UInt64
    private var cardItemID: String?
    private var answers: [(questionID: String, wasCorrect: Bool)] = []
    private var nextDueDate: Date?
    /// Set when `finish()` fails, so `retrySave()` knows what to redo.
    private var finishPending = false

    init(
        mode: Mode, context: ModelContext, userID: String,
        scheduler: FSRSScheduler = FSRSScheduler(),
        clock: @escaping () -> Date = Date.init,
        seed: UInt64? = nil
    ) {
        self.mode = mode
        self.context = context
        self.userID = userID
        self.scheduler = scheduler
        self.clock = clock
        self.seed = seed ?? UInt64(bitPattern: Int64(clock().timeIntervalSince1970.rounded()))
    }

    var current: QuestionVM? { currentIndex < questions.count ? questions[currentIndex] : nil }

    var isAnswered: Bool { selectedIndex != nil }

    var progress: Double { questions.isEmpty ? 0 : Double(currentIndex) / Double(questions.count) }

    var progressText: String { "\(min(currentIndex + 1, questions.count))/\(questions.count)" }

    var contextLine: String {
        let title = lessonTitle.uppercased(with: Locale(identifier: "tr_TR"))
        switch mode {
        case .lesson: return "YENİ DERS · \(title)"
        case .review: return "KONU TEKRARI · \(title)"
        }
    }

    func start() throws {
        let lessonID = mode.lessonID
        guard let lesson = try context.fetch(FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonID })).first else {
            step = .unavailable
            return
        }
        lessonTitle = lesson.title
        skill = lesson.skill
        if let storedPassage = lesson.passage {
            passage = PassageVM(title: storedPassage.title, body: storedPassage.body)
        }

        let card = lesson.items.first { !$0.type.isVocabularyCard }
        cardItemID = card?.id

        let pool = lesson.questions
        guard !pool.isEmpty, cardItemID != nil else {
            step = .unavailable
            return
        }

        let lastAttempt = try lastAttempts(for: Set(pool.map(\.id)))
        let candidates = pool.map { question in
            QuestionCandidate(
                id: question.id, order: question.order,
                lastAttemptedAt: lastAttempt[question.id]?.answeredAt,
                lastWasCorrect: lastAttempt[question.id]?.wasCorrect
            )
        }
        var generator = SeededGenerator(seed: seed)
        let size = PracticeScoring.selectionSize(poolCount: pool.count, skill: lesson.skill)
        let chosenIDs = PracticeQuestionSelector.select(from: candidates, size: size, using: &generator)
        let byID = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        questions = chosenIDs.compactMap { id in
            guard let question = byID[id] else { return nil }
            return QuestionVM(
                id: question.id, prompt: question.prompt, options: question.options,
                correctIndex: question.correctIndex, explanationTR: question.explanationTR
            )
        }
        guard !questions.isEmpty else {
            step = .unavailable
            return
        }

        let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        if try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).isEmpty {
            context.insert(LessonProgress(userID: userID, lessonID: lessonID, startedAt: clock()))
            try context.save()
        }

        currentIndex = 0
        selectedIndex = nil
        let explanation = card?.content?.explanationTR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        step = explanation.isEmpty ? .question : .explanation(explanation)
    }

    /// "Sorulara geç" on the explanation card.
    func beginQuestions() {
        guard case .explanation = step else { return }
        step = .question
    }

    /// Commits an answer. Every answer is persisted immediately, so quitting
    /// mid-way still informs the next selection (spec "Recording rules").
    func select(_ index: Int) {
        guard selectedIndex == nil, let question = current else { return }
        let attempt = QuestionAttempt(
            userID: userID, questionID: question.id,
            wasCorrect: index == question.correctIndex,
            answeredAt: clock(), selectedIndex: index
        )
        context.insert(attempt)
        do {
            try save()
        } catch {
            context.delete(attempt)
            saveError = error.localizedDescription
            return
        }
        answers.append((question.id, index == question.correctIndex))
        selectedIndex = index
    }

    /// "Sonraki" on the feedback card.
    func next() {
        guard isAnswered else { return }
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedIndex = nil
            return
        }
        finish()
    }

    func retrySave() {
        saveError = nil
        if finishPending { finish() }
    }

    func clearSaveError() { saveError = nil }

    func summary() -> Summary {
        let correct = answers.filter(\.wasCorrect).count
        let total = answers.count
        let missedIDs = Set(answers.filter { !$0.wasCorrect }.map(\.questionID))
        return Summary(
            correctCount: correct,
            total: total,
            percent: total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()),
            missedPrompts: questions.filter { missedIDs.contains($0.id) }.map(\.prompt),
            nextReviewText: nextDueDate.map { RatingIntervalFormatter.text(from: clock(), to: $0) }
        )
    }

    /// Applies the FSRS rating and marks the lesson complete — only ever at
    /// the end of a session, and only as a unit: if either write fails the
    /// screen stays on the question with a retryable error, never in a
    /// half-complete "lesson done" state.
    private func finish() {
        guard let itemID = cardItemID else { return }
        finishPending = true
        let now = clock()
        let rating = PracticeScoring.rating(correct: answers.filter(\.wasCorrect).count, total: answers.count)
        do {
            if failNextSaveForTesting {
                failNextSaveForTesting = false
                throw PracticeSaveError()
            }
            let state = try FSRSStateStore().recordReview(
                userID: userID, itemID: itemID, rating: rating, now: now,
                in: context, scheduler: scheduler
            )
            nextDueDate = state.dueDate

            let lessonID = mode.lessonID
            let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
            if let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first,
               progress.completedAt == nil {
                progress.completedAt = now
                try context.save()
            }
        } catch {
            saveError = error.localizedDescription
            return
        }
        finishPending = false
        step = .summary
    }

    private func save() throws {
        if failNextSaveForTesting {
            failNextSaveForTesting = false
            throw PracticeSaveError()
        }
        try context.save()
    }

    /// Most recent attempt per question id, for this user.
    private func lastAttempts(for questionIDs: Set<String>) throws -> [String: QuestionAttempt] {
        let userIDValue = userID
        let rows = try context.fetch(FetchDescriptor<QuestionAttempt>(
            predicate: #Predicate { $0.userID == userIDValue },
            sortBy: [SortDescriptor(\.answeredAt)]
        ))
        var latest: [String: QuestionAttempt] = [:]
        for row in rows where questionIDs.contains(row.questionID) {
            latest[row.questionID] = row   // sorted ascending, so the last write wins
        }
        return latest
    }
}

/// Stand-in failure used by the test seam; never thrown in production.
struct PracticeSaveError: LocalizedError {
    var errorDescription: String? { "Kaydedilemedi. Tekrar dene." }
}
```

- [ ] **Step 4: Commit**

```bash
git add App/Sources/EnglishApp/Practice App/Tests/EnglishAppTests/PracticeSessionViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add PracticeSessionViewModel driving every practice lesson type

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`.

---

## Task 7: Practice screens — explanation, question, feedback, summary

**Files:**
- Create: `App/Sources/EnglishApp/Practice/PracticeOptionText.swift`
- Create: `App/Sources/EnglishApp/Practice/PracticeSessionView.swift`
- Create: `App/Sources/EnglishApp/Practice/PracticeExplanationView.swift`
- Create: `App/Sources/EnglishApp/Practice/PracticeQuestionView.swift`
- Create: `App/Sources/EnglishApp/Practice/PracticeSummaryView.swift`
- Test: `App/Tests/EnglishAppTests/PracticeOptionTextTests.swift` (new)

**Interfaces:**
- Consumes: Task 6's `PracticeSessionViewModel` surface; existing `Theme`, `PaperCard`, `PrimaryButtonStyle`, `ProgressBar`, `StatTile`, `Font.serifTitle(_:)`, `Skill.color`/`Skill.displayName`.
- Produces: `PracticeSessionView(mode:onClose:)` for Task 9; `PracticeOptionText.letter(_:)` and `PracticeOptionText.accessibilityLabel(index:text:state:)`; `PracticeOptionState` (`.idle`, `.correct`, `.wrongPick`, `.dimmed`).

**Known gap (from the spec's "Testing" section):** CI has no UI tests, so screens are verified by the compile, by the pure `PracticeOptionText` tests, by code review and by TestFlight on a real device. Do not invent a UI test harness here.

- [ ] **Step 1: Write the failing option-text test**

```swift
// App/Tests/EnglishAppTests/PracticeOptionTextTests.swift
import XCTest
@testable import EnglishApp

final class PracticeOptionTextTests: XCTestCase {
    func test_letters_areAThroughE() {
        XCTAssertEqual((0..<5).map(PracticeOptionText.letter), ["A", "B", "C", "D", "E"])
    }

    func test_outOfRangeIndex_fallsBackToTheNumber() {
        XCTAssertEqual(PracticeOptionText.letter(5), "6")
        XCTAssertEqual(PracticeOptionText.letter(-1), "0")
    }

    func test_unansweredOption_readsAsPlainShikki() {
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 0, text: "had already restructured", state: .idle),
            "A şıkkı: had already restructured"
        )
    }

    func test_correctAndWrongOptions_announceTheirStateInWords_notJustColour() {
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 1, text: "because", state: .correct),
            "B şıkkı: because, doğru cevap"
        )
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 2, text: "unless", state: .wrongPick),
            "C şıkkı: unless, senin cevabın, yanlış"
        )
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 3, text: "therefore", state: .dimmed),
            "D şıkkı: therefore"
        )
    }

    func test_stateForOption_derivesFromTheSelectionAndTheKey() {
        // Nothing answered yet.
        XCTAssertEqual(PracticeOptionText.state(index: 2, selectedIndex: nil, correctIndex: 1), .idle)
        // Answered wrongly: the key turns correct, the pick turns wrongPick,
        // everything else dims.
        XCTAssertEqual(PracticeOptionText.state(index: 1, selectedIndex: 2, correctIndex: 1), .correct)
        XCTAssertEqual(PracticeOptionText.state(index: 2, selectedIndex: 2, correctIndex: 1), .wrongPick)
        XCTAssertEqual(PracticeOptionText.state(index: 3, selectedIndex: 2, correctIndex: 1), .dimmed)
        // Answered correctly: only the key is highlighted.
        XCTAssertEqual(PracticeOptionText.state(index: 1, selectedIndex: 1, correctIndex: 1), .correct)
        XCTAssertEqual(PracticeOptionText.state(index: 0, selectedIndex: 1, correctIndex: 1), .dimmed)
    }
}
```

- [ ] **Step 2: Confirm it cannot compile, then implement `PracticeOptionText`**

```swift
// App/Sources/EnglishApp/Practice/PracticeOptionText.swift
import Foundation

/// How one answer option renders after an answer is committed. Every state
/// carries an icon and words as well as a colour — never colour alone
/// (spec "Screens and flow", rule 4).
enum PracticeOptionState: Equatable {
    /// Nothing answered yet.
    case idle
    /// The keyed option, once the answer is in.
    case correct
    /// The learner's pick, when it was wrong.
    case wrongPick
    /// Any other option, once the answer is in.
    case dimmed
}

enum PracticeOptionText {
    private static let letters = ["A", "B", "C", "D", "E"]

    static func letter(_ index: Int) -> String {
        guard index >= 0, index < letters.count else { return "\(index + 1)" }
        return letters[index]
    }

    static func state(index: Int, selectedIndex: Int?, correctIndex: Int) -> PracticeOptionState {
        guard let selectedIndex else { return .idle }
        if index == correctIndex { return .correct }
        if index == selectedIndex { return .wrongPick }
        return .dimmed
    }

    /// VoiceOver label, e.g. "A şıkkı: had already restructured, doğru cevap".
    static func accessibilityLabel(index: Int, text: String, state: PracticeOptionState) -> String {
        let base = "\(letter(index)) şıkkı: \(text)"
        switch state {
        case .idle, .dimmed: return base
        case .correct: return "\(base), doğru cevap"
        case .wrongPick: return "\(base), senin cevabın, yanlış"
        }
    }

    static func iconName(for state: PracticeOptionState) -> String? {
        switch state {
        case .idle, .dimmed: return nil
        case .correct: return "checkmark.circle.fill"
        case .wrongPick: return "xmark.circle.fill"
        }
    }
}
```

- [ ] **Step 3: Build the explanation screen**

```swift
// App/Sources/EnglishApp/Practice/PracticeExplanationView.swift
import SwiftUI
import LearningEngine

/// Step 1 of a grammar lesson: the Turkish rule card, then "Sorulara geç".
struct PracticeExplanationView: View {
    let title: String
    let skill: Skill
    let explanation: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SkillBadge(skill: skill)
                    Text(title)
                        .font(.serifTitle(.title))
                        .foregroundStyle(Theme.ink)
                    PaperCard {
                        Text(explanation)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Sorulara geç", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

#Preview("Explanation") {
    PracticeExplanationView(
        title: "Zamanlar (Tenses)",
        skill: .grammar,
        explanation: "YDS'de zaman soruları neredeyse her zaman cümledeki bir ZAMAN İŞARETİNE dayanır.\n\n• Past perfect (had + V3): geçmişteki iki olaydan önce olanı için.",
        onContinue: {}
    )
    .padding()
    .background(Theme.paper)
}
```

- [ ] **Step 4: Build the question + feedback screen**

```swift
// App/Sources/EnglishApp/Practice/PracticeQuestionView.swift
import SwiftUI
import LearningEngine

/// Steps 2-5: optional pinned passage, prompt, A-E options, and — once an
/// option is tapped — the feedback card with the Turkish explanation, the
/// optional "Öğretmene Sor" button and "Sonraki".
struct PracticeQuestionView: View {
    let question: PracticeSessionViewModel.QuestionVM
    let passage: PracticeSessionViewModel.PassageVM?
    let selectedIndex: Int?
    let skill: Skill
    let showsTutorButton: Bool
    let isLoadingTutor: Bool
    let onSelect: (Int) -> Void
    let onNext: () -> Void
    let onTutor: () -> Void

    @State private var isPassageExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnswered: Bool { selectedIndex != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let passage {
                        passagePanel(passage)
                    }
                    Text(question.prompt)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        optionRow(index: index, option: option)
                    }
                    if isAnswered {
                        feedbackCard
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isAnswered {
                Button("Sonraki", action: onNext).buttonStyle(PrimaryButtonStyle())
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedIndex)
    }

    @ViewBuilder
    private func passagePanel(_ passage: PracticeSessionViewModel.PassageVM) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isPassageExpanded.toggle()
                } label: {
                    HStack {
                        Text(passage.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: isPassageExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPassageExpanded ? "Metni gizle: \(passage.title)" : "Metni göster: \(passage.title)")
                if isPassageExpanded {
                    Text(passage.body)
                        .font(.callout)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func optionRow(index: Int, option: String) -> some View {
        let state = PracticeOptionText.state(index: index, selectedIndex: selectedIndex, correctIndex: question.correctIndex)
        Button {
            onSelect(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(PracticeOptionText.letter(index))
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(tint(for: state))
                Text(option)
                    .font(.subheadline)
                    .foregroundStyle(state == .dimmed ? Theme.secondaryInk : Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon = PracticeOptionText.iconName(for: state) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint(for: state))
                }
            }
            .padding(12)
            .background(background(for: state), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(state == .idle ? Theme.border : tint(for: state), lineWidth: state == .idle ? 1 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
        .accessibilityLabel(PracticeOptionText.accessibilityLabel(index: index, text: option, state: state))
    }

    private func tint(for state: PracticeOptionState) -> Color {
        switch state {
        case .idle: return skill.color
        case .correct: return Theme.primary
        case .wrongPick: return Theme.danger
        case .dimmed: return Theme.secondaryInk
        }
    }

    private func background(for state: PracticeOptionState) -> Color {
        switch state {
        case .idle: return Theme.surface
        case .correct: return Theme.primary.opacity(0.12)
        case .wrongPick: return Theme.danger.opacity(0.12)
        case .dimmed: return Theme.paper
        }
    }

    @ViewBuilder
    private var feedbackCard: some View {
        let wasCorrect = selectedIndex == question.correctIndex
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    wasCorrect ? "Doğru" : "Yanlış",
                    systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(wasCorrect ? Theme.primary : Theme.danger)
                Text(question.explanationTR)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                if showsTutorButton {
                    Button(action: onTutor) {
                        HStack(spacing: 6) {
                            if isLoadingTutor {
                                ProgressView().controlSize(.small).tint(Theme.primary)
                            } else {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                            }
                            Text("Öğretmene Sor")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingTutor)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build the summary screen**

```swift
// App/Sources/EnglishApp/Practice/PracticeSummaryView.swift
import SwiftUI

struct PracticeSummaryView: View {
    let title: String
    let summary: PracticeSessionViewModel.Summary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(.largeTitle).weight(.bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primary.opacity(0.15), in: Circle())
            Text("Oturum tamamlandı").font(.serifTitle(.title)).foregroundStyle(Theme.ink)
            Text(title).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 8) {
                StatTile(value: "\(summary.correctCount)/\(summary.total)", label: "doğru")
                StatTile(value: "%\(summary.percent)", label: "başarı", tint: Theme.primary)
            }
            .padding(.top, 8)
            if !summary.missedPrompts.isEmpty {
                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YANLIŞ YAPTIKLARIN")
                            .font(.caption2.weight(.semibold)).tracking(1)
                            .foregroundStyle(Theme.secondaryInk)
                        ForEach(Array(summary.missedPrompts.enumerated()), id: \.offset) { _, prompt in
                            Text(prompt)
                                .font(.footnote)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            if let nextReviewText = summary.nextReviewText {
                Text("Bu konuyu \(nextReviewText) sonra tekrar edeceğiz")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
            Button("Plana dön", action: onDone).buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Theme.paper.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: summary.total)
    }
}

#Preview("Practice summary") {
    PracticeSummaryView(
        title: "Zamanlar (Tenses)",
        summary: .init(
            correctCount: 6, total: 8, percent: 75,
            missedPrompts: ["By the time the central bank announced the new interest rate, most investors ---- their portfolios."],
            nextReviewText: "3 gün"
        ),
        onDone: {}
    )
}
```

- [ ] **Step 6: Build the container**

Tutor wiring is deliberately inert here (`showsTutorButton: false`); Task 8 fills it in.

```swift
// App/Sources/EnglishApp/Practice/PracticeSessionView.swift
import SwiftUI
import SwiftData
import LearningEngine

struct PracticeSessionView: View {
    let mode: PracticeSessionViewModel.Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var viewModel: PracticeSessionViewModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Oturum açılamadı", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .task { start() }
    }

    private func start() {
        guard viewModel == nil else { return }
        let vm = PracticeSessionViewModel(mode: mode, context: context, userID: UserIdentity.current)
        do {
            try vm.start()
            viewModel = vm
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func content(_ vm: PracticeSessionViewModel) -> some View {
        switch vm.step {
        case .loading:
            ProgressView()
        case .unavailable:
            ContentUnavailableView(
                "Bu ders henüz hazır değil",
                systemImage: "questionmark.folder",
                description: Text("İçerik güncellendiğinde burada görünecek.")
            )
            .overlay(alignment: .bottom) {
                Button("Plana dön", action: onClose).buttonStyle(PrimaryButtonStyle()).padding()
            }
        case .summary:
            PracticeSummaryView(title: vm.lessonTitle, summary: vm.summary(), onDone: onClose)
        case .explanation(let text):
            session(vm) {
                PracticeExplanationView(
                    title: vm.lessonTitle, skill: vm.skill, explanation: text,
                    onContinue: { vm.beginQuestions() }
                )
            }
        case .question:
            session(vm) {
                if let question = vm.current {
                    PracticeQuestionView(
                        question: question, passage: vm.passage, selectedIndex: vm.selectedIndex,
                        skill: vm.skill, showsTutorButton: false, isLoadingTutor: false,
                        onSelect: { vm.select($0) }, onNext: { vm.next() }, onTutor: {}
                    )
                }
            }
        }
    }

    /// Shared chrome: close button, progress bar, context line, error alert.
    @ViewBuilder
    private func session<Body: View>(_ vm: PracticeSessionViewModel, @ViewBuilder body: () -> Body) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.secondaryInk)
                }
                .accessibilityLabel("Kapat")
                ProgressBar(progress: vm.progress)
                Text(vm.progressText).font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
            }
            Text(vm.contextLine)
                .font(.caption2.weight(.semibold)).tracking(1.2)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            body()
        }
        .padding()
        .sensoryFeedback(.selection, trigger: vm.currentIndex)
        .alert(
            "Kaydedilemedi",
            isPresented: Binding(get: { vm.saveError != nil }, set: { if !$0 { vm.clearSaveError() } }),
            presenting: vm.saveError
        ) { _ in
            Button("Tekrar dene") { vm.retrySave() }
            Button("Kapat", role: .cancel) { vm.clearSaveError() }
        } message: { message in
            Text(message)
        }
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add App/Sources/EnglishApp/Practice App/Tests/EnglishAppTests/PracticeOptionTextTests.swift
git commit -m "$(cat <<'EOF'
Add practice session screens: explanation, question, feedback, summary

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`. `App Build` is the meaningful gate here: it is what proves the SwiftUI compiles for a real device.

---

## Task 8: Tutor question context and its screen integration

**Files:**
- Modify: `TutorEngine/Sources/TutorEngine/TutorRequest.swift`
- Create: `TutorEngine/Sources/TutorEngine/QuestionPromptBuilder.swift`
- Modify: `TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift`
- Test: `TutorEngine/Tests/TutorEngineTests/QuestionPromptBuilderTests.swift` (new)
- Modify: `App/Sources/EnglishApp/Tutor/TutorViewModel.swift`
- Modify: `App/Sources/EnglishApp/Tutor/TutorSheetView.swift`
- Modify: `App/Sources/EnglishApp/Practice/PracticeSessionView.swift`
- Modify: `App/Tests/EnglishAppTests/TutorViewModelTests.swift` (**fake engine must gain the new method**)
- Modify: `App/Tests/EnglishAppTests/ChatViewModelTests.swift` (**same**)

**Interfaces:**
- Consumes: Task 7's `PracticeQuestionView(showsTutorButton:isLoadingTutor:onTutor:)`.
- Produces: `QuestionTutorRequest(prompt:options:correctIndex:selectedIndex:explanationTR:ask:)`; `TutorEngine.respond(to question: QuestionTutorRequest) async throws -> String`; `QuestionPromptBuilder.build(for:)`; `TutorViewModel.Context` gaining a `.question(QuestionTutorRequest)` case.

> **Breaking-change warning.** Adding a method to the `TutorEngine` protocol breaks **both** existing test doubles: `FakeTutorEngine` in `App/Tests/EnglishAppTests/TutorViewModelTests.swift` and `FakeChatEngine` (plus the suspending engine defined further down the same file) in `App/Tests/EnglishAppTests/ChatViewModelTests.swift`. Update every one of them in this task's commit, or `App Build` goes red.

- [ ] **Step 1: Write the failing prompt-builder test**

```swift
// TutorEngine/Tests/TutorEngineTests/QuestionPromptBuilderTests.swift
import XCTest
@testable import TutorEngine

final class QuestionPromptBuilderTests: XCTestCase {
    let request = QuestionTutorRequest(
        prompt: "By the time the central bank announced the new interest rate, most investors ---- their portfolios.",
        options: [
            "have already restructured",
            "had already restructured",
            "already restructure",
            "are already restructuring",
            "will already restructure"
        ],
        correctIndex: 1,
        selectedIndex: 0,
        explanationTR: "«By the time» kalıbı past perfect ister.",
        ask: .quickAction(.simplerExplanation)
    )

    func test_promptCarriesTheQuestionOptionsKeyAndTheLearnersAnswer() {
        let prompt = QuestionPromptBuilder.build(for: request)
        XCTAssertTrue(prompt.contains("By the time the central bank announced"))
        XCTAssertTrue(prompt.contains("A) have already restructured"))
        XCTAssertTrue(prompt.contains("E) will already restructure"))
        XCTAssertTrue(prompt.contains("Correct answer: B) had already restructured"))
        XCTAssertTrue(prompt.contains("The learner chose: A) have already restructured"))
    }

    func test_anUnansweredQuestion_saysSo() {
        let unanswered = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
            selectedIndex: nil, explanationTR: request.explanationTR, ask: request.ask
        )
        let prompt = QuestionPromptBuilder.build(for: unanswered)
        XCTAssertTrue(prompt.contains("The learner has not answered yet."))
        XCTAssertFalse(prompt.contains("The learner chose:"))
    }

    func test_quickActions_produceDistinctInstructions() {
        func instruction(_ action: QuickAction) -> String {
            QuestionPromptBuilder.build(for: QuestionTutorRequest(
                prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
                selectedIndex: request.selectedIndex, explanationTR: request.explanationTR,
                ask: .quickAction(action)
            ))
        }
        XCTAssertTrue(instruction(.simplerExplanation).contains("Explain, in plain English"))
        XCTAssertTrue(instruction(.anotherExample).contains("Write one new example sentence"))
        XCTAssertTrue(instruction(.compareToSimilarWords).contains("why the option the learner chose is wrong"))
        XCTAssertNotEqual(instruction(.simplerExplanation), instruction(.anotherExample))
    }

    func test_freeTextQuestion_isQuotedIntoThePrompt() {
        let asked = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
            selectedIndex: request.selectedIndex, explanationTR: request.explanationTR,
            ask: .freeText("Why not present perfect?")
        )
        XCTAssertTrue(QuestionPromptBuilder.build(for: asked).contains("The learner asks: \"Why not present perfect?\""))
    }

    func test_promptIsDeterministic() {
        XCTAssertEqual(QuestionPromptBuilder.build(for: request), QuestionPromptBuilder.build(for: request))
    }
}
```

- [ ] **Step 2: Add the request type and the protocol method**

Append to `TutorEngine/Sources/TutorEngine/TutorRequest.swift`, and extend the protocol:

```swift
/// Everything needed to answer a tutor ask about one practice question: the
/// question as the learner saw it, the key, and which option they picked.
/// Like `TutorRequest`, it carries no conversation history.
public struct QuestionTutorRequest: Sendable, Equatable {
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    /// Nil if the learner opened the tutor before answering.
    public let selectedIndex: Int?
    /// The authored Turkish explanation, so the model does not contradict it.
    public let explanationTR: String
    public let ask: TutorAsk

    public init(
        prompt: String, options: [String], correctIndex: Int,
        selectedIndex: Int?, explanationTR: String, ask: TutorAsk
    ) {
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.selectedIndex = selectedIndex
        self.explanationTR = explanationTR
        self.ask = ask
    }
}
```

```swift
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
    func respond(to chat: ChatRequest) async throws -> String
    func respond(to question: QuestionTutorRequest) async throws -> String
}
```

- [ ] **Step 3: Implement the prompt builder**

```swift
// TutorEngine/Sources/TutorEngine/QuestionPromptBuilder.swift
import Foundation

/// Turns a `QuestionTutorRequest` into the text prompt sent to the model.
/// Pure and deterministic, like `PromptBuilder` — all wording iteration
/// happens here, with no model-loading code involved.
public enum QuestionPromptBuilder {
    private static func letter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return index >= 0 && index < letters.count ? letters[index] : "\(index + 1)"
    }

    private static func labelled(_ options: [String], _ index: Int) -> String {
        guard index >= 0, index < options.count else { return "-" }
        return "\(letter(index)) \(options[index])"
    }

    public static func build(for request: QuestionTutorRequest) -> String {
        let optionLines = request.options.enumerated()
            .map { "\(letter($0.offset)) \($0.element)" }
            .joined(separator: "\n")

        var prompt = """
        You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam.
        The learner is working on this multiple-choice question:

        Question: \(request.prompt)
        \(optionLines)

        Correct answer: \(labelled(request.options, request.correctIndex))

        """

        if let selectedIndex = request.selectedIndex {
            prompt += "The learner chose: \(labelled(request.options, selectedIndex))\n"
        } else {
            prompt += "The learner has not answered yet.\n"
        }

        prompt += """
        The explanation the app already showed (in Turkish): \(request.explanationTR)


        """

        switch request.ask {
        case .quickAction(.simplerExplanation):
            prompt += "Explain, in plain English and in 2-3 short sentences, why the correct answer is right. Do not contradict the explanation above."
        case .quickAction(.anotherExample):
            prompt += "Write one new example sentence that uses the same grammar point or vocabulary as the correct answer, then translate it into Turkish."
        case .quickAction(.compareToSimilarWords):
            prompt += "Explain briefly why the option the learner chose is wrong and how it differs from the correct answer. Keep it to 2-3 short sentences."
        case .freeText(let question):
            prompt += "The learner asks: \"\(question)\". Answer clearly and briefly, staying focused on this question and why its answer is what it is."
        }

        return prompt
    }
}
```

In `TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift`, add the third `respond` overload next to the existing `respond(to request: TutorRequest)`, reusing whatever single-prompt generation path that one already uses — same generation call, with `QuestionPromptBuilder.build(for: question)` as the prompt string instead of `PromptBuilder.build(for: request)`.

- [ ] **Step 4: Widen `TutorViewModel` to carry either context**

Replace `TutorViewModel.TutorContext` usage with an enum, keeping the existing card case so `StudySessionView` is untouched:

```swift
    enum Context {
        case card(TutorContext)
        case question(prompt: String, options: [String], correctIndex: Int, selectedIndex: Int?, explanationTR: String)
    }

    struct TutorContext {
        let headword: String
        let definition: String
        let exampleSentences: [String]
        let translationTR: String
    }
```

Change the stored `context` to `Context`, add a convenience initializer so existing call sites keep compiling:

```swift
    init(engine: any TutorEngine, context: TutorContext, timeoutSeconds: UInt64 = 30) {
        self.init(engine: engine, context: .card(context), timeoutSeconds: timeoutSeconds)
    }

    init(engine: any TutorEngine, context: Context, timeoutSeconds: UInt64 = 30) {
        self.engine = engine
        self.context = context
        self.timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }
```

and route `send(_:)` through the right request type, keeping the existing timeout wrapper by making it generic over the work:

```swift
    private func send(_ ask: TutorAsk) async {
        state = .loading
        do {
            let response: String
            switch context {
            case .card(let card):
                let request = TutorRequest(
                    headword: card.headword, definition: card.definition,
                    exampleSentences: card.exampleSentences, translationTR: card.translationTR, ask: ask
                )
                response = try await withTimeout { try await self.engine.respond(to: request) }
            case .question(let prompt, let options, let correctIndex, let selectedIndex, let explanationTR):
                let request = QuestionTutorRequest(
                    prompt: prompt, options: options, correctIndex: correctIndex,
                    selectedIndex: selectedIndex, explanationTR: explanationTR, ask: ask
                )
                response = try await withTimeout { try await self.engine.respond(to: request) }
            }
            state = .response(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    private func withTimeout(_ work: @escaping @Sendable () async throws -> String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: self.timeoutNanoseconds)
                throw TutorTimeoutError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw TutorTimeoutError()
            }
            return result
        }
    }
```

(Delete the now-unused `respondWithTimeout(to:)`.)

In `TutorSheetView`, add a second initializer taking `TutorViewModel.Context`, and make the three quick-action button titles context-aware so a question sheet does not offer "Benzer kelimelerden farkı ne?":

```swift
    init(engine: any TutorEngine, context: TutorViewModel.TutorContext) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: context))
        _isQuestionContext = State(initialValue: false)
    }

    init(engine: any TutorEngine, questionContext: TutorViewModel.Context) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: questionContext))
        _isQuestionContext = State(initialValue: true)
    }
```

with `@State private var isQuestionContext: Bool` and:

```swift
    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickAction(isQuestionContext ? "Neden bu cevap?" : "Daha basit anlat") { await viewModel.ask(.simplerExplanation) }
            quickAction(isQuestionContext ? "Benzer bir örnek ver" : "Başka bir örnek ver") { await viewModel.ask(.anotherExample) }
            quickAction(isQuestionContext ? "Benim cevabım neden yanlış?" : "Benzer kelimelerden farkı ne?") { await viewModel.ask(.compareToSimilarWords) }
        }
    }
```

and change the free-text placeholder to `isQuestionContext ? "Bu soru hakkında bir şey sor..." : "Bu kelime hakkında bir şey sor..."`.

- [ ] **Step 5: Update both fake engines**

In `App/Tests/EnglishAppTests/TutorViewModelTests.swift`, add to `FakeTutorEngine`:

```swift
    private(set) var lastQuestionRequest: QuestionTutorRequest?

    func respond(to question: QuestionTutorRequest) async throws -> String {
        lastQuestionRequest = question
        if let stubbedError { throw stubbedError }
        return stubbedResponse
    }
```

and add a test that actually exercises the new path:

```swift
    func test_questionContext_sendsAQuestionRequestCarryingTheLearnersAnswer() async {
        let engine = FakeTutorEngine()
        engine.stubbedResponse = "Past perfect is needed here."
        let viewModel = TutorViewModel(engine: engine, context: .question(
            prompt: "By the time the bank announced the rate, investors ---- their portfolios.",
            options: ["a", "b", "c", "d", "e"], correctIndex: 1, selectedIndex: 3,
            explanationTR: "«By the time» past perfect ister."
        ))

        await viewModel.ask(.compareToSimilarWords)

        XCTAssertEqual(viewModel.state, .response("Past perfect is needed here."))
        XCTAssertEqual(engine.lastQuestionRequest?.correctIndex, 1)
        XCTAssertEqual(engine.lastQuestionRequest?.selectedIndex, 3)
        XCTAssertEqual(engine.lastQuestionRequest?.ask, .quickAction(.compareToSimilarWords))
        XCTAssertNil(engine.lastRequest, "a question context must not send a card TutorRequest")
    }
```

In `App/Tests/EnglishAppTests/ChatViewModelTests.swift`, add to `FakeChatEngine` **and to the suspending engine defined lower in the same file**:

```swift
    func respond(to question: QuestionTutorRequest) async throws -> String {
        fatalError("not used by ChatViewModelTests")
    }
```

- [ ] **Step 6: Wire the button into `PracticeSessionView`**

Add state and the sheet, mirroring `StudySessionView`'s single-flight tutor load:

```swift
    @State private var isLoadingTutor = false
    @State private var showTutorSheet = false
```

replace the `.question` branch's `PracticeQuestionView(...)` call with:

```swift
                if let question = vm.current {
                    PracticeQuestionView(
                        question: question, passage: vm.passage, selectedIndex: vm.selectedIndex,
                        skill: vm.skill,
                        showsTutorButton: appState.isTutorAvailable,
                        isLoadingTutor: isLoadingTutor,
                        onSelect: { vm.select($0) },
                        onNext: { vm.next() },
                        onTutor: { Task { await openTutor() } }
                    )
                    .sheet(isPresented: $showTutorSheet) {
                        if let engine = appState.tutorEngine {
                            TutorSheetView(engine: engine, questionContext: .question(
                                prompt: question.prompt, options: question.options,
                                correctIndex: question.correctIndex, selectedIndex: vm.selectedIndex,
                                explanationTR: question.explanationTR
                            ))
                        }
                    }
                }
```

and add the loader:

```swift
    /// Same single-flight rule as StudySessionView: AppState dedupes
    /// concurrent loads, and a nil engine means "not available", never an
    /// error shown to the learner.
    private func openTutor() async {
        guard !isLoadingTutor else { return }
        if appState.tutorEngine == nil {
            isLoadingTutor = true
            await appState.loadTutorEngineIfNeeded()
            isLoadingTutor = false
        }
        if appState.tutorEngine != nil { showTutorSheet = true }
    }
```

Because `AppState.isTutorAvailable` is `false` on the Simulator, this button simply never renders in CI — which is exactly the intended behaviour when the tutor is unavailable (spec "Error handling").

- [ ] **Step 7: Commit**

```bash
git add TutorEngine App/Sources App/Tests
git commit -m "$(cat <<'EOF'
Add tutor question context, prompt builder and the Öğretmene Sor button

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Push and confirm both CI workflows green**

`scripts/ci-test.sh` (which also runs `swift test` in `TutorEngine`), then `scripts/ci-app-build.sh`.

---

## Task 9: Wire Bugün and Ders Yolu, and clear the residue

**Files:**
- Modify: `App/Sources/EnglishApp/Today/TodayPlanView.swift`
- Modify: `App/Sources/EnglishApp/CoursePath/CoursePathView.swift`
- Test: `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift` (extend)
- Test: `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift` (extend)

**Interfaces:**
- Consumes: `PracticeSessionView(mode:onClose:)` (Task 7), `PlanTaskAction.startPractice(lessonID:)` / `.startPracticeReview(itemID:lessonID:)` (Task 5).
- Produces: nothing new. This task makes the feature reachable and removes the temporary `case .startPractice, .startPracticeReview: break` placeholders Task 5 introduced.

`ContentSeederTests`, `StudySessionViewModelTests` and `CoursePathViewModelTests` all build their store from the synthetic `TestPackageJSON` (vocabulary only), so none of them are affected by the shipped practice content. Only tests that seed the **real** package need new expectations.

- [ ] **Step 1: Write the failing end-to-end routing tests**

Add to `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`:

```swift
    func makeRealContentContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    func test_dersYolu_showsThePracticeLessonsInTheFreePreviewUnit_andRoutesThemToPractice() throws {
        let context = try makeRealContentContext()
        let viewModel = CoursePathViewModel(
            context: context, userID: "u", accessProvider: FixedAccessProvider(level: .preview)
        )
        viewModel.load()

        let firstSection = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(firstSection.tasks.count, 10)
        let actions = firstSection.tasks.map(PlanTaskAction.action(for:))
        XCTAssertEqual(actions.prefix(3).filter { if case .startLesson = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(
            actions.dropFirst(3).filter { if case .startPractice = $0 { return true } else { return false } }.count, 7,
            "all seven practice lessons must be openable, not locked or 'coming soon'"
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: firstSection.tasks[3]),
            .startPractice(lessonID: "yds-practice-lesson-tenses")
        )
    }

    func test_lockedUnits_stillShowPaketiAc() throws {
        let context = try makeRealContentContext()
        let viewModel = CoursePathViewModel(
            context: context, userID: "u", accessProvider: FixedAccessProvider(level: .preview)
        )
        viewModel.load()

        let secondSection = try XCTUnwrap(viewModel.sections.dropFirst().first)
        XCTAssertTrue(secondSection.tasks.allSatisfy { if case .locked = $0 { return true } else { return false } })
    }
```

Add to `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift`:

```swift
    func test_bugun_schedulesAPracticeLessonOnceGrammarIsBehindItsWeeklyTarget() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()

        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        let actions = plan.tasks.map(PlanTaskAction.action(for:))
        XCTAssertTrue(
            actions.contains { if case .startPractice = $0 { return true } else { return false } },
            "with grammar and reading weighted at 30/35, the first plan must include a practice lesson"
        )
        XCTAssertFalse(
            actions.contains { if case .comingSoon = $0 { return true } else { return false } },
            "no shipped lesson may still route to 'coming soon'"
        )
    }
```

- [ ] **Step 2: Wire `TodayPlanView`**

Replace the `ActiveSession` helper and the `fullScreenCover`/`handle` pieces:

```swift
    private struct ActiveSession: Identifiable {
        enum Kind {
            case study(StudySessionViewModel.Mode)
            case practice(PracticeSessionViewModel.Mode)
        }
        let id = UUID()
        let kind: Kind
    }
```

```swift
        .fullScreenCover(item: $activeSession) { session in
            switch session.kind {
            case .study(let mode):
                StudySessionView(mode: mode) {
                    activeSession = nil
                    refresh()
                }
            case .practice(let mode):
                PracticeSessionView(mode: mode) {
                    activeSession = nil
                    refresh()
                }
            }
        }
```

```swift
    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startReview(let count):
            activeSession = ActiveSession(kind: .study(.review(cardCount: count)))
        case .startLesson(let id):
            activeSession = ActiveSession(kind: .study(.lesson(id: id)))
        case .startPractice(let lessonID):
            activeSession = ActiveSession(kind: .practice(.lesson(id: lessonID)))
        case .startPracticeReview(let itemID, let lessonID):
            activeSession = ActiveSession(kind: .practice(.review(lessonID: lessonID, itemID: itemID)))
        case .comingSoon(let title):
            infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title):
            infoMessage = ("Bu ders paketin tam sürümünde", title)
        case .none:
            break
        }
    }
```

- [ ] **Step 3: Wire `CoursePathView`**

```swift
    private struct ActiveSession: Identifiable {
        enum Kind {
            case study(lessonID: String)
            case practice(lessonID: String)
        }
        let id = UUID()
        let kind: Kind
    }
```

```swift
        .fullScreenCover(item: $activeSession) { session in
            switch session.kind {
            case .study(let lessonID):
                StudySessionView(mode: .lesson(id: lessonID)) {
                    activeSession = nil
                    refresh()
                }
            case .practice(let lessonID):
                PracticeSessionView(mode: .lesson(id: lessonID)) {
                    activeSession = nil
                    refresh()
                }
            }
        }
```

```swift
    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startLesson(let id):
            activeSession = ActiveSession(kind: .study(lessonID: id))
        case .startPractice(let lessonID):
            activeSession = ActiveSession(kind: .practice(lessonID: lessonID))
        case .comingSoon(let title):
            infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title):
            infoMessage = ("Bu ders paketin tam sürümünde", title)
        // Ders Yolu never shows review tasks, so these cannot occur here.
        case .startReview, .startPracticeReview, .none:
            break
        }
    }
```

Rename the existing `@State private var activeSession: ActiveLessonSession?` to `ActiveSession?` in both files and delete the old `ActiveLessonSession` struct.

- [ ] **Step 4: Sweep the residue**

Confirm all of the following are true before committing; each is a one-line grep:

- `grep -rn "case .startPractice, .startPracticeReview: break" App/Sources` returns nothing (the Task 5 placeholders are gone).
- `grep -rn "comingSoon" App/Sources` shows it only in `PlanTaskAction.swift`, `TodayPlanView.swift` and `CoursePathView.swift`, and only for skills with no content.
- `grep -rn "ActiveLessonSession" App/Sources` returns nothing.
- `grep -rn "forItemType" App/Sources LearningEngine/Sources` shows it only inside `Skill.swift` (as the fallback of `forItem`) — every call site now goes through `Skill.forItem(type:lessonSkill:)`.
- `App/Sources/EnglishApp/Resources/Localizable.xcstrings` is **unchanged** in `git diff` (per the Global Constraints, Turkish copy stays as inline literals).
- Every new Turkish string added across Tasks 5-9 uses informal "sen": scan the diff for any "-iniz"/"-ınız" formal endings and rewrite them.

- [ ] **Step 5: Commit**

```bash
git add App/Sources App/Tests
git commit -m "$(cat <<'EOF'
Open practice lessons and practice reviews from Bugün and Ders Yolu

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

`scripts/ci-test.sh`, then `scripts/ci-app-build.sh`.

- [ ] **Step 7: Record what CI cannot prove**

Add these to the branch's hand-off notes (they are the slice's known verification gaps, all called out by the spec):

1. **Real-device lightweight migration.** An existing install must open with the new entities (`Question`, `Passage`, `QuestionAttempt`) and the new `ItemContent.explanationTR` without losing data. CI always starts from a fresh store, so this is a TestFlight check: install the previous build, study a vocabulary lesson, upgrade, and confirm the streak, `wordsSeen` and due counts survive and that Profil shows no storage warning.
2. **Every screen.** No UI tests exist. Walk both grammar topics, both reading lessons, the cloze, sentence-completion and translation sets on device in light and dark mode, at the largest Dynamic Type size, with Reduce Motion on and with VoiceOver on (confirm the "A şıkkı: …" labels and that correctness is announced in words).
3. **The tutor button.** `AppState.isTutorAvailable` is false on the Simulator, so "Öğretmene Sor" is only reachable on a real device.

---

## Self-review

Run against the spec after the plan is written; findings are fixed inline.

**Spec coverage**

| Spec section | Covered by |
|---|---|
| Data model — `Question`, `Passage`, `QuestionAttempt` | Task 1 |
| `ItemContent.explanationTR`, `LearningItemType.practiceSet` | Task 1 |
| Skill attribution from the owning lesson, `forItemType` as fallback | Task 1 (`Skill.forItem`), applied in Task 5 |
| Content format v3+, importer validation (6 rules) | Task 1 (8 errors: the spec's 6 plus `invalidQuestionKind` and `missingPracticeCard`) |
| Validate-into-a-temporary-store update path | Task 1, Step 7 (`ContentSeeder` scratch schema) |
| Sample content, ~60-70 questions | Task 2 (63) |
| Independent content review | Task 3 |
| Score-to-rating with 50/75/100 boundaries | Task 4 (`PracticeScoring`) |
| Question selection priority + determinism | Task 4 (`PracticeQuestionSelector`, `SeededGenerator`) |
| Pool smaller than selection size | Task 4 `test_poolSmallerThanTheRequestedSize_returnsEverything`, Task 6 `test_poolSmallerThanTheSelectionSize_asksEveryQuestion` |
| `DailyPlanBuilder` `practiceReview`, cap 2, ordering, budget | Task 5 |
| `PlanTaskAction` routing, `.comingSoon` only for contentless skills | Task 5 |
| Access policy unchanged | Task 2 (content placement), Task 9 `test_lockedUnits_stillShowPaketiAc` |
| `PracticeSessionViewModel` | Task 6 |
| Screens: explanation, pinned passage, progress, A-E, feedback, summary | Task 7 |
| Recording rules (attempt immediate, completion at summary) | Task 6 contract table + tests |
| Save-failure handling, "Tekrar dene", no half-complete state | Task 6 `test_saveFailureOnFinish_...`, Task 7 alert |
| Tutor question context + prompt builder with tests | Task 8 |
| Tutor hidden when unavailable | Task 8 (`showsTutorButton: appState.isTutorAvailable`) |
| Routing from Bugün / Ders Yolu | Task 9 |
| Turkish strings, Dynamic Type, Reduce Motion, VoiceOver, no colour-only | Global Constraints, Tasks 7 and 9 |
| Known gaps (no UI tests, device migration) | Task 9, Step 7 |

**Rulings made where the spec was silent or stale** — each is flagged again in the hand-off:

1. **Package version.** The spec says "version becomes 3", but `PACKAGE_VERSION` is *already* 3 on `master` and `RealContentSeedingTests` asserts it. Leaving it at 3 would mean installed apps never re-import and never see the practice content. Ruled: **version 4**.
2. **Where the practice lessons live.** The spec does not say. Ruled: appended to the existing first unit, for the free-preview reasons argued in Task 2.
3. **Skills for cloze / sentence completion / translation.** Not in the spec and there is no exam-technique skill. Ruled: cloze and translation → `reading`, sentence completion → `grammar`.
4. **`practiceReview` carries `isDone` and `lessonID`.** The spec's signature is `practiceReview(itemID, title, skill, minutes: 3)`. `isDone` is needed because every other `PlanTask` has it and `DailyPlan.isComplete` depends on it; `lessonID` is needed because the practice session is driven by the lesson, and re-deriving it from the item in the view layer would push a SwiftData fetch into the routing code.
5. **Within-tier ordering.** The spec's "then most recently answered wrong, then attempted-correctly, least recently attempted first" is ambiguous. Ruled: the tier order is never-attempted → last-wrong → last-correct, and **within every tier** the least recently attempted comes first.
6. **A practice-set lesson needs exactly one card item.** The spec only forbids "a practice skill but no questions". Without an explicit card the FSRS invariant is unenforceable, so `missingPracticeCard` was added as an eighth rule.
7. **The explanation card is shown in review mode too**, not only on a first pass — re-reading the rule before a topic review is the point of a topic review.
8. **`Localizable.xcstrings` is left untouched.** The catalog is empty and `sourceLanguage` is `tr`; Xcode extracts the inline literals. Hand-adding entries would diverge from every existing screen.

**Placeholder scan:** no "TBD", no "similar to Task N", no "add error handling" — every code step carries the code. The one deliberate content deferral is Task 2 Step 1's remaining 57 questions, which is an authoring instruction with a fixed inventory, seven binding quality rules, six worked exemplars and a machine-checked schema, plus a separate review gate in Task 3.

**Type consistency:** `PracticeScoring.selectionSize(poolCount:skill:)`, `PracticeQuestionSelector.select(from:size:using:)`, `QuestionCandidate(id:order:lastAttemptedAt:lastWasCorrect:)`, `SeededGenerator(seed:)`, `DuePracticeCard(itemID:lessonID:title:skill:dueDate:isDone:)`, `PlanTask.practiceReview(itemID:lessonID:title:skill:minutes:isDone:)`, `PlanTaskAction.startPractice(lessonID:)` / `.startPracticeReview(itemID:lessonID:)`, `PracticeSessionViewModel.Mode.review(lessonID:itemID:)`, `QuestionTutorRequest(prompt:options:correctIndex:selectedIndex:explanationTR:ask:)` are spelled identically everywhere they appear across Tasks 4-9.
