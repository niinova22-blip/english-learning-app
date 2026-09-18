# Slice 6a — Design System + Goal Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the app from a single flashcard queue into a goal-driven daily plan (skill weights, lessons, preview access, streak) with a redesigned, Turkish, "academic and focused" UI.

**Architecture:** Pure, SwiftData-free planning logic (`SkillWeights`, `LessonAccessPolicy`, `StreakCalculator`, `DailyPlanBuilder`) lives in the `LearningEngine` package and is unit-tested there. The app target adds learner-side SwiftData models, a coordinator that snapshots SwiftData into plan inputs, a study-session view model, a design-system folder, and the new screens. Skill weights live in the content JSON.

**Tech Stack:** Swift 5.10, SwiftUI + SwiftData (iOS 17.0), XCTest, XcodeGen 2.46, Python 3 (content assembly), GitHub Actions macOS CI.

**Spec:** `docs/superpowers/specs/2026-09-14-design-system-goal-engine-design.md`

## Global Constraints

- iOS deployment target `17.0`, `SWIFT_VERSION` `5.10`, LearningEngine `swift-tools-version: 5.10`. No new third-party dependencies.
- **This Windows machine has NO Swift toolchain and no Xcode.** Never run `swift build`, `swift test` or `xcodebuild` locally. Verification is only via CI: `bash scripts/ci-test.sh` (LearningEngine + TutorEngine `swift test`, plus the content drift check) and `bash scripts/ci-app-build.sh` (Xcode build + `EnglishAppTests`). Both need a clean, committed tree; they push and watch the run. If the watch detaches, poll `"C:/Program Files/GitHub CLI/gh.exe" run list --limit 5 --json databaseId,workflowName,headSha,status,conclusion` until the run for your commit is `completed`. Never report done while CI is running.
- "Run test to verify it fails" steps are satisfied by reasoning (no local toolchain); do NOT push a deliberately failing commit. Push once per task after the implementation, and fix with new commits if CI fails.
- Tests use XCTest (`final class …: XCTestCase`), in-memory `ModelContainer`s, and never `Task.sleep`.
- Python is available locally: `python scripts/assemble-content.py`.
- Every commit message ends with a blank line and then:
  `Co-Authored-By: Claude <noreply@anthropic.com>` (use the implementer model's own name) and `Claude-Session: https://claude.ai/code/session_01NUxuqD7b3LJadTK7NyMRYW`. Never amend or force-push. Never bare `git stash`. Never `git clean -fdx`.
- The 7 skills, exactly and in this order: `vocabulary, grammar, reading, listening, writing, speaking, pronunciation`.
- Item type → skill: `vocabulary`, `phrase`, `collocation` → `.vocabulary`; `grammarPoint` → `.grammar`.
- Plan constants: `minutesPerReviewCard = 0.4`, `maxReviewShareOfBudget = 0.5`, default `dailyMinutes = 20`.
- Preview access = only lessons of the unit with the lowest `order`. Dev toggle UserDefaults key: `dev.unlockAllPackages` (default `false`).
- All user-facing copy is Turkish. Rating labels exactly: `Bilemedim`, `Zorlandım`, `Bildim`, `Çok kolay` (for `.again`, `.hard`, `.good`, `.easy`). One-time hint key: `hint.ratingExplained`; hint text: `Kelimeyi ne kadar iyi bildiğini seç. Uygulama bir sonraki tekrar zamanını buna göre ayarlar.`
- Rating intervals are computed with `FSRSScheduler.review` without persisting. This engine's minimum interval is 1 day (`FSRSScheduler.nextIntervalDays` clamps to ≥ 1), so labels are day-based: `1 gün`, `4 gün`, `2 ay`, `1 yıl` (spec amendment — the mockup's minute values are not produced by this engine; no in-session relearning in 6a).
- Colors (light / dark): paper `#FBF8F2`/`#151A1C`, surface `#FFFFFF`/`#1E2527`, border `#E7E1D6`/`#2E3739`, ink `#1F2A2E`/`#EEF2F1`, secondaryInk `#6B7280`/`#9CA3AF`, primary `#0F766E`/`#2DD4BF`, accent `#EA580C`/`#FB923C`, danger `#B91C1C`/`#F87171`. Skill colors: vocabulary = primary, grammar = accent, reading `#3B82F6`, listening `#7C3AED`, writing `#0891B2`, speaking `#DB2777`, pronunciation `#65A30D`.
- Titles use `.system(<textStyle>, design: .serif)`; no fixed point sizes, no bundled fonts.
- Bundled YDS package: `version` `2`, weights `vocabulary 35, grammar 30, reading 35, listening 0, writing 0, speaking 0, pronunciation 0`; lesson title format `"<unit theme> · <lesson order + 1>"`; every existing lesson `"skill": "vocabulary"`.

## File Map

| File | Responsibility | Task |
|---|---|---|
| `LearningEngine/Sources/LearningEngine/Models/Skill.swift` | `Skill`, `SkillWeights`, item-type mapping | 1 |
| `LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift`, `Lesson.swift` | new stored fields | 1 |
| `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`, `ContentImporter.swift` | new document fields + validation | 1 |
| `scripts/assemble-content.py` + both `YDSAcademicVocabulary1.json` copies | content version/weights/titles/skills | 2 |
| `LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift`, `LessonProgress.swift` | learner-side SwiftData models | 3 |
| `LearningEngine/Sources/LearningEngine/Planning/PlanTypes.swift` | value snapshots shared by planning code | 3 |
| `LearningEngine/Sources/LearningEngine/Planning/LessonAccessPolicy.swift`, `StreakCalculator.swift` | access rule, streak | 3 |
| `LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift` | daily plan | 4 |
| `App/Sources/EnglishApp/AppModelContainer.swift`, `ContentSeeder.swift` | schema + versioned seeding | 5 |
| `App/Sources/EnglishApp/Access/PackageAccessProvider.swift` | entitlement interface + dev impl | 5 |
| `App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift` | SwiftData → plan input, profile repair, streak, stats | 5 |
| `App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift` | review-only candidates | 5 |
| `App/Sources/EnglishApp/DesignSystem/*` | tokens + components | 6 |
| `App/Sources/EnglishApp/Study/StudySessionViewModel.swift`, `RatingIntervalFormatter.swift` | session logic | 7 |
| `App/Sources/EnglishApp/Study/StudySessionView.swift`, `StudyCardView.swift`, `StudySummaryView.swift` | session UI | 8 |
| `App/Sources/EnglishApp/Today/TodayPlanView.swift`, `Today/PlanTaskAction.swift`, `Profile/ProfileView.swift`, `RootTabView.swift`, `Resources/Localizable.xcstrings`, `project.yml`; deletes `Today/TodayView.swift`, `Today/SessionSummaryView.swift`, `Settings/SettingsView.swift` | home, profile, tabs, localization | 9 |
| `App/Sources/EnglishApp/Tutor/TutorChatView.swift`, `TutorSheetView.swift`, `TutorTabView.swift` | restyle + Turkish copy | 10 |

---

### Task 1: Skill weights in the content model and importer

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Models/Skill.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Models/Lesson.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentImporter.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/SkillWeightsTests.swift`
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift` (add the new required fields to every inline JSON package; add new tests)

**Interfaces:**
- Produces: `public enum Skill: String, Codable, CaseIterable, Sendable`; `Skill.forItemType(_ type: LearningItemType) -> Skill`; `public struct SkillWeights: Sendable, Equatable` with `init(_ values: [Skill: Double]) throws`, `static let vocabularyOnly`, `func weight(of:) -> Double`, `func share(of:) -> Double`, `var activeSkills: [Skill]`; `SkillWeightsError`; `ContentPackage.version: Int`, `ContentPackage.skillWeights: SkillWeights` (computed); `Lesson.title: String`, `Lesson.skill: Skill`; `ContentImportError.invalidSkillWeights(String)`, `.invalidSkill(String)`, `.invalidVersion(Int)`.

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/SkillWeightsTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class SkillWeightsTests: XCTestCase {
    private func full(_ overrides: [Skill: Double] = [:]) -> [Skill: Double] {
        var values = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 0.0) })
        values[.vocabulary] = 1
        for (k, v) in overrides { values[k] = v }
        return values
    }

    func test_skillOrder_isExactlyTheSevenSkills() {
        XCTAssertEqual(Skill.allCases.map(\.rawValue),
                       ["vocabulary", "grammar", "reading", "listening", "writing", "speaking", "pronunciation"])
    }

    func test_itemTypeMapping() {
        XCTAssertEqual(Skill.forItemType(.vocabulary), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.phrase), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.collocation), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.grammarPoint), .grammar)
    }

    func test_shares_areNormalized_andActiveSkillsExcludeZero() throws {
        let weights = try SkillWeights(full([.vocabulary: 35, .grammar: 30, .reading: 35]))
        XCTAssertEqual(weights.share(of: .vocabulary), 0.35, accuracy: 1e-9)
        XCTAssertEqual(weights.share(of: .grammar), 0.30, accuracy: 1e-9)
        XCTAssertEqual(weights.share(of: .pronunciation), 0, accuracy: 1e-9)
        XCTAssertEqual(weights.activeSkills, [.vocabulary, .grammar, .reading])
    }

    func test_init_missingSkill_throws() {
        var values = full()
        values.removeValue(forKey: .speaking)
        XCTAssertThrowsError(try SkillWeights(values)) { error in
            XCTAssertEqual(error as? SkillWeightsError, .missingSkill(.speaking))
        }
    }

    func test_init_negativeWeight_throws() {
        XCTAssertThrowsError(try SkillWeights(full([.grammar: -1]))) { error in
            XCTAssertEqual(error as? SkillWeightsError, .negativeWeight(.grammar))
        }
    }

    func test_init_allZero_throws() {
        XCTAssertThrowsError(try SkillWeights(full([.vocabulary: 0]))) { error in
            XCTAssertEqual(error as? SkillWeightsError, .zeroTotal)
        }
    }

    func test_vocabularyOnly_isOnlyVocabulary() {
        XCTAssertEqual(SkillWeights.vocabularyOnly.activeSkills, [.vocabulary])
    }
}
```

Append to `ContentImporterTests` (inside the class). First, add this helper at the top of the class and use it to build every JSON package in the file, replacing the existing inline literals' package header so that each package includes `"version": 1` and `"skillWeights"`, and each lesson includes `"title"` and `"skill"`:

```swift
    /// Builds a minimal valid package JSON. `lessonExtra`/`packageExtra` let
    /// individual tests break exactly one field.
    func packageJSON(
        version: String = "1",
        skillWeights: String = #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#,
        lessonSkill: String = "vocabulary",
        goal: String = "yds",
        itemType: String = "vocabulary"
    ) -> Data {
        """
        {
          "id": "test-package", "name": "Test Package", "goal": "\(goal)",
          "levelLower": "B2", "levelUpper": "C1",
          "version": \(version),
          "skillWeights": \(skillWeights),
          "units": [
            { "id": "test-unit-1", "theme": "Test Theme", "order": 0,
              "lessons": [
                { "id": "test-lesson-1", "order": 0, "estimatedDurationMinutes": 5,
                  "title": "Test Theme · 1", "skill": "\(lessonSkill)",
                  "items": [
                    { "id": "test-item-economy", "type": "\(itemType)", "headword": "economy",
                      "frequencyRank": 100, "baseDifficulty": 0.3,
                      "definition": "the system of production and trade",
                      "exampleSentences": ["The economy grew."],
                      "translationTR": "ekonomi", "collocations": ["global economy"] }
                  ] }
              ] }
          ]
        }
        """.data(using: .utf8)!
    }

    func makeFullInMemoryContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_importPackage_storesVersionWeightsTitleAndSkill() throws {
        let context = try makeFullInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: packageJSON(version: "2", skillWeights: #"{"vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)
        try context.save()

        XCTAssertEqual(package.version, 2)
        XCTAssertEqual(package.skillWeights.share(of: .reading), 0.35, accuracy: 1e-9)
        let lesson = package.units[0].lessons[0]
        XCTAssertEqual(lesson.title, "Test Theme · 1")
        XCTAssertEqual(lesson.skill, .vocabulary)
    }

    func test_importPackage_missingSkillInWeights_throwsAndInsertsNothing() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("missing pronunciation"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_unknownSkillKeyInWeights_throws() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0, "dancing": 1}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("unknown dancing"))
        }
    }

    func test_importPackage_negativeWeight_throws() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 1, "grammar": -2, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("negative grammar"))
        }
    }

    func test_importPackage_zeroTotalWeights_throws() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(
            from: packageJSON(skillWeights: #"{"vocabulary": 0, "grammar": 0, "reading": 0, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0}"#),
            into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkillWeights("zero total"))
        }
    }

    func test_importPackage_invalidLessonSkill_throwsAndInsertsNothing() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: packageJSON(lessonSkill: "juggling"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidSkill("juggling"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 0)
    }

    func test_importPackage_versionBelowOne_throws() throws {
        let context = try makeFullInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: packageJSON(version: "0"), into: context)) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidVersion(0))
        }
    }
```

For every pre-existing test in `ContentImporterTests.swift` that decodes an inline JSON literal: add `"version": 1,` and the vocabulary-only `"skillWeights"` object shown in `packageJSON`'s default to the package object, and `"title": "<anything>", "skill": "vocabulary",` to every lesson object. Do not change what those tests assert. The fixture-based test (`YDSAcademicVocabulary1.json`) keeps working after Task 2 regenerates the fixture; in this task it will fail decoding, so Task 1 and Task 2 are pushed together (see Step 5).

- [ ] **Step 2: Verify the tests would fail**

Reason through it: `Skill`, `SkillWeights`, `ContentPackage.version`, `Lesson.title`, and the new error cases do not exist yet, so the test target cannot compile. Do not push.

- [ ] **Step 3: Implement**

`LearningEngine/Sources/LearningEngine/Models/Skill.swift`:

```swift
import Foundation

/// The shared skill set every goal package weights. Order matters: it is the
/// tie-break order and the display order.
public enum Skill: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammar, reading, listening, writing, speaking, pronunciation

    /// Which skill a reviewed item counts toward.
    public static func forItemType(_ type: LearningItemType) -> Skill {
        switch type {
        case .vocabulary, .phrase, .collocation: return .vocabulary
        case .grammarPoint: return .grammar
        }
    }
}

public enum SkillWeightsError: Error, Equatable {
    case missingSkill(Skill)
    case negativeWeight(Skill)
    case zeroTotal
}

/// Per-package skill weights. Always contains all seven skills, each >= 0,
/// with a positive total.
public struct SkillWeights: Sendable, Equatable {
    private let values: [Skill: Double]

    public init(_ values: [Skill: Double]) throws {
        for skill in Skill.allCases {
            guard let value = values[skill] else { throw SkillWeightsError.missingSkill(skill) }
            guard value >= 0 else { throw SkillWeightsError.negativeWeight(skill) }
        }
        guard values.values.reduce(0, +) > 0 else { throw SkillWeightsError.zeroTotal }
        self.values = values
    }

    public static let vocabularyOnly: SkillWeights = {
        var values = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 0.0) })
        values[.vocabulary] = 1
        return try! SkillWeights(values)
    }()

    public func weight(of skill: Skill) -> Double { values[skill] ?? 0 }

    public func share(of skill: Skill) -> Double {
        weight(of: skill) / values.values.reduce(0, +)
    }

    public var activeSkills: [Skill] { Skill.allCases.filter { weight(of: $0) > 0 } }
}
```

`LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift` — replace the class (keep `LearningGoal` as is). Weights are stored as seven plain `Double` attributes with defaults: this keeps SwiftData lightweight migration trivial for existing stores and avoids composite-attribute encoding issues (spec §1.2 amended: one representation in JSON, flat attributes in SwiftData):

```swift
@Model
public final class ContentPackage {
    @Attribute(.unique) public var id: String
    public var name: String
    public var goal: LearningGoal
    public var levelLower: String
    public var levelUpper: String
    public var version: Int = 1
    public var weightVocabulary: Double = 1
    public var weightGrammar: Double = 0
    public var weightReading: Double = 0
    public var weightListening: Double = 0
    public var weightWriting: Double = 0
    public var weightSpeaking: Double = 0
    public var weightPronunciation: Double = 0
    @Relationship(deleteRule: .cascade, inverse: \Unit.package)
    public var units: [Unit] = []

    public init(
        id: String, name: String, goal: LearningGoal, levelLower: String, levelUpper: String,
        version: Int = 1, skillWeights: SkillWeights = .vocabularyOnly
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.levelLower = levelLower
        self.levelUpper = levelUpper
        self.version = version
        self.skillWeights = skillWeights
    }

    /// Falls back to vocabulary-only if stored values were ever invalid.
    public var skillWeights: SkillWeights {
        get {
            (try? SkillWeights([
                .vocabulary: weightVocabulary, .grammar: weightGrammar, .reading: weightReading,
                .listening: weightListening, .writing: weightWriting, .speaking: weightSpeaking,
                .pronunciation: weightPronunciation
            ])) ?? .vocabularyOnly
        }
        set {
            weightVocabulary = newValue.weight(of: .vocabulary)
            weightGrammar = newValue.weight(of: .grammar)
            weightReading = newValue.weight(of: .reading)
            weightListening = newValue.weight(of: .listening)
            weightWriting = newValue.weight(of: .writing)
            weightSpeaking = newValue.weight(of: .speaking)
            weightPronunciation = newValue.weight(of: .pronunciation)
        }
    }
}
```

`LearningEngine/Sources/LearningEngine/Models/Lesson.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class Lesson {
    @Attribute(.unique) public var id: String
    public var order: Int
    public var estimatedDurationMinutes: Int
    public var title: String = ""
    public var skill: Skill = Skill.vocabulary
    public var unit: Unit?
    @Relationship(deleteRule: .cascade, inverse: \LearningItem.lesson)
    public var items: [LearningItem] = []

    public init(id: String, order: Int, estimatedDurationMinutes: Int, title: String = "", skill: Skill = .vocabulary) {
        self.id = id
        self.order = order
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.title = title
        self.skill = skill
    }
}
```

`ContentDocuments.swift` — add fields:

```swift
public struct LessonDocument: Decodable {
    public let id: String
    public let order: Int
    public let estimatedDurationMinutes: Int
    public let title: String
    public let skill: String
    public let items: [LearningItemDocument]
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

`ContentImporter.swift` — add error cases and validation. Validation happens before any model object is created, and `context.insert` stays the last statement, so a throw inserts nothing:

```swift
public enum ContentImportError: Error, Equatable {
    case invalidGoal(String)
    case invalidItemType(String)
    case decodingFailed(String)
    case invalidSkillWeights(String)
    case invalidSkill(String)
    case invalidVersion(Int)
}
```

Inside `importPackage`, after the goal guard:

```swift
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
```

Replace the lesson construction line with:

```swift
                let lesson = Lesson(
                    id: lessonDoc.id, order: lessonDoc.order,
                    estimatedDurationMinutes: lessonDoc.estimatedDurationMinutes,
                    title: lessonDoc.title, skill: Skill(rawValue: lessonDoc.skill)!
                )
```

The item-type guard currently throws mid-loop before `context.insert`, which already inserts nothing; keep it. Add the helper to the enum:

```swift
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
```

`SampleContent.swift` needs no change (defaults cover it).

- [ ] **Step 4: Commit (do not push yet)**

```bash
git add LearningEngine/Sources/LearningEngine/Models/Skill.swift LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift LearningEngine/Sources/LearningEngine/Models/Lesson.swift LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift LearningEngine/Sources/LearningEngine/Import/ContentImporter.swift LearningEngine/Tests/LearningEngineTests/SkillWeightsTests.swift LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift
git commit   # subject: Add skill weights, lesson titles and skills to the content model (+ Global Constraints trailers)
```

- [ ] **Step 5: Verify via CI together with Task 2**

The bundled JSON and test fixture lack the new required fields until Task 2, so CI would fail on the fixture test and the app's seeding test. Task 1 and Task 2 are a single review unit: complete Task 2, then run `bash scripts/ci-test.sh` and `bash scripts/ci-app-build.sh` once for both.

---

### Task 2: Content assembly — version, weights, lesson titles and skills

**Files:**
- Modify: `scripts/assemble-content.py`
- Regenerate (by running the script, never by hand): `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`, `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`
- Modify: `App/Tests/EnglishAppTests/RealContentSeedingTests.swift` (assert the new fields)

**Interfaces:**
- Consumes: document fields from Task 1 (`version`, `skillWeights`, lesson `title`, lesson `skill`).
- Produces: bundled package `yds-academic-vocab-1` at `version` 2 with the Global Constraints weights and titles.

The batch files under `content/yds-academic-vocab-1/batches/` stay unchanged: the script derives `title` and defaults `skill`, so authors do not repeat them. A batch lesson may still set `title`/`skill` explicitly (Slice 7 grammar and reading lessons will).

- [ ] **Step 1: Write the failing test**

In `RealContentSeedingTests.test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsAll120ItemsAcrossFourUnits`, after the existing assertions, add:

```swift
        XCTAssertEqual(package.version, 2)
        XCTAssertEqual(package.skillWeights.activeSkills, [.vocabulary, .grammar, .reading])
        XCTAssertEqual(package.skillWeights.share(of: .pronunciation), 0)
        let scienceUnit = package.units.first { $0.id == "yds-vocab1-unit-science-research" }
        let secondLesson = scienceUnit?.lessons.first { $0.order == 1 }
        XCTAssertEqual(secondLesson?.title, "Science & Research Methods · 2")
        XCTAssertTrue(package.units.flatMap(\.lessons).allSatisfy { $0.skill == .vocabulary })
```

- [ ] **Step 2: Verify it would fail**

The bundled JSON has no `version`, `skillWeights`, `title` or `skill`, so decoding throws. Do not push.

- [ ] **Step 3: Implement the script changes**

In `scripts/assemble-content.py`, add below `OUTPUT_PATHS`:

```python
PACKAGE_VERSION = 2

# Skill weights for the YDS goal. YDS has no listening, speaking, writing or
# pronunciation section, so those are 0 and the planner never schedules them.
SKILL_WEIGHTS = {
    "vocabulary": 35,
    "grammar": 30,
    "reading": 35,
    "listening": 0,
    "writing": 0,
    "speaking": 0,
    "pronunciation": 0,
}

SKILLS = ["vocabulary", "grammar", "reading", "listening", "writing", "speaking", "pronunciation"]


def validate_weights(weights):
    keys = set(weights)
    missing = [s for s in SKILLS if s not in keys]
    unknown = sorted(keys - set(SKILLS))
    if missing or unknown:
        raise ValueError(f"skillWeights missing={missing} unknown={unknown}")
    if any(v < 0 for v in weights.values()):
        raise ValueError("skillWeights has a negative weight")
    if sum(weights.values()) <= 0:
        raise ValueError("skillWeights total must be > 0")


def enrich_lessons(unit):
    """Adds a derived title and a default skill to every lesson, with a
    stable key order so the committed JSON diff stays readable."""
    enriched = []
    for lesson in unit["lessons"]:
        skill = lesson.get("skill", "vocabulary")
        if skill not in SKILLS:
            raise ValueError(f"lesson {lesson['id']} has invalid skill {skill!r}")
        title = lesson.get("title", f"{unit['theme']} · {lesson['order'] + 1}")
        enriched.append({
            "id": lesson["id"],
            "order": lesson["order"],
            "estimatedDurationMinutes": lesson["estimatedDurationMinutes"],
            "title": title,
            "skill": skill,
            "items": lesson["items"],
        })
    unit = dict(unit)
    unit["lessons"] = enriched
    return unit
```

Replace `assemble()` with:

```python
def assemble():
    validate_weights(SKILL_WEIGHTS)
    return {
        "id": "yds-academic-vocab-1",
        "name": "YDS: Academic Vocabulary I",
        "goal": "yds",
        "levelLower": "B2",
        "levelUpper": "C1",
        "version": PACKAGE_VERSION,
        "skillWeights": SKILL_WEIGHTS,
        "units": [enrich_lessons(u) for u in load_units()],
    }
```

Update the module docstring with one paragraph: the script also stamps `version`, `skillWeights` and per-lesson `title`/`skill`, and bumping `PACKAGE_VERSION` makes installed apps re-import the package on next launch.

- [ ] **Step 4: Regenerate the JSON and inspect the diff**

Run: `python scripts/assemble-content.py`
Expected: two `Wrote …` lines.
Run: `git diff --stat`
Expected: both JSON files changed. `git diff App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json | head -40` shows `"version": 2`, the `skillWeights` block, and `"title": "Business & Economics · 1"` with `"skill": "vocabulary"` on the first lesson. Turkish characters in items must be unchanged (no mojibake in the diff).

- [ ] **Step 5: Commit and verify Tasks 1+2 via CI**

Commit message subject: `Stamp content version, skill weights and lesson titles in the YDS package` (plus the Global Constraints trailers).

```bash
git add scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json App/Tests/EnglishAppTests/RealContentSeedingTests.swift
git commit
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Expected: Swift Tests green (including `SkillWeightsTests`, the new `ContentImporterTests` and the drift check) and App Build green (`RealContentSeedingTests` with the new assertions).

---

### Task 3: Learner models, access policy and streak

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/LessonProgress.swift`
- Create: `LearningEngine/Sources/LearningEngine/Planning/PlanTypes.swift`
- Create: `LearningEngine/Sources/LearningEngine/Planning/LessonAccessPolicy.swift`
- Create: `LearningEngine/Sources/LearningEngine/Planning/StreakCalculator.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/LearnerModelsTests.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/LessonAccessPolicyTests.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/StreakCalculatorTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `@Model public final class LearnerProfile` — `userID` (unique), `activePackageID: String`, `dailyMinutes: Int`, `examDate: Date?`, `createdAt: Date`; `init(userID:activePackageID:dailyMinutes: = LearnerProfile.defaultDailyMinutes, examDate: = nil, createdAt:)`; `static let defaultDailyMinutes = 20`.
  - `@Model public final class LessonProgress` — `id` (unique, `"\(userID)|\(lessonID)"`), `userID`, `lessonID`, `startedAt: Date`, `completedAt: Date?`; `init(userID:lessonID:startedAt:)`; `static func makeID(userID:lessonID:) -> String`.
  - `public enum PackageAccessLevel: Sendable, Equatable { case owned, preview }`
  - `public struct UnitOutline { id: String; order: Int; lessonIDs: [String] }`, `public struct PackageOutline { units: [UnitOutline] }` (both `Sendable, Equatable`, public memberwise inits)
  - `public struct LessonAccessPolicy: Sendable { init(); func accessibleLessonIDs(in: PackageOutline, level: PackageAccessLevel) -> Set<String> }`
  - `public enum StreakCalculator { static func streak(activityDates: [Date], now: Date, calendar: Calendar = .current) -> Int }`

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/LearnerModelsTests.swift`:

```swift
import XCTest
import SwiftData
@testable import LearningEngine

final class LearnerModelsTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([LearnerProfile.self, LessonProgress.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_learnerProfile_defaults() throws {
        let context = try makeContext()
        let created = Date(timeIntervalSince1970: 1_000)
        context.insert(LearnerProfile(userID: "u1", activePackageID: "p1", createdAt: created))
        try context.save()

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 20)
        XCTAssertNil(profile.examDate)
        XCTAssertEqual(profile.activePackageID, "p1")
        XCTAssertEqual(profile.createdAt, created)
    }

    func test_lessonProgress_idCombinesUserAndLesson_andStartsIncomplete() throws {
        let context = try makeContext()
        let started = Date(timeIntervalSince1970: 2_000)
        context.insert(LessonProgress(userID: "u1", lessonID: "l1", startedAt: started))
        try context.save()

        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>()).first)
        XCTAssertEqual(progress.id, "u1|l1")
        XCTAssertEqual(LessonProgress.makeID(userID: "u1", lessonID: "l1"), "u1|l1")
        XCTAssertEqual(progress.startedAt, started)
        XCTAssertNil(progress.completedAt)
    }
}
```

`LearningEngine/Tests/LearningEngineTests/LessonAccessPolicyTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class LessonAccessPolicyTests: XCTestCase {
    // Units deliberately out of array order: access is decided by `order`.
    let outline = PackageOutline(units: [
        UnitOutline(id: "u-second", order: 1, lessonIDs: ["b1", "b2"]),
        UnitOutline(id: "u-first", order: 0, lessonIDs: ["a1", "a2", "a3"]),
    ])

    func test_preview_onlyLowestOrderUnitIsAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: outline, level: .preview), ["a1", "a2", "a3"])
    }

    func test_owned_everyLessonIsAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: outline, level: .owned), ["a1", "a2", "a3", "b1", "b2"])
    }

    func test_preview_emptyPackage_hasNothingAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: PackageOutline(units: []), level: .preview), [])
    }
}
```

`LearningEngine/Tests/LearningEngineTests/StreakCalculatorTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class StreakCalculatorTests: XCTestCase {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_noActivity_isZero() {
        XCTAssertEqual(StreakCalculator.streak(activityDates: [], now: date(2026, 9, 14), calendar: calendar), 0)
    }

    func test_consecutiveDaysEndingToday_countsAll_andMultipleEventsPerDayCountOnce() {
        let dates = [date(2026, 9, 12), date(2026, 9, 13, 8), date(2026, 9, 13, 22), date(2026, 9, 14, 9)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14, 23), calendar: calendar), 3)
    }

    func test_todayWithoutActivity_doesNotBreakStreakFromYesterday() {
        let dates = [date(2026, 9, 12), date(2026, 9, 13)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14, 7), calendar: calendar), 2)
    }

    func test_gapBeforeYesterday_resetsToZero() {
        XCTAssertEqual(StreakCalculator.streak(activityDates: [date(2026, 9, 11)], now: date(2026, 9, 14), calendar: calendar), 0)
    }

    func test_gapInsideHistory_countsOnlyRecentRun() {
        let dates = [date(2026, 9, 10), date(2026, 9, 12), date(2026, 9, 13), date(2026, 9, 14)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14), calendar: calendar), 3)
    }

    func test_monthBoundary() {
        let dates = [date(2026, 8, 31), date(2026, 9, 1)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 1), calendar: calendar), 2)
    }

    func test_dstSpringForward_isStillConsecutive() {
        // US DST starts 2026-03-08 (a 23-hour day).
        let dates = [date(2026, 3, 7, 23), date(2026, 3, 8, 1), date(2026, 3, 9, 0)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 3, 9, 10), calendar: calendar), 3)
    }
}
```

- [ ] **Step 2: Verify the tests would fail**

None of the tested types exist, so the test target cannot compile. Do not push.

- [ ] **Step 3: Implement**

`LearnerProfile.swift`:

```swift
import Foundation
import SwiftData

/// Per-user learning settings. Exactly one per user; `activePackageID` is the
/// single active goal that drives the daily plan.
@Model
public final class LearnerProfile {
    public static let defaultDailyMinutes = 20

    @Attribute(.unique) public var userID: String
    public var activePackageID: String
    public var dailyMinutes: Int
    public var examDate: Date?
    public var createdAt: Date

    public init(
        userID: String, activePackageID: String,
        dailyMinutes: Int = LearnerProfile.defaultDailyMinutes,
        examDate: Date? = nil, createdAt: Date
    ) {
        self.userID = userID
        self.activePackageID = activePackageID
        self.dailyMinutes = dailyMinutes
        self.examDate = examDate
        self.createdAt = createdAt
    }
}
```

`LessonProgress.swift`:

```swift
import Foundation
import SwiftData

/// Created when a learner first enters a lesson; `completedAt` is set once
/// every item of the lesson has been rated at least once.
@Model
public final class LessonProgress {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var lessonID: String
    public var startedAt: Date
    public var completedAt: Date?

    public init(userID: String, lessonID: String, startedAt: Date) {
        self.id = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        self.userID = userID
        self.lessonID = lessonID
        self.startedAt = startedAt
        self.completedAt = nil
    }

    public static func makeID(userID: String, lessonID: String) -> String {
        "\(userID)|\(lessonID)"
    }
}
```

`Planning/PlanTypes.swift`:

```swift
import Foundation

public enum PackageAccessLevel: Sendable, Equatable {
    case owned, preview
}

/// SwiftData-free snapshot of a package's unit/lesson structure.
public struct UnitOutline: Sendable, Equatable {
    public let id: String
    public let order: Int
    public let lessonIDs: [String]

    public init(id: String, order: Int, lessonIDs: [String]) {
        self.id = id
        self.order = order
        self.lessonIDs = lessonIDs
    }
}

public struct PackageOutline: Sendable, Equatable {
    public let units: [UnitOutline]

    public init(units: [UnitOutline]) {
        self.units = units
    }
}
```

`Planning/LessonAccessPolicy.swift`:

```swift
import Foundation

/// Owned packages expose every lesson; previews expose only the lessons of
/// the unit with the lowest `order`.
public struct LessonAccessPolicy: Sendable {
    public init() {}

    public func accessibleLessonIDs(in outline: PackageOutline, level: PackageAccessLevel) -> Set<String> {
        switch level {
        case .owned:
            return Set(outline.units.flatMap(\.lessonIDs))
        case .preview:
            guard let firstUnit = outline.units.min(by: { $0.order < $1.order }) else { return [] }
            return Set(firstUnit.lessonIDs)
        }
    }
}
```

`Planning/StreakCalculator.swift`:

```swift
import Foundation

public enum StreakCalculator {
    /// Consecutive local calendar days with activity, ending today — or
    /// ending yesterday if today has no activity yet (the streak only breaks
    /// once a whole day passes without activity).
    public static func streak(activityDates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let activeDays = Set(activityDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !activeDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
```

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add learner profile, lesson progress, preview access policy and streak` (plus trailers).

```bash
git add LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift LearningEngine/Sources/LearningEngine/Models/LessonProgress.swift LearningEngine/Sources/LearningEngine/Planning LearningEngine/Tests/LearningEngineTests/LearnerModelsTests.swift LearningEngine/Tests/LearningEngineTests/LessonAccessPolicyTests.swift LearningEngine/Tests/LearningEngineTests/StreakCalculatorTests.swift
git commit
bash scripts/ci-test.sh
```

Expected: Swift Tests green with the three new test classes passing.

---

### Task 4: Daily plan builder

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift`

**Interfaces:**
- Consumes: `Skill`, `SkillWeights` (Task 1).
- Produces (all `public`, `Sendable, Equatable`, public memberwise inits):
  - `struct PlanLesson { id: String; title: String; skill: Skill; estimatedMinutes: Int; isAccessible: Bool; completedAt: Date? }`
  - `struct DailyPlanInput { weights: SkillWeights; dailyMinutes: Int; lessonsInPathOrder: [PlanLesson]; dueNowCount: Int; reviewedTodayCount: Int; pastWeekSkillMinutes: [Skill: Double]; startOfToday: Date }`
  - `enum PlanTask { case review(cardCount: Int, minutes: Double, isDone: Bool); case lesson(id: String, title: String, skill: Skill, minutes: Double, isDone: Bool); case locked(id: String, title: String) }`
  - `struct SkillBalance { skill: Skill; targetShare: Double; actualShare: Double }`
  - `struct DailyPlan { tasks: [PlanTask]; totalMinutes: Double; weeklyBalance: [SkillBalance]; var isComplete: Bool }`
  - `struct DailyPlanBuilder { static let minutesPerReviewCard = 0.4; static let maxReviewShareOfBudget = 0.5; init(); func build(_ input: DailyPlanInput) -> DailyPlan }`

Precise rules (spec §2.2 made exact):
- `budget = Double(max(dailyMinutes, 0))`; `reviewCap = floor(budget * 0.5 / 0.4)`; `reviewTarget = min(reviewedTodayCount + dueNowCount, reviewCap)`. If `reviewTarget > 0`, the first task is `.review(cardCount: reviewTarget, minutes: reviewTarget * 0.4, isDone: reviewedTodayCount >= reviewTarget || dueNowCount == 0)`.
- Lesson candidates: `isAccessible`, `skill` in `weights.activeSkills`, and not `completedAt < startOfToday`. Each skill offers only its first remaining candidate in path order.
- Deficit uses lesson minutes only (review minutes cannot be attributed to a skill before they happen): `deficit(s) = share(s) * (pastTotal + plannedLessonMinutes) - (pastWeekSkillMinutes[s] + plannedLessonMinutesBySkill[s])`. Highest deficit wins; ties → higher weight; then `Skill.allCases` order.
- Keep adding while `reviewMinutes + plannedLessonMinutes < budget` and a candidate exists. If none was added and a candidate exists, add exactly one.
- A lesson task's `isDone` is `completedAt != nil` (only lessons completed today can reach the plan with a date).
- Locked card: if no lesson with an active skill is accessible and incomplete (`completedAt == nil`), and a lesson with an active skill is not accessible, append `.locked` for the first such inaccessible lesson in path order.
- `totalMinutes` = review minutes + lesson minutes. `weeklyBalance`: one entry per active skill in `Skill.allCases` order, `targetShare = share(s)`, `actualShare = pastTotal > 0 ? past[s] / pastTotal : 0`.
- `isComplete`: every `.review`/`.lesson` task is done (locked tasks do not count); true for an empty plan.

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class DailyPlanBuilderTests: XCTestCase {
    let startOfToday = Date(timeIntervalSince1970: 1_800_000_000)

    let yds = try! SkillWeights([
        .vocabulary: 35, .grammar: 30, .reading: 35,
        .listening: 0, .writing: 0, .speaking: 0, .pronunciation: 0
    ])

    func lesson(_ id: String, _ skill: Skill, minutes: Int = 8, accessible: Bool = true, completedAt: Date? = nil) -> PlanLesson {
        PlanLesson(id: id, title: "T-\(id)", skill: skill, estimatedMinutes: minutes, isAccessible: accessible, completedAt: completedAt)
    }

    func input(
        dailyMinutes: Int = 20, lessons: [PlanLesson] = [], due: Int = 0, reviewedToday: Int = 0,
        past: [Skill: Double] = [:], weights: SkillWeights? = nil
    ) -> DailyPlanInput {
        DailyPlanInput(
            weights: weights ?? yds, dailyMinutes: dailyMinutes, lessonsInPathOrder: lessons,
            dueNowCount: due, reviewedTodayCount: reviewedToday,
            pastWeekSkillMinutes: past, startOfToday: startOfToday
        )
    }

    func lessonIDs(_ plan: DailyPlan) -> [String] {
        plan.tasks.compactMap { if case .lesson(let id, _, _, _, _) = $0 { return id } else { return nil } }
    }

    func test_reviewTask_isCappedAtHalfTheBudget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 100))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 25, minutes: 10, isDone: false))
    }

    func test_reviewTask_isDoneWhenTodaysReviewsReachTheTarget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 5, reviewedToday: 25))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 25, minutes: 10, isDone: true))
    }

    func test_reviewTask_isDoneWhenNothingIsDueAnymore() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 0, reviewedToday: 6))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 6, minutes: 6 * 0.4, isDone: true))
    }

    func test_noDueAndNoReviewsToday_hasNoReviewTask() {
        let plan = DailyPlanBuilder().build(input(lessons: [lesson("v1", .vocabulary)]))
        XCTAssertEqual(lessonIDs(plan), ["v1"])
        XCTAssertEqual(plan.tasks.count, 1)
    }

    func test_picksTheSkillFurthestBehindItsWeeklyTarget() {
        // past total 100: vocabulary 35-60=-25, grammar 30-0=30, reading 35-40=-5 → grammar first.
        // After g1 (10 min, lesson total 10): grammar has no more lessons; reading -1.5 beats vocabulary -21.5.
        let lessons = [lesson("v1", .vocabulary), lesson("g1", .grammar, minutes: 10), lesson("r1", .reading, minutes: 12)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, past: [.vocabulary: 60, .reading: 40]))
        XCTAssertEqual(lessonIDs(plan), ["g1", "r1"])
        XCTAssertEqual(plan.totalMinutes, 22, accuracy: 1e-9)
    }

    func test_eachSkillOffersLessonsInPathOrder() {
        let lessons = [lesson("v1", .vocabulary, minutes: 5), lesson("v2", .vocabulary, minutes: 5), lesson("v3", .vocabulary, minutes: 5)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 10, lessons: lessons))
        XCTAssertEqual(lessonIDs(plan), ["v1", "v2"])
    }

    func test_zeroWeightSkill_isNeverScheduled() {
        let lessons = [lesson("p1", .pronunciation), lesson("v1", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, past: [.vocabulary: 500]))
        XCTAssertEqual(lessonIDs(plan), ["v1"])
    }

    func test_skillsWithoutLessons_areSkipped() {
        let lessons = [lesson("v1", .vocabulary), lesson("v2", .vocabulary), lesson("v3", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 16, lessons: lessons, past: [.vocabulary: 100]))
        XCTAssertEqual(lessonIDs(plan), ["v1", "v2"])
    }

    func test_atLeastOneLesson_evenWithNoBudget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 0, lessons: [lesson("v1", .vocabulary)], due: 30))
        XCTAssertEqual(plan.tasks, [.lesson(id: "v1", title: "T-v1", skill: .vocabulary, minutes: 8, isDone: false)])
    }

    func test_lessonCompletedToday_staysInPlanAsDone() {
        let lessons = [lesson("v1", .vocabulary, completedAt: startOfToday.addingTimeInterval(3600)), lesson("v2", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 10, lessons: lessons))
        XCTAssertEqual(plan.tasks.first, .lesson(id: "v1", title: "T-v1", skill: .vocabulary, minutes: 8, isDone: true))
    }

    func test_lessonCompletedBeforeToday_isExcluded() {
        let lessons = [lesson("v1", .vocabulary, completedAt: startOfToday.addingTimeInterval(-60)), lesson("v2", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 8, lessons: lessons))
        XCTAssertEqual(lessonIDs(plan), ["v2"])
    }

    func test_previewExhausted_appendsLockedCardForFirstInaccessibleLesson() {
        let lessons = [
            lesson("a1", .vocabulary, completedAt: startOfToday.addingTimeInterval(-86_400)),
            lesson("b1", .vocabulary, accessible: false),
            lesson("b2", .vocabulary, accessible: false),
        ]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, due: 4))
        XCTAssertEqual(plan.tasks, [.review(cardCount: 4, minutes: 4 * 0.4, isDone: false), .locked(id: "b1", title: "T-b1")])
    }

    func test_noLockedCard_whileAnAccessibleLessonIsStillIncomplete() {
        let lessons = [lesson("a1", .vocabulary), lesson("b1", .vocabulary, accessible: false)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons))
        XCTAssertFalse(plan.tasks.contains { if case .locked = $0 { return true } else { return false } })
    }

    func test_emptyInputs_produceAnEmptyCompletePlan() {
        let plan = DailyPlanBuilder().build(input())
        XCTAssertEqual(plan.tasks, [])
        XCTAssertTrue(plan.isComplete)
        XCTAssertEqual(plan.totalMinutes, 0)
    }

    func test_isComplete_ignoresLockedTasks() {
        let lessons = [
            lesson("a1", .vocabulary, completedAt: startOfToday.addingTimeInterval(600)),
            lesson("b1", .vocabulary, accessible: false),
        ]
        let plan = DailyPlanBuilder().build(input(lessons: lessons))
        XCTAssertTrue(plan.isComplete)
    }

    func test_sameInput_sameOutput() {
        let lessons = [lesson("v1", .vocabulary), lesson("g1", .grammar), lesson("r1", .reading)]
        let i = input(lessons: lessons, due: 12, past: [.grammar: 20])
        XCTAssertEqual(DailyPlanBuilder().build(i), DailyPlanBuilder().build(i))
    }

    func test_weeklyBalance_coversActiveSkillsInOrder() {
        let plan = DailyPlanBuilder().build(input(past: [.vocabulary: 30, .reading: 10]))
        XCTAssertEqual(plan.weeklyBalance.map(\.skill), [.vocabulary, .grammar, .reading])
        XCTAssertEqual(plan.weeklyBalance[0].targetShare, 0.35, accuracy: 1e-9)
        XCTAssertEqual(plan.weeklyBalance[0].actualShare, 0.75, accuracy: 1e-9)
        XCTAssertEqual(plan.weeklyBalance[1].actualShare, 0, accuracy: 1e-9)
    }

    func test_weeklyBalance_withNoHistory_hasZeroActualShares() {
        let plan = DailyPlanBuilder().build(input())
        XCTAssertTrue(plan.weeklyBalance.allSatisfy { $0.actualShare == 0 })
    }
}
```

- [ ] **Step 2: Verify the tests would fail**

The planning types do not exist, so the test target cannot compile. Do not push.

- [ ] **Step 3: Implement**

`LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift`:

```swift
import Foundation

public struct PlanLesson: Sendable, Equatable {
    public let id: String
    public let title: String
    public let skill: Skill
    public let estimatedMinutes: Int
    public let isAccessible: Bool
    public let completedAt: Date?

    public init(id: String, title: String, skill: Skill, estimatedMinutes: Int, isAccessible: Bool, completedAt: Date?) {
        self.id = id
        self.title = title
        self.skill = skill
        self.estimatedMinutes = estimatedMinutes
        self.isAccessible = isAccessible
        self.completedAt = completedAt
    }
}

public struct DailyPlanInput: Sendable, Equatable {
    public let weights: SkillWeights
    public let dailyMinutes: Int
    public let lessonsInPathOrder: [PlanLesson]
    public let dueNowCount: Int
    public let reviewedTodayCount: Int
    public let pastWeekSkillMinutes: [Skill: Double]
    public let startOfToday: Date

    public init(
        weights: SkillWeights, dailyMinutes: Int, lessonsInPathOrder: [PlanLesson],
        dueNowCount: Int, reviewedTodayCount: Int,
        pastWeekSkillMinutes: [Skill: Double], startOfToday: Date
    ) {
        self.weights = weights
        self.dailyMinutes = dailyMinutes
        self.lessonsInPathOrder = lessonsInPathOrder
        self.dueNowCount = dueNowCount
        self.reviewedTodayCount = reviewedTodayCount
        self.pastWeekSkillMinutes = pastWeekSkillMinutes
        self.startOfToday = startOfToday
    }
}

public enum PlanTask: Sendable, Equatable {
    case review(cardCount: Int, minutes: Double, isDone: Bool)
    case lesson(id: String, title: String, skill: Skill, minutes: Double, isDone: Bool)
    case locked(id: String, title: String)
}

public struct SkillBalance: Sendable, Equatable {
    public let skill: Skill
    public let targetShare: Double
    public let actualShare: Double

    public init(skill: Skill, targetShare: Double, actualShare: Double) {
        self.skill = skill
        self.targetShare = targetShare
        self.actualShare = actualShare
    }
}

public struct DailyPlan: Sendable, Equatable {
    public let tasks: [PlanTask]
    public let totalMinutes: Double
    public let weeklyBalance: [SkillBalance]

    public init(tasks: [PlanTask], totalMinutes: Double, weeklyBalance: [SkillBalance]) {
        self.tasks = tasks
        self.totalMinutes = totalMinutes
        self.weeklyBalance = weeklyBalance
    }

    /// Every review/lesson task is done. Locked tasks are not actionable, so
    /// they never keep the plan open.
    public var isComplete: Bool {
        tasks.allSatisfy { task in
            switch task {
            case .review(_, _, let isDone), .lesson(_, _, _, _, let isDone): return isDone
            case .locked: return true
            }
        }
    }
}

/// Builds the day's plan from a pure snapshot. Contains no clock reads and no
/// SwiftData, so identical inputs always produce identical plans.
public struct DailyPlanBuilder: Sendable {
    public static let minutesPerReviewCard = 0.4
    public static let maxReviewShareOfBudget = 0.5

    public init() {}

    public func build(_ input: DailyPlanInput) -> DailyPlan {
        var tasks: [PlanTask] = []
        let budget = Double(max(input.dailyMinutes, 0))
        let weights = input.weights
        let activeSkills = Set(weights.activeSkills)

        // 1. Review task.
        let reviewCap = Int((budget * Self.maxReviewShareOfBudget / Self.minutesPerReviewCard).rounded(.down))
        let reviewTarget = min(input.reviewedTodayCount + input.dueNowCount, reviewCap)
        var reviewMinutes = 0.0
        if reviewTarget > 0 {
            reviewMinutes = Double(reviewTarget) * Self.minutesPerReviewCard
            let isDone = input.reviewedTodayCount >= reviewTarget || input.dueNowCount == 0
            tasks.append(.review(cardCount: reviewTarget, minutes: reviewMinutes, isDone: isDone))
        }

        // 2. Lesson selection by weekly deficit.
        var queues: [Skill: [PlanLesson]] = [:]
        for lesson in input.lessonsInPathOrder
        where lesson.isAccessible && activeSkills.contains(lesson.skill) && !completedBeforeToday(lesson, input) {
            queues[lesson.skill, default: []].append(lesson)
        }

        let pastTotal = input.pastWeekSkillMinutes.values.reduce(0, +)
        var plannedLessonMinutes = 0.0
        var plannedBySkill: [Skill: Double] = [:]
        var addedAny = false

        func nextLesson() -> PlanLesson? {
            let skills = Skill.allCases.filter { !(queues[$0]?.isEmpty ?? true) }
            let best = skills.max { lhs, rhs in
                let dl = deficit(lhs), dr = deficit(rhs)
                if dl != dr { return dl < dr }
                let wl = weights.weight(of: lhs), wr = weights.weight(of: rhs)
                if wl != wr { return wl < wr }
                // Earlier Skill.allCases position wins, so it must compare as "larger".
                return Skill.allCases.firstIndex(of: lhs)! > Skill.allCases.firstIndex(of: rhs)!
            }
            guard let skill = best else { return nil }
            return queues[skill]!.removeFirst()
        }

        func deficit(_ skill: Skill) -> Double {
            weights.share(of: skill) * (pastTotal + plannedLessonMinutes)
                - ((input.pastWeekSkillMinutes[skill] ?? 0) + (plannedBySkill[skill] ?? 0))
        }

        func add(_ lesson: PlanLesson) {
            let minutes = Double(lesson.estimatedMinutes)
            tasks.append(.lesson(id: lesson.id, title: lesson.title, skill: lesson.skill, minutes: minutes, isDone: lesson.completedAt != nil))
            plannedLessonMinutes += minutes
            plannedBySkill[lesson.skill, default: 0] += minutes
            addedAny = true
        }

        while reviewMinutes + plannedLessonMinutes < budget, let lesson = nextLesson() {
            add(lesson)
        }
        // 3. At least one lesson when any candidate exists.
        if !addedAny, let lesson = nextLesson() {
            add(lesson)
        }

        // 5. Locked card when the accessible part is exhausted.
        let activeLessons = input.lessonsInPathOrder.filter { activeSkills.contains($0.skill) }
        let hasOpenAccessible = activeLessons.contains { $0.isAccessible && $0.completedAt == nil }
        if !hasOpenAccessible, let locked = activeLessons.first(where: { !$0.isAccessible }) {
            tasks.append(.locked(id: locked.id, title: locked.title))
        }

        let balance = weights.activeSkills.map { skill in
            SkillBalance(
                skill: skill,
                targetShare: weights.share(of: skill),
                actualShare: pastTotal > 0 ? (input.pastWeekSkillMinutes[skill] ?? 0) / pastTotal : 0
            )
        }

        return DailyPlan(tasks: tasks, totalMinutes: reviewMinutes + plannedLessonMinutes, weeklyBalance: balance)
    }

    private func completedBeforeToday(_ lesson: PlanLesson, _ input: DailyPlanInput) -> Bool {
        guard let completedAt = lesson.completedAt else { return false }
        return completedAt < input.startOfToday
    }
}
```

Note for the reviewer and implementer: `SkillWeights` must be `Equatable` for `DailyPlanInput: Equatable` (Task 1 declares it).

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add goal-weighted daily plan builder` (plus trailers).

```bash
git add LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift
git commit
bash scripts/ci-test.sh
```

Expected: Swift Tests green, all `DailyPlanBuilderTests` pass.

---

### Task 5: App data layer — versioned seeding, access provider, plan coordinator

**Files:**
- Modify: `App/Sources/EnglishApp/AppModelContainer.swift`
- Create: `App/Sources/EnglishApp/ContentSeeder.swift`
- Create: `App/Sources/EnglishApp/Access/PackageAccessProvider.swift`
- Create: `App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift`
- Modify: `App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift`
- Modify: `App/Sources/EnglishApp/AppState.swift` (inject the access provider)
- Create: `App/Tests/EnglishAppTests/ContentSeederTests.swift`
- Create: `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift`
- Create: `App/Tests/EnglishAppTests/TestPackageJSON.swift` (shared test helper)
- Modify: `App/Tests/EnglishAppTests/TodaySessionCoordinatorTests.swift`

**Interfaces:**
- Consumes: Task 1 (`ContentPackage.version`, `.skillWeights`, `Lesson.title`, `.skill`, `Skill.forItemType`), Task 3 (`LearnerProfile`, `LessonProgress`, `PackageAccessLevel`, `PackageOutline`, `UnitOutline`, `LessonAccessPolicy`, `StreakCalculator`), Task 4 (`DailyPlanInput`, `PlanLesson`, `DailyPlan`, `DailyPlanBuilder`).
- Produces:
  - `enum ContentSeeder { static func seed(bundledData: Data, into context: ModelContext) throws -> SeedOutcome }`, `enum SeedOutcome: Equatable { case imported, upgraded(from: Int, to: Int), upToDate }`
  - `protocol PackageAccessProvider { func accessLevel(forPackageID id: String) -> PackageAccessLevel }`; `struct DevelopmentPackageAccessProvider: PackageAccessProvider { static let unlockAllKey = "dev.unlockAllPackages"; init(defaults: UserDefaults = .standard) }`
  - `AppState.accessProvider: any PackageAccessProvider` (default `DevelopmentPackageAccessProvider()`)
  - `struct TodayPlanCoordinator` — `init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider, now: Date = Date(), calendar: Calendar = .current)`; `func ensureProfile() throws -> LearnerProfile?`; `func activePackage() throws -> ContentPackage?`; `func buildPlanInput() throws -> DailyPlanInput?`; `func buildPlan() throws -> DailyPlan?`; `func streak() throws -> Int`; `func stats() throws -> LearnerStats`
  - `struct LearnerStats: Equatable { streak: Int; wordsSeen: Int; completedLessons: Int; totalLessons: Int; packageName: String?; accessLevel: PackageAccessLevel?; dailyMinutes: Int }`
  - `TodaySessionCoordinator.buildTodaySession()` now returns only items that already have a `UserItemState` (the review queue).

Seeding strategy (resolves the spec §1.4 SwiftData risk up front): the new document is first imported into a throwaway in-memory container. Only if that fully succeeds is the old package deleted and saved, and the new one imported and saved. Deletion and re-insertion never share a save, and invalid content can never remove existing content.

- [ ] **Step 1: Write the shared test helper and the failing tests**

`App/Tests/EnglishAppTests/TestPackageJSON.swift`:

```swift
import Foundation

/// Two units (order 0 and 1), two vocabulary lessons each (8 minutes), two
/// items per lesson. Item IDs: "<prefix>-u<unit>-l<lesson>-i<item>".
enum TestPackageJSON {
    static func make(id: String = "pkg", version: Int = 1, titleSuffix: String = "", prefix: String = "item") -> Data {
        func item(_ u: Int, _ l: Int, _ i: Int) -> String {
            """
            { "id": "\(prefix)-u\(u)-l\(l)-i\(i)", "type": "vocabulary", "headword": "word\(u)\(l)\(i)",
              "frequencyRank": \(u * 10 + l + i), "baseDifficulty": 0.3,
              "definition": "d", "exampleSentences": ["e"], "translationTR": "t", "collocations": [] }
            """
        }
        func lesson(_ u: Int, _ l: Int) -> String {
            """
            { "id": "lesson-u\(u)-l\(l)", "order": \(l), "estimatedDurationMinutes": 8,
              "title": "Unit \(u) · \(l + 1)\(titleSuffix)", "skill": "vocabulary",
              "items": [\(item(u, l, 0)), \(item(u, l, 1))] }
            """
        }
        func unit(_ u: Int) -> String {
            """
            { "id": "unit-\(u)", "theme": "Unit \(u)", "order": \(u), "lessons": [\(lesson(u, 0)), \(lesson(u, 1))] }
            """
        }
        return """
        { "id": "\(id)", "name": "Test \(id)", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "version": \(version),
          "skillWeights": { "vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0 },
          "units": [\(unit(0)), \(unit(1))] }
        """.data(using: .utf8)!
    }

    static let invalid = #"{ "id": "pkg", "name": "x", "goal": "yds", "levelLower": "B2", "levelUpper": "C1", "version": 9, "skillWeights": {}, "units": [] }"#.data(using: .utf8)!
}
```

`App/Tests/EnglishAppTests/ContentSeederTests.swift`:

```swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class ContentSeederTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_emptyStore_imports() throws {
        let context = try makeContext()
        XCTAssertEqual(try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context), .imported)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 1)
    }

    func test_sameVersion_isUpToDate_andDoesNotDuplicate() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)
        XCTAssertEqual(try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context), .upToDate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
    }

    func test_newerVersion_replacesContent_andKeepsUserState() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)
        try FSRSStateStore().recordReview(userID: "u", itemID: "item-u0-l0-i0", rating: .good, now: Date(), in: context, scheduler: FSRSScheduler())
        context.insert(LessonProgress(userID: "u", lessonID: "lesson-u0-l0", startedAt: Date()))
        try context.save()

        let outcome = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 2, titleSuffix: " (v2)"), into: context)

        XCTAssertEqual(outcome, .upgraded(from: 1, to: 2))
        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].version, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertTrue(lessons.allSatisfy { $0.title.hasSuffix(" (v2)") })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LessonProgress>()), 1)
    }

    func test_invalidNewerContent_throws_andKeepsOldContent() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)

        XCTAssertThrowsError(try ContentSeeder.seed(bundledData: TestPackageJSON.invalid, into: context))

        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.map(\.version), [1])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
    }
}
```

`App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift`:

```swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

struct FixedAccessProvider: PackageAccessProvider {
    let level: PackageAccessLevel
    func accessLevel(forPackageID id: String) -> PackageAccessLevel { level }
}

final class TodayPlanCoordinatorTests: XCTestCase {
    let userID = "u"
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    lazy var now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 15))!
    lazy var startOfToday = calendar.startOfDay(for: now)

    func makeContext(seed: Bool = true) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if seed { _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context) }
        return context
    }

    func coordinator(_ context: ModelContext, level: PackageAccessLevel = .preview) -> TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: level), now: now, calendar: calendar)
    }

    func test_ensureProfile_createsDefaultForFirstPackage_once() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(coordinator(context).ensureProfile())
        XCTAssertEqual(profile.activePackageID, "pkg")
        XCTAssertEqual(profile.dailyMinutes, 20)
        _ = try coordinator(context).ensureProfile()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearnerProfile>()), 1)
    }

    func test_ensureProfile_repairsMissingActivePackage() throws {
        let context = try makeContext()
        context.insert(LearnerProfile(userID: userID, activePackageID: "gone", createdAt: now))
        try context.save()
        XCTAssertEqual(try coordinator(context).ensureProfile()?.activePackageID, "pkg")
    }

    func test_noPackages_meansNoProfileAndNoPlan() throws {
        let context = try makeContext(seed: false)
        XCTAssertNil(try coordinator(context).ensureProfile())
        XCTAssertNil(try coordinator(context).buildPlan())
    }

    func test_planInput_lessonsInPathOrder_withPreviewAccess() throws {
        let context = try makeContext()
        let input = try XCTUnwrap(coordinator(context, level: .preview).buildPlanInput())
        XCTAssertEqual(input.lessonsInPathOrder.map(\.id), ["lesson-u0-l0", "lesson-u0-l1", "lesson-u1-l0", "lesson-u1-l1"])
        XCTAssertEqual(input.lessonsInPathOrder.map(\.isAccessible), [true, true, false, false])
        XCTAssertEqual(input.lessonsInPathOrder[0].title, "Unit 0 · 1")
        XCTAssertEqual(input.dailyMinutes, 20)
        XCTAssertEqual(input.startOfToday, startOfToday)
    }

    func test_planInput_ownedAccess_unlocksEverything() throws {
        let context = try makeContext()
        let input = try XCTUnwrap(coordinator(context, level: .owned).buildPlanInput())
        XCTAssertTrue(input.lessonsInPathOrder.allSatisfy(\.isAccessible))
    }

    func test_planInput_dueAndReviewedTodayCounts() throws {
        let context = try makeContext()
        let store = FSRSStateStore()
        // Reviewed yesterday → due today (min interval is 1 day).
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .again, now: yesterday, in: context, scheduler: FSRSScheduler())
        // Reviewed twice today → counts once, not due now.
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now.addingTimeInterval(-600), in: context, scheduler: FSRSScheduler())
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now.addingTimeInterval(-300), in: context, scheduler: FSRSScheduler())

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.dueNowCount, 1)
        XCTAssertEqual(input.reviewedTodayCount, 1)
    }

    func test_planInput_pastWeekMinutes_useLessonsAndReviewsBeforeToday() throws {
        let context = try makeContext()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: twoDaysAgo)
        progress.completedAt = twoDaysAgo
        context.insert(progress)
        for i in 0..<5 {
            context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i\(i % 2)", rating: .good, reviewedAt: calendar.date(byAdding: .day, value: -3, to: now)!))
        }
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i0", rating: .good, reviewedAt: now))                                   // today: excluded
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i0", rating: .good, reviewedAt: calendar.date(byAdding: .day, value: -8, to: now)!)) // too old
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.pastWeekSkillMinutes[.vocabulary] ?? 0, 8 + 5 * 0.4, accuracy: 1e-9)
        XCTAssertEqual(input.lessonsInPathOrder[0].completedAt, twoDaysAgo)
    }

    func test_buildPlan_firstDay_schedulesPreviewLessons() throws {
        let context = try makeContext()
        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        XCTAssertEqual(plan.tasks.first, .lesson(id: "lesson-u0-l0", title: "Unit 0 · 1", skill: .vocabulary, minutes: 8, isDone: false))
    }

    func test_streak_andStats() throws {
        let context = try makeContext()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l0-i0", rating: .good, reviewedAt: yesterday))
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now, in: context, scheduler: FSRSScheduler())
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: now)
        progress.completedAt = now
        context.insert(progress)
        try context.save()

        let c = coordinator(context)
        XCTAssertEqual(try c.streak(), 2)
        let stats = try c.stats()
        XCTAssertEqual(stats.wordsSeen, 1)
        XCTAssertEqual(stats.completedLessons, 1)
        XCTAssertEqual(stats.totalLessons, 4)
        XCTAssertEqual(stats.packageName, "Test pkg")
        XCTAssertEqual(stats.accessLevel, .preview)
        XCTAssertEqual(stats.dailyMinutes, 20)
    }
}
```

Replace `App/Tests/EnglishAppTests/TodaySessionCoordinatorTests.swift`'s first test with these two (keep the two `computeSnapshot` tests unchanged):

```swift
    func test_buildTodaySession_coldStart_isEmpty_becauseNewWordsComeFromLessons() throws {
        let context = try makeInMemoryContext()
        context.insert(SampleContent.ydsStarterPackage())
        try context.save()

        let session = try TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5).buildTodaySession()

        XCTAssertTrue(session.isEmpty)
    }

    func test_buildTodaySession_returnsOnlyDueSeenItems() throws {
        let context = try makeInMemoryContext()
        let package = SampleContent.ydsStarterPackage()
        context.insert(package)
        try context.save()
        let reviewedAt = Date().addingTimeInterval(-3 * 86_400)
        try FSRSStateStore().recordReview(userID: "test-user", itemID: "sample-item-hypothesis", rating: .again, now: reviewedAt, in: context, scheduler: FSRSScheduler())

        let session = try TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5).buildTodaySession()

        XCTAssertEqual(session.map(\.id), ["sample-item-hypothesis"])
    }
```

- [ ] **Step 2: Verify the tests would fail**

`ContentSeeder`, `PackageAccessProvider`, `TodayPlanCoordinator` and the new schema entries do not exist. The old `TodaySessionCoordinator` backfills never-seen items, so the cold-start test would get a non-empty session. Do not push.

- [ ] **Step 3: Implement**

`App/Sources/EnglishApp/ContentSeeder.swift`:

```swift
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
```

`App/Sources/EnglishApp/AppModelContainer.swift` — change the schema and replace `seedRealContentIfNeeded`:

```swift
    static let schema = Schema([
        ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
        ReviewLog.self, UserItemState.self, LearnerProfile.self, LessonProgress.self
    ])
```

```swift
    static func seedRealContentIfNeeded(in context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            assertionFailure("YDSAcademicVocabulary1.json missing from app bundle")
            containerCreationError = "YDSAcademicVocabulary1.json missing from app bundle"
            return
        }
        do {
            _ = try ContentSeeder.seed(bundledData: Data(contentsOf: url), into: context)
        } catch {
            containerCreationError = "Failed to seed content: \(error.localizedDescription)"
        }
    }
```

`RealContentSeedingTests.test_seedRealContentIfNeeded_populatesEmptyStore_andIsIdempotent` keeps passing unchanged (the second call is `.upToDate`).

`App/Sources/EnglishApp/Access/PackageAccessProvider.swift`:

```swift
import Foundation
import LearningEngine

/// Entitlement boundary. Slice 8 replaces the implementation with StoreKit;
/// screens only ever talk to this protocol.
protocol PackageAccessProvider {
    func accessLevel(forPackageID id: String) -> PackageAccessLevel
}

/// Development stand-in: every package is a preview unless the developer
/// toggle in Profile unlocks all of them.
struct DevelopmentPackageAccessProvider: PackageAccessProvider {
    static let unlockAllKey = "dev.unlockAllPackages"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        defaults.bool(forKey: Self.unlockAllKey) ? .owned : .preview
    }
}
```

In `AppState.swift`, add below `tutorEngine`:

```swift
    /// Swapped for a StoreKit-backed provider in Slice 8.
    let accessProvider: any PackageAccessProvider = DevelopmentPackageAccessProvider()
```

`App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift`:

```swift
import Foundation
import SwiftData
import LearningEngine

struct LearnerStats: Equatable {
    let streak: Int
    let wordsSeen: Int
    let completedLessons: Int
    let totalLessons: Int
    let packageName: String?
    let accessLevel: PackageAccessLevel?
    let dailyMinutes: Int
}

/// Snapshots SwiftData into the pure planning types.
struct TodayPlanCoordinator {
    let context: ModelContext
    let userID: String
    let accessProvider: any PackageAccessProvider
    let now: Date
    let calendar: Calendar

    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider, now: Date = Date(), calendar: Calendar = .current) {
        self.context = context
        self.userID = userID
        self.accessProvider = accessProvider
        self.now = now
        self.calendar = calendar
    }

    /// Returns the user's profile, creating or repairing it so it always points
    /// at an installed package. Nil only when no package is installed.
    @discardableResult
    func ensureProfile() throws -> LearnerProfile? {
        let packages = try context.fetch(FetchDescriptor<ContentPackage>(sortBy: [SortDescriptor(\.id)]))
        guard let firstPackage = packages.first else { return nil }
        let userIDValue = userID
        let existing = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first
        if let existing {
            if !packages.contains(where: { $0.id == existing.activePackageID }) {
                existing.activePackageID = firstPackage.id
                try context.save()
            }
            return existing
        }
        let profile = LearnerProfile(userID: userID, activePackageID: firstPackage.id, createdAt: now)
        context.insert(profile)
        try context.save()
        return profile
    }

    func activePackage() throws -> ContentPackage? {
        guard let profile = try ensureProfile() else { return nil }
        let packageID = profile.activePackageID
        return try context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first
    }

    func buildPlanInput() throws -> DailyPlanInput? {
        guard let profile = try ensureProfile(), let package = try activePackage() else { return nil }

        let units = package.units.sorted { $0.order < $1.order }
        let lessons = units.flatMap { $0.lessons.sorted { $0.order < $1.order } }
        let outline = PackageOutline(units: units.map { unit in
            UnitOutline(id: unit.id, order: unit.order, lessonIDs: unit.lessons.map(\.id))
        })
        let accessible = LessonAccessPolicy().accessibleLessonIDs(in: outline, level: accessProvider.accessLevel(forPackageID: package.id))
        let completion = try completionDates()

        let planLessons = lessons.map { lesson in
            PlanLesson(
                id: lesson.id, title: lesson.title, skill: lesson.skill,
                estimatedMinutes: lesson.estimatedDurationMinutes,
                isAccessible: accessible.contains(lesson.id),
                completedAt: completion[lesson.id]
            )
        }

        let startOfToday = calendar.startOfDay(for: now)
        let userIDValue = userID
        let nowValue = now
        let dueNowCount = try context.fetchCount(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue && $0.dueDate <= nowValue }))
        let todaysLogs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.userID == userIDValue && $0.reviewedAt >= startOfToday }))

        return DailyPlanInput(
            weights: package.skillWeights,
            dailyMinutes: profile.dailyMinutes,
            lessonsInPathOrder: planLessons,
            dueNowCount: dueNowCount,
            reviewedTodayCount: Set(todaysLogs.map(\.itemID)).count,
            pastWeekSkillMinutes: try pastWeekSkillMinutes(startOfToday: startOfToday, lessons: lessons),
            startOfToday: startOfToday
        )
    }

    func buildPlan() throws -> DailyPlan? {
        try buildPlanInput().map { DailyPlanBuilder().build($0) }
    }

    func streak() throws -> Int {
        let userIDValue = userID
        let logs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.userID == userIDValue }))
        let completions = try completionDates().values
        return StreakCalculator.streak(activityDates: logs.map(\.reviewedAt) + completions, now: now, calendar: calendar)
    }

    func stats() throws -> LearnerStats {
        let profile = try ensureProfile()
        let package = try activePackage()
        let userIDValue = userID
        let wordsSeen = try context.fetchCount(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue }))
        let lessonIDs = Set(package?.units.flatMap { $0.lessons.map(\.id) } ?? [])
        let completed = try completionDates().keys.filter { lessonIDs.contains($0) }.count
        return LearnerStats(
            streak: try streak(),
            wordsSeen: wordsSeen,
            completedLessons: completed,
            totalLessons: lessonIDs.count,
            packageName: package?.name,
            accessLevel: package.map { accessProvider.accessLevel(forPackageID: $0.id) },
            dailyMinutes: profile?.dailyMinutes ?? LearnerProfile.defaultDailyMinutes
        )
    }

    /// lessonID → completion date, for this user's completed lessons.
    private func completionDates() throws -> [String: Date] {
        let userIDValue = userID
        let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.userID == userIDValue }))
        var result: [String: Date] = [:]
        for row in progress {
            if let completedAt = row.completedAt { result[row.lessonID] = completedAt }
        }
        return result
    }

    private func pastWeekSkillMinutes(startOfToday: Date, lessons: [Lesson]) throws -> [Skill: Double] {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: startOfToday) else { return [:] }
        var minutes: [Skill: Double] = [:]

        let lessonsByID = Dictionary(lessons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (lessonID, completedAt) in try completionDates() where completedAt >= windowStart && completedAt < startOfToday {
            guard let lesson = lessonsByID[lessonID] else { continue }
            minutes[lesson.skill, default: 0] += Double(lesson.estimatedDurationMinutes)
        }

        let userIDValue = userID
        let logs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate {
            $0.userID == userIDValue && $0.reviewedAt >= windowStart && $0.reviewedAt < startOfToday
        }))
        if !logs.isEmpty {
            let items = try context.fetch(FetchDescriptor<LearningItem>())
            let typeByID = Dictionary(items.map { ($0.id, $0.type) }, uniquingKeysWith: { first, _ in first })
            for log in logs {
                guard let type = typeByID[log.itemID] else { continue }
                minutes[Skill.forItemType(type), default: 0] += DailyPlanBuilder.minutesPerReviewCard
            }
        }
        return minutes
    }
}
```

`App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift` — replace `buildTodaySession()` (and delete the backfill block and its comment):

```swift
    /// The review queue: due items the learner has already seen. Never-seen
    /// items are introduced only through lessons (StudySessionViewModel).
    func buildTodaySession() throws -> [LearningItem] {
        let userIDValue = userID
        let allStates = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue }))
        let seenIDs = Set(allStates.map(\.itemID))
        let seenItems = try context.fetch(FetchDescriptor<LearningItem>()).filter { seenIDs.contains($0.id) && $0.content != nil }
        let dueStates = allStates.filter { $0.dueDate <= now }

        return DailySessionBuilder().buildSession(
            candidateItems: seenItems,
            dueStates: dueStates,
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: try computeSnapshot(),
            sessionSize: sessionSize,
            now: now
        )
        .filter { item in dueStates.contains { $0.itemID == item.id } }
    }
```

(The trailing filter drops non-due "new candidates" that `DailySessionBuilder` would otherwise append from the seen set.)

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add versioned content seeding, access provider and plan coordinator` (plus trailers).

```bash
git add App/Sources/EnglishApp/AppModelContainer.swift App/Sources/EnglishApp/ContentSeeder.swift App/Sources/EnglishApp/Access App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift App/Sources/EnglishApp/Today/TodaySessionCoordinator.swift App/Sources/EnglishApp/AppState.swift App/Tests/EnglishAppTests/ContentSeederTests.swift App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift App/Tests/EnglishAppTests/TestPackageJSON.swift App/Tests/EnglishAppTests/TodaySessionCoordinatorTests.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green; `ContentSeederTests`, `TodayPlanCoordinatorTests`, updated `TodaySessionCoordinatorTests` and the existing `RealContentSeedingTests` pass. `TodayView` still compiles (it only calls `buildTodaySession()`).

---

### Task 6: Design system — tokens and components

**Files:**
- Create: `App/Sources/EnglishApp/DesignSystem/Theme.swift`
- Create: `App/Sources/EnglishApp/DesignSystem/SkillStyle.swift`
- Create: `App/Sources/EnglishApp/DesignSystem/Components.swift`
- Create: `App/Sources/EnglishApp/DesignSystem/PlanTaskRow.swift`
- Create: `App/Tests/EnglishAppTests/DesignSystemTests.swift`

**Interfaces:**
- Consumes: `Skill`, `PlanTask`, `FSRSRating` (LearningEngine).
- Produces:
  - `enum Theme` with static `Color`s: `paper, surface, border, ink, secondaryInk, primary, accent, danger, reading, listening, writing, speaking, pronunciation`; `static func dynamic(light: UInt32, dark: UInt32) -> Color`; `static func rgb(_ hex: UInt32) -> (r: Double, g: Double, b: Double)`.
  - `extension Font { static func serifTitle(_ style: Font.TextStyle = .title) -> Font }`
  - `extension Skill { var displayName: String; var color: Color }`
  - `extension FSRSRating { var label: String }` (Turkish labels from Global Constraints)
  - Views: `PaperCard<Content: View>(content:)`, `PrimaryButtonStyle`, `SkillBadge(skill:)`, `ProgressBar(progress: Double)`, `RatingButton(rating:intervalText:action:)`, `StreakBadge(days:)`, `StatTile(value:label:tint:)`, `PlanTaskRow(task:isHighlighted:onStart:)`
  - `enum PlanTaskText { static func title(_ task: PlanTask) -> String; static func subtitle(_ task: PlanTask) -> String; static func minutes(_ value: Double) -> Int }`

- [ ] **Step 1: Write the failing tests**

`App/Tests/EnglishAppTests/DesignSystemTests.swift`:

```swift
import XCTest
@testable import EnglishApp
import LearningEngine

final class DesignSystemTests: XCTestCase {
    func test_rgb_parsesHex() {
        let c = Theme.rgb(0x0F766E)
        XCTAssertEqual(c.r, 15.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.g, 118.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.b, 110.0 / 255, accuracy: 1e-9)
    }

    func test_skillDisplayNames_areTurkish() {
        XCTAssertEqual(Skill.allCases.map(\.displayName),
                       ["Kelime", "Gramer", "Okuma", "Dinleme", "Yazma", "Konuşma", "Telaffuz"])
    }

    func test_ratingLabels() {
        XCTAssertEqual([FSRSRating.again, .hard, .good, .easy].map(\.label),
                       ["Bilemedim", "Zorlandım", "Bildim", "Çok kolay"])
    }

    func test_planTaskText() {
        XCTAssertEqual(PlanTaskText.title(.review(cardCount: 14, minutes: 5.6, isDone: false)), "Kelime tekrarı")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: false)), "14 kart · 6 dk")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: true)), "14 kart · bitti")
        XCTAssertEqual(PlanTaskText.title(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "Science · 2")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "Yeni ders · Kelime · 8 dk")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "x", skill: .grammar, minutes: 10, isDone: true)), "Gramer · bitti")
        XCTAssertEqual(PlanTaskText.title(.locked(id: "l", title: "Law · 1")), "Law · 1")
        XCTAssertEqual(PlanTaskText.subtitle(.locked(id: "l", title: "Law · 1")), "Paketi aç")
    }

    func test_minutes_roundUp() {
        XCTAssertEqual(PlanTaskText.minutes(0.4), 1)
        XCTAssertEqual(PlanTaskText.minutes(8), 8)
        XCTAssertEqual(PlanTaskText.minutes(21.2), 22)
    }
}
```

- [ ] **Step 2: Verify the tests would fail**

None of these symbols exist. Do not push.

- [ ] **Step 3: Implement**

`DesignSystem/Theme.swift`:

```swift
import SwiftUI
import UIKit

/// Color roles for the "academic and focused" direction. Every role has a
/// light and a dark value; views only ever use these roles.
enum Theme {
    static let paper = dynamic(light: 0xFBF8F2, dark: 0x151A1C)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1E2527)
    static let border = dynamic(light: 0xE7E1D6, dark: 0x2E3739)
    static let ink = dynamic(light: 0x1F2A2E, dark: 0xEEF2F1)
    static let secondaryInk = dynamic(light: 0x6B7280, dark: 0x9CA3AF)
    static let primary = dynamic(light: 0x0F766E, dark: 0x2DD4BF)
    static let accent = dynamic(light: 0xEA580C, dark: 0xFB923C)
    static let danger = dynamic(light: 0xB91C1C, dark: 0xF87171)
    static let reading = fixed(0x3B82F6)
    static let listening = fixed(0x7C3AED)
    static let writing = fixed(0x0891B2)
    static let speaking = fixed(0xDB2777)
    static let pronunciation = fixed(0x65A30D)

    static func rgb(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            uiColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func fixed(_ hex: UInt32) -> Color {
        Color(uiColor(hex))
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        let c = rgb(hex)
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}

extension Font {
    /// Serif (New York) title that still scales with Dynamic Type.
    static func serifTitle(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .serif).weight(.bold)
    }
}
```

`DesignSystem/SkillStyle.swift`:

```swift
import SwiftUI
import LearningEngine

extension Skill {
    var displayName: String {
        switch self {
        case .vocabulary: return "Kelime"
        case .grammar: return "Gramer"
        case .reading: return "Okuma"
        case .listening: return "Dinleme"
        case .writing: return "Yazma"
        case .speaking: return "Konuşma"
        case .pronunciation: return "Telaffuz"
        }
    }

    var color: Color {
        switch self {
        case .vocabulary: return Theme.primary
        case .grammar: return Theme.accent
        case .reading: return Theme.reading
        case .listening: return Theme.listening
        case .writing: return Theme.writing
        case .speaking: return Theme.speaking
        case .pronunciation: return Theme.pronunciation
        }
    }
}

extension FSRSRating {
    var label: String {
        switch self {
        case .again: return "Bilemedim"
        case .hard: return "Zorlandım"
        case .good: return "Bildim"
        case .easy: return "Çok kolay"
        }
    }

    var tint: Color {
        switch self {
        case .again: return Theme.danger
        case .hard: return Theme.accent
        case .good: return Theme.primary
        case .easy: return Theme.reading
        }
    }
}
```

`DesignSystem/Components.swift`:

```swift
import SwiftUI
import LearningEngine

struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SkillBadge: View {
    let skill: Skill

    var body: some View {
        Text(skill.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(skill.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(skill.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule().fill(Theme.primary)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue("%\(Int((min(max(progress, 0), 1) * 100).rounded()))")
    }
}

struct RatingButton: View {
    let rating: FSRSRating
    let intervalText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(rating.label).font(.subheadline.weight(.semibold))
                Text(intervalText).font(.caption2)
                    .foregroundStyle(rating == .good ? Color.white.opacity(0.85) : Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(rating == .good ? Color.white : rating.tint)
            .background(rating == .good ? rating.tint : rating.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(rating.tint.opacity(rating == .good ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rating.label), sonraki tekrar \(intervalText)")
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        Label("\(days) gün", systemImage: "flame.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .accessibilityLabel("\(days) günlük seri")
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.ink

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

#Preview("Components · light") {
    ComponentsPreview().preferredColorScheme(.light)
}

#Preview("Components · dark") {
    ComponentsPreview().preferredColorScheme(.dark)
}

private struct ComponentsPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("hypothesis").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
                HStack { SkillBadge(skill: .vocabulary); SkillBadge(skill: .grammar); SkillBadge(skill: .reading) }
                ProgressBar(progress: 0.3)
                PaperCard { Text("Kâğıt kart").foregroundStyle(Theme.ink) }
                HStack(spacing: 6) {
                    RatingButton(rating: .again, intervalText: "1 gün") {}
                    RatingButton(rating: .hard, intervalText: "1 gün") {}
                    RatingButton(rating: .good, intervalText: "3 gün") {}
                    RatingButton(rating: .easy, intervalText: "9 gün") {}
                }
                HStack { StatTile(value: "10", label: "kelime"); StatTile(value: "%80", label: "bildim", tint: Theme.primary); StatTile(value: "12", label: "gün seri", tint: Theme.accent) }
                StreakBadge(days: 12)
                Button("Başla") {}.buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Theme.paper)
    }
}
```

`DesignSystem/PlanTaskRow.swift`:

```swift
import SwiftUI
import LearningEngine

enum PlanTaskText {
    static func minutes(_ value: Double) -> Int { Int(value.rounded(.up)) }

    static func title(_ task: PlanTask) -> String {
        switch task {
        case .review: return "Kelime tekrarı"
        case .lesson(_, let title, _, _, _), .locked(_, let title): return title
        }
    }

    static func subtitle(_ task: PlanTask) -> String {
        switch task {
        case .review(let count, let minutes, let isDone):
            return isDone ? "\(count) kart · bitti" : "\(count) kart · \(self.minutes(minutes)) dk"
        case .lesson(_, _, let skill, let minutes, let isDone):
            return isDone ? "\(skill.displayName) · bitti" : "Yeni ders · \(skill.displayName) · \(self.minutes(minutes)) dk"
        case .locked:
            return "Paketi aç"
        }
    }
}

struct PlanTaskRow: View {
    let task: PlanTask
    let isHighlighted: Bool
    let onStart: () -> Void

    private var isDone: Bool {
        switch task {
        case .review(_, _, let done), .lesson(_, _, _, _, let done): return done
        case .locked: return false
        }
    }

    private var isLocked: Bool {
        if case .locked = task { return true } else { return false }
    }

    private var iconName: String {
        if isDone { return "checkmark" }
        switch task {
        case .review: return "arrow.triangle.2.circlepath"
        case .lesson: return "text.book.closed"
        case .locked: return "lock.fill"
        }
    }

    private var tint: Color {
        switch task {
        case .review: return Theme.primary
        case .lesson(_, _, let skill, _, _): return skill.color
        case .locked: return Theme.secondaryInk
        }
    }

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? .white : tint)
                    .frame(width: 34, height: 34)
                    .background(isDone ? Theme.primary : tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(PlanTaskText.title(task))
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone || isLocked ? Theme.secondaryInk : Theme.ink)
                    Text(PlanTaskText.subtitle(task))
                        .font(.caption)
                        .foregroundStyle(isLocked ? Theme.accent : Theme.secondaryInk)
                }
                Spacer(minLength: 8)
                if isHighlighted && !isDone && !isLocked {
                    Text("Başla")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(isLocked ? Theme.paper : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHighlighted && !isDone ? Theme.primary : Theme.border,
                            style: StrokeStyle(lineWidth: isHighlighted && !isDone ? 1.5 : 1, dash: isLocked ? [5] : []))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDone)
    }
}

#Preview("Plan rows") {
    VStack(spacing: 8) {
        PlanTaskRow(task: .review(cardCount: 14, minutes: 5.6, isDone: true), isHighlighted: false) {}
        PlanTaskRow(task: .lesson(id: "a", title: "Science & Research Methods · 2", skill: .vocabulary, minutes: 8, isDone: false), isHighlighted: true) {}
        PlanTaskRow(task: .locked(id: "b", title: "Law, Policy & Society · 1"), isHighlighted: false) {}
    }
    .padding()
    .background(Theme.paper)
}
```

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add design system tokens and components` (plus trailers).

```bash
git add App/Sources/EnglishApp/DesignSystem App/Tests/EnglishAppTests/DesignSystemTests.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green; `DesignSystemTests` pass (the previews compile as part of the build).

---

### Task 7: Study session logic

**Files:**
- Create: `App/Sources/EnglishApp/Study/RatingIntervalFormatter.swift`
- Create: `App/Sources/EnglishApp/Study/StudySessionViewModel.swift`
- Create: `App/Tests/EnglishAppTests/StudySessionViewModelTests.swift`

**Interfaces:**
- Consumes: `TodaySessionCoordinator.buildTodaySession()` (Task 5), `LessonProgress` (Task 3), `FSRSStateStore`, `FSRSScheduler`, `TestPackageJSON` + `ContentSeeder` (tests, Task 5).
- Produces:
  - `enum RatingIntervalFormatter { static func text(from now: Date, to due: Date, calendar: Calendar = .current) -> String }`
  - `@MainActor @Observable final class StudySessionViewModel` with:
    - `enum Mode: Equatable { case review(cardCount: Int); case lesson(id: String) }`
    - `struct Card: Equatable, Identifiable { id: String /* itemID */; headword; definition; exampleSentence: String?; translationTR; collocations: [String]; skill: Skill }`
    - `struct Summary: Equatable { title: String; subtitle: String?; cardCount: Int; knownShare: Double; needsReview: [String] }`
    - `init(mode: Mode, context: ModelContext, userID: String, scheduler: FSRSScheduler = FSRSScheduler(), clock: @escaping () -> Date = Date.init)`
    - `private(set) var cards: [Card]`, `currentIndex: Int`, `isRevealed: Bool`, `isFinished: Bool`, `saveError: String?`, `lessonTitle: String?`
    - `var current: Card?`, `var progress: Double`, `var progressText: String`, `var contextLine: String`
    - `func start() throws`, `func reveal()`, `func intervalTexts() -> [FSRSRating: String]`, `func rate(_ rating: FSRSRating)`, `func summary() -> Summary`, `func clearSaveError()`

Behaviour (spec §2.6):
- `.review(cardCount:)` → cards = `TodaySessionCoordinator(context:userID:sessionSize: cardCount, now: clock()).buildTodaySession()`.
- `.lesson(id:)` → the lesson's items sorted by `frequencyRank`, then `id`, skipping items that already have a `UserItemState` for this user. On `start()`, insert `LessonProgress` if none exists. If no items remain, mark the lesson complete and set `isFinished = true`.
- `rate(_:)` saves through `FSRSStateStore.recordReview` (reaction time = time since the card was shown). On a thrown error: set `saveError`, keep the same card, do not advance. On success: remember the rating, advance, reset `isRevealed`; after the last card set `isFinished`, and in lesson mode set `completedAt` when every item of the lesson has a `UserItemState`.
- `intervalTexts()` runs `scheduler.review(card: <current card's stored FSRS state or nil>, rating:, now:)` for all four ratings without saving.
- `contextLine`: lesson → `"YENİ DERS · \(lessonTitle.uppercased(with: Locale(identifier: "tr_TR")))"`; review → `"TEKRAR"`.
- `summary()`: title `"Ders tamamlandı"` (lesson) or `"Tekrar tamamlandı"` (review); subtitle = lesson title or nil; `cardCount` = cards rated this session; `knownShare` = share rated `.good`/`.easy` (0 when none); `needsReview` = headwords rated `.again`, in card order.

- [ ] **Step 1: Write the failing tests**

`App/Tests/EnglishAppTests/StudySessionViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

@MainActor
final class StudySessionViewModelTests: XCTestCase {
    let userID = "u"
    var clockNow = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        return context
    }

    func makeVM(_ mode: StudySessionViewModel.Mode, _ context: ModelContext) -> StudySessionViewModel {
        StudySessionViewModel(mode: mode, context: context, userID: userID, clock: { [unowned self] in self.clockNow })
    }

    func progressRow(_ context: ModelContext, _ lessonID: String) throws -> LessonProgress? {
        let id = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        return try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == id })).first
    }

    func test_lessonStart_loadsItemsInOrder_andCreatesProgress() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()

        XCTAssertEqual(vm.cards.map(\.id), ["item-u0-l0-i0", "item-u0-l0-i1"])
        XCTAssertEqual(vm.progressText, "1/2")
        XCTAssertEqual(vm.contextLine, "YENİ DERS · UNIT 0 · 1")
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0"))
        XCTAssertNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_ratingEveryCard_finishesAndCompletesLesson_withSummary() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()

        vm.reveal()
        XCTAssertTrue(vm.isRevealed)
        vm.rate(.good)
        XCTAssertFalse(vm.isRevealed)
        XCTAssertEqual(vm.progressText, "2/2")
        vm.reveal()
        vm.rate(.again)

        XCTAssertTrue(vm.isFinished)
        XCTAssertEqual(try progressRow(context, "lesson-u0-l0")?.completedAt, clockNow)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 2)
        XCTAssertEqual(vm.summary(), .init(title: "Ders tamamlandı", subtitle: "Unit 0 · 1", cardCount: 2, knownShare: 0.5, needsReview: ["word001"]))
    }

    func test_reenteringALesson_resumesAtFirstUnratedItem() throws {
        let context = try makeContext()
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .good, now: clockNow, in: context, scheduler: FSRSScheduler())

        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        XCTAssertEqual(vm.cards.map(\.id), ["item-u0-l0-i1"])
        vm.rate(.good)
        XCTAssertTrue(vm.isFinished)
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_leavingEarly_keepsRatings_andLessonStaysIncomplete() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        vm.rate(.good)

        XCTAssertFalse(vm.isFinished)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 1)
        XCTAssertNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_lessonWithNothingLeft_finishesImmediately() throws {
        let context = try makeContext()
        for i in 0..<2 {
            try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i\(i)", rating: .good, now: clockNow, in: context, scheduler: FSRSScheduler())
        }
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        XCTAssertTrue(vm.isFinished)
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_reviewMode_loadsOnlyDueSeenItems() throws {
        let context = try makeContext()
        let threeDaysAgo = clockNow.addingTimeInterval(-3 * 86_400)
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u1-l0-i0", rating: .again, now: threeDaysAgo, in: context, scheduler: FSRSScheduler())

        let vm = makeVM(.review(cardCount: 10), context)
        try vm.start()
        XCTAssertEqual(vm.cards.map(\.id), ["item-u1-l0-i0"])
        XCTAssertEqual(vm.contextLine, "TEKRAR")
        vm.rate(.good)
        XCTAssertEqual(vm.summary().title, "Tekrar tamamlandı")
        XCTAssertNil(vm.summary().subtitle)
    }

    func test_intervalTexts_coverAllRatings_andNewCardAgainIsOneDay() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        let texts = vm.intervalTexts()
        XCTAssertEqual(Set(texts.keys), Set([FSRSRating.again, .hard, .good, .easy]))
        XCTAssertEqual(texts[.again], "1 gün")
    }

    func test_intervalFormatter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 22))!
        func plus(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: now)! }
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: now, calendar: calendar), "1 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(1), calendar: calendar), "1 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(25), calendar: calendar), "25 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(60), calendar: calendar), "2 ay")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(400), calendar: calendar), "1 yıl")
    }
}
```

(`word001` is the headword of `item-u0-l0-i1` in `TestPackageJSON`: `"word\(u)\(l)\(i)"`.)

- [ ] **Step 2: Verify the tests would fail**

`StudySessionViewModel` and `RatingIntervalFormatter` do not exist. Do not push.

- [ ] **Step 3: Implement**

`Study/RatingIntervalFormatter.swift`:

```swift
import Foundation

enum RatingIntervalFormatter {
    /// Calendar-day distance as Turkish text. The FSRS engine never schedules
    /// under a day, so the minimum shown is "1 gün".
    static func text(from now: Date, to due: Date, calendar: Calendar = .current) -> String {
        let days = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 1, 1)
        if days < 30 { return "\(days) gün" }
        if days < 365 { return "\(days / 30) ay" }
        return "\(days / 365) yıl"
    }
}
```

`Study/StudySessionViewModel.swift`:

```swift
import Foundation
import Observation
import SwiftData
import LearningEngine

@MainActor
@Observable
final class StudySessionViewModel {
    enum Mode: Equatable {
        case review(cardCount: Int)
        case lesson(id: String)
    }

    struct Card: Equatable, Identifiable {
        let id: String
        let headword: String
        let definition: String
        let exampleSentence: String?
        let translationTR: String
        let collocations: [String]
        let skill: Skill
    }

    struct Summary: Equatable {
        let title: String
        let subtitle: String?
        let cardCount: Int
        let knownShare: Double
        let needsReview: [String]
    }

    let mode: Mode
    private(set) var cards: [Card] = []
    private(set) var currentIndex = 0
    private(set) var isRevealed = false
    private(set) var isFinished = false
    private(set) var saveError: String?
    private(set) var lessonTitle: String?

    private let context: ModelContext
    private let userID: String
    private let scheduler: FSRSScheduler
    private let clock: () -> Date
    private var ratings: [(cardID: String, rating: FSRSRating)] = []
    private var lessonItemIDs: [String] = []
    private var cardShownAt = Date()

    init(mode: Mode, context: ModelContext, userID: String, scheduler: FSRSScheduler = FSRSScheduler(), clock: @escaping () -> Date = Date.init) {
        self.mode = mode
        self.context = context
        self.userID = userID
        self.scheduler = scheduler
        self.clock = clock
    }

    var current: Card? { currentIndex < cards.count ? cards[currentIndex] : nil }

    var progress: Double { cards.isEmpty ? 0 : Double(currentIndex) / Double(cards.count) }

    var progressText: String { "\(min(currentIndex + 1, cards.count))/\(cards.count)" }

    var contextLine: String {
        switch mode {
        case .review: return "TEKRAR"
        case .lesson: return "YENİ DERS · \((lessonTitle ?? "").uppercased(with: Locale(identifier: "tr_TR")))"
        }
    }

    func start() throws {
        switch mode {
        case .review(let cardCount):
            let items = try TodaySessionCoordinator(context: context, userID: userID, sessionSize: cardCount, now: clock()).buildTodaySession()
            cards = items.compactMap(Self.card)

        case .lesson(let lessonID):
            guard let lesson = try context.fetch(FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonID })).first else {
                isFinished = true
                return
            }
            lessonTitle = lesson.title
            let ordered = lesson.items.sorted { ($0.frequencyRank, $0.id) < ($1.frequencyRank, $1.id) }
            lessonItemIDs = ordered.map(\.id)
            let seen = try seenItemIDs()
            cards = ordered.filter { !seen.contains($0.id) }.compactMap(Self.card)

            let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
            if try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).isEmpty {
                context.insert(LessonProgress(userID: userID, lessonID: lessonID, startedAt: clock()))
                try context.save()
            }
        }
        currentIndex = 0
        isRevealed = false
        cardShownAt = clock()
        if cards.isEmpty { try finish() }
    }

    func reveal() { isRevealed = true }

    func clearSaveError() { saveError = nil }

    func intervalTexts() -> [FSRSRating: String] {
        guard let card = current else { return [:] }
        let now = clock()
        let prior = try? storedCard(for: card.id)
        var texts: [FSRSRating: String] = [:]
        for rating in FSRSRating.allCases {
            let result = scheduler.review(card: prior ?? nil, rating: rating, now: now)
            texts[rating] = RatingIntervalFormatter.text(from: now, to: result.dueDate)
        }
        return texts
    }

    func rate(_ rating: FSRSRating) {
        guard let card = current else { return }
        let now = clock()
        do {
            try FSRSStateStore().recordReview(
                userID: userID, itemID: card.id, rating: rating, now: now, in: context,
                scheduler: scheduler, reactionTimeMs: Int(now.timeIntervalSince(cardShownAt) * 1000)
            )
        } catch {
            saveError = error.localizedDescription
            return
        }
        ratings.append((card.id, rating))
        currentIndex += 1
        isRevealed = false
        cardShownAt = now
        if currentIndex >= cards.count {
            do { try finish() } catch { saveError = error.localizedDescription }
        }
    }

    func summary() -> Summary {
        let known = ratings.filter { $0.rating == .good || $0.rating == .easy }.count
        let againIDs = Set(ratings.filter { $0.rating == .again }.map(\.cardID))
        let isLesson: Bool
        if case .lesson = mode { isLesson = true } else { isLesson = false }
        return Summary(
            title: isLesson ? "Ders tamamlandı" : "Tekrar tamamlandı",
            subtitle: isLesson ? lessonTitle : nil,
            cardCount: ratings.count,
            knownShare: ratings.isEmpty ? 0 : Double(known) / Double(ratings.count),
            needsReview: cards.filter { againIDs.contains($0.id) }.map(\.headword)
        )
    }

    private func finish() throws {
        isFinished = true
        guard case .lesson(let lessonID) = mode else { return }
        let seen = try seenItemIDs()
        guard lessonItemIDs.allSatisfy(seen.contains) else { return }
        let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        if let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first,
           progress.completedAt == nil {
            progress.completedAt = clock()
            try context.save()
        }
    }

    private func seenItemIDs() throws -> Set<String> {
        let userIDValue = userID
        return Set(try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue })).map(\.itemID))
    }

    private func storedCard(for itemID: String) throws -> FSRSCard? {
        let stateID = "\(userID)_\(itemID)"
        guard let state = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.id == stateID })).first else { return nil }
        return FSRSCard(stability: state.stability, difficulty: state.difficulty, reps: state.reps, lapses: state.lapses, lastReviewedAt: state.lastReviewedAt)
    }

    private static func card(from item: LearningItem) -> Card? {
        guard let content = item.content else { return nil }
        return Card(
            id: item.id, headword: content.headword, definition: content.definition,
            exampleSentence: content.exampleSentences.first, translationTR: content.translationTR,
            collocations: content.collocations, skill: Skill.forItemType(item.type)
        )
    }
}
```

(`UserItemState`'s ID format `"\(userID)_\(itemID)"` comes from `UserItemState.init`.)

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add study session view model and interval formatter` (plus trailers).

```bash
git add App/Sources/EnglishApp/Study App/Tests/EnglishAppTests/StudySessionViewModelTests.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green; all `StudySessionViewModelTests` pass.

---

### Task 8: Study session screen and summary

**Files:**
- Create: `App/Sources/EnglishApp/Study/StudySessionView.swift`
- Create: `App/Sources/EnglishApp/Study/StudyCardView.swift`
- Create: `App/Sources/EnglishApp/Study/StudySummaryView.swift`

(The new summary is named `StudySummaryView` so the old `Today/SessionSummaryView.swift`, still used by `TodayView`, keeps compiling until Task 9 deletes both.)

**Interfaces:**
- Consumes: `StudySessionViewModel` (Task 7), design-system views (Task 6), `TodayPlanCoordinator.streak()` (Task 5), `AppState.isTutorAvailable`, `.tutorEngine`, `.loadTutorEngineIfNeeded()`, `.accessProvider`, `TutorSheetView(engine:context:)`, `TutorViewModel.TutorContext(headword:definition:exampleSentences:translationTR:)`, `UserIdentity.current`.
- Produces: `StudySessionView(mode: StudySessionViewModel.Mode, onClose: @escaping () -> Void)`; `StudySummaryView(summary: StudySessionViewModel.Summary, streak: Int, onDone: @escaping () -> Void)`; `StudyCardView(card:isRevealed:showsTutorButton:isLoadingTutor:onTutor:)`.

This task is view composition over logic already covered by `StudySessionViewModelTests`. It adds no unit tests; its gate is the App Build (compiles, existing tests stay green) plus light and dark `#Preview`s.

- [ ] **Step 1: Card view**

`Study/StudyCardView.swift`:

```swift
import SwiftUI
import LearningEngine

/// Front shows only the headword; back shows meaning, example and
/// collocations. Flips in 3D, or cross-fades when Reduce Motion is on.
struct StudyCardView: View {
    let card: StudySessionViewModel.Card
    let isRevealed: Bool
    let showsTutorButton: Bool
    let isLoadingTutor: Bool
    let onTutor: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            front
                .opacity(isRevealed ? 0 : 1)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (isRevealed ? 180 : 0)), axis: (x: 0, y: 1, z: 0))
            back
                .opacity(isRevealed ? 1 : 0)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (isRevealed ? 0 : -180)), axis: (x: 0, y: 1, z: 0))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45), value: isRevealed)
    }

    private var front: some View {
        VStack(spacing: 12) {
            SkillBadge(skill: card.skill)
            Text(card.headword)
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Anlamını hatırlamaya çalış")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
        .background(cardBackground)
    }

    private var back: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.headword).font(.serifTitle(.title)).foregroundStyle(Theme.ink)
                    Spacer()
                    if showsTutorButton {
                        Button(action: onTutor) {
                            if isLoadingTutor {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles").font(.title3).foregroundStyle(Theme.primary)
                            }
                        }
                        .disabled(isLoadingTutor)
                        .accessibilityLabel("Öğretmene sor")
                    }
                }
                Text(card.translationTR).font(.headline).foregroundStyle(Theme.primary)
                Text(card.definition).font(.body).foregroundStyle(Theme.ink)
                if let example = card.exampleSentence {
                    sectionLabel("ÖRNEK")
                    Text("“\(example)”")
                        .font(.callout.italic())
                        .foregroundStyle(Theme.ink)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 2) }
                }
                if !card.collocations.isEmpty {
                    sectionLabel("BİRLİKTE KULLANIM")
                    FlowChips(items: card.collocations)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(cardBackground)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk).padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

/// Wrapping row of small chips (collocations).
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.caption)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview("Card back · light") {
    StudyCardView(
        card: .init(id: "i", headword: "hypothesis", definition: "A proposed explanation made on the basis of limited evidence.",
                    exampleSentence: "The researchers tested the hypothesis that sleep improves memory.",
                    translationTR: "hipotez, varsayım", collocations: ["test a hypothesis", "support a hypothesis"], skill: .vocabulary),
        isRevealed: true, showsTutorButton: true, isLoadingTutor: false, onTutor: {}
    )
    .padding().background(Theme.paper).preferredColorScheme(.light)
}

#Preview("Card front · dark") {
    StudyCardView(
        card: .init(id: "i", headword: "hypothesis", definition: "d", exampleSentence: nil, translationTR: "hipotez", collocations: [], skill: .vocabulary),
        isRevealed: false, showsTutorButton: false, isLoadingTutor: false, onTutor: {}
    )
    .padding().background(Theme.paper).preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Summary view**

`Study/StudySummaryView.swift`:

```swift
import SwiftUI

struct StudySummaryView: View {
    let summary: StudySessionViewModel.Summary
    let streak: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(.largeTitle).weight(.bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primary.opacity(0.15), in: Circle())
            Text(summary.title).font(.serifTitle(.title)).foregroundStyle(Theme.ink)
            if let subtitle = summary.subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }
            HStack(spacing: 8) {
                StatTile(value: "\(summary.cardCount)", label: "kart")
                StatTile(value: "%\(Int((summary.knownShare * 100).rounded()))", label: "bildim", tint: Theme.primary)
                StatTile(value: "\(streak)", label: "gün seri", tint: Theme.accent)
            }
            .padding(.top, 8)
            if !summary.needsReview.isEmpty {
                PaperCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEKRAR ETMEN GEREKENLER").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk)
                        Text(summary.needsReview.joined(separator: " · ")).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                }
            }
            Spacer()
            Button("Plana dön", action: onDone).buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Theme.paper.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: summary.cardCount)
    }
}

#Preview("Summary") {
    StudySummaryView(
        summary: .init(title: "Ders tamamlandı", subtitle: "Science & Research Methods · 2", cardCount: 10, knownShare: 0.8, needsReview: ["empirical", "variable"]),
        streak: 12, onDone: {}
    )
}
```

- [ ] **Step 3: Session view**

`Study/StudySessionView.swift`:

```swift
import SwiftUI
import SwiftData
import LearningEngine
import TutorEngine

struct StudySessionView: View {
    let mode: StudySessionViewModel.Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage("hint.ratingExplained") private var ratingHintShown = false

    @State private var viewModel: StudySessionViewModel?
    @State private var loadError: String?
    @State private var streak = 0
    @State private var isLoadingTutor = false
    @State private var showTutorSheet = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Oturum açılamadı", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let viewModel {
                if viewModel.isFinished {
                    StudySummaryView(summary: viewModel.summary(), streak: streak, onDone: onClose)
                        .task { streak = (try? planCoordinator.streak()) ?? 0 }
                } else {
                    session(viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .task { start() }
    }

    private var planCoordinator: TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
    }

    private func start() {
        guard viewModel == nil else { return }
        let vm = StudySessionViewModel(mode: mode, context: context, userID: UserIdentity.current)
        do {
            try vm.start()
            viewModel = vm
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func session(_ vm: StudySessionViewModel) -> some View {
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

            if let card = vm.current {
                StudyCardView(
                    card: card, isRevealed: vm.isRevealed,
                    showsTutorButton: appState.isTutorAvailable, isLoadingTutor: isLoadingTutor,
                    onTutor: { Task { await openTutor() } }
                )
                .onTapGesture { if !vm.isRevealed { vm.reveal() } }
                .sheet(isPresented: $showTutorSheet) {
                    if let engine = appState.tutorEngine {
                        TutorSheetView(engine: engine, context: .init(
                            headword: card.headword, definition: card.definition,
                            exampleSentences: card.exampleSentence.map { [$0] } ?? [],
                            translationTR: card.translationTR
                        ))
                    }
                }
            }

            Spacer(minLength: 0)

            if vm.isRevealed {
                if !ratingHintShown {
                    Text("Kelimeyi ne kadar iyi bildiğini seç. Uygulama bir sonraki tekrar zamanını buna göre ayarlar.")
                        .font(.footnote)
                        .foregroundStyle(Color.white)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { ratingHintShown = true }
                }
                let intervals = vm.intervalTexts()
                HStack(spacing: 6) {
                    ForEach(FSRSRating.allCases, id: \.self) { rating in
                        RatingButton(rating: rating, intervalText: intervals[rating] ?? "") {
                            ratingHintShown = true
                            vm.rate(rating)
                        }
                    }
                }
            } else {
                Button("Cevabı göster") { vm.reveal() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .sensoryFeedback(.selection, trigger: vm.currentIndex)
        .alert(
            "Puan kaydedilemedi",
            isPresented: Binding(get: { vm.saveError != nil }, set: { if !$0 { vm.clearSaveError() } }),
            presenting: vm.saveError
        ) { _ in
            Button("Tamam", role: .cancel) { vm.clearSaveError() }
        } message: { message in
            Text(message)
        }
    }

    /// Same single-flight rule as before: AppState dedupes concurrent loads.
    private func openTutor() async {
        guard !isLoadingTutor else { return }
        if appState.tutorEngine == nil {
            isLoadingTutor = true
            await appState.loadTutorEngineIfNeeded()
            isLoadingTutor = false
        }
        if appState.tutorEngine != nil { showTutorSheet = true }
    }
}
```

`FSRSRating.allCases` is declared `.again, .hard, .good, .easy` (raw values 1–4), which is exactly the required button order.

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Add redesigned study session screen and summary` (plus trailers).

```bash
git add App/Sources/EnglishApp/Study/StudySessionView.swift App/Sources/EnglishApp/Study/StudyCardView.swift App/Sources/EnglishApp/Study/StudySummaryView.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green (new views compile; all existing tests pass). The screen is not reachable from the tab bar until Task 9.

---

### Task 9: Today plan screen, Profile, tabs and localization

**Files:**
- Create: `App/Sources/EnglishApp/Today/PlanTaskAction.swift`
- Create: `App/Sources/EnglishApp/Today/TodayPlanView.swift`
- Create: `App/Sources/EnglishApp/Profile/ProfileView.swift`
- Create: `App/Sources/EnglishApp/Resources/Localizable.xcstrings`
- Modify: `App/Sources/EnglishApp/RootTabView.swift`
- Modify: `App/project.yml` (development language)
- Delete: `App/Sources/EnglishApp/Today/TodayView.swift`, `App/Sources/EnglishApp/Today/SessionSummaryView.swift`, `App/Sources/EnglishApp/Settings/SettingsView.swift`
- Create: `App/Tests/EnglishAppTests/PlanTaskActionTests.swift`

**Interfaces:**
- Consumes: `TodayPlanCoordinator` + `LearnerStats` (Task 5), `DailyPlan`/`PlanTask`/`SkillBalance` (Task 4), design system (Task 6), `StudySessionView` (Task 8), `DevelopmentPackageAccessProvider.unlockAllKey` (Task 5), `AppModelContainer.containerCreationError`, `AppModelContainer.seedRealContentIfNeeded(in:)`, `AppState.dataGeneration`/`bumpDataGeneration()`, `learningEngineVersion` (LearningEngine).
- Produces: `enum PlanTaskAction: Equatable { case startReview(cardCount: Int); case startLesson(id: String); case comingSoon(title: String); case locked(title: String); case none }` with `static func action(for task: PlanTask) -> PlanTaskAction`; `TodayPlanView`; `ProfileView`.

- [ ] **Step 1: Write the failing test**

`App/Tests/EnglishAppTests/PlanTaskActionTests.swift`:

```swift
import XCTest
@testable import EnglishApp
import LearningEngine

final class PlanTaskActionTests: XCTestCase {
    func test_actions() {
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: false)), .startReview(cardCount: 12))
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: false)), .startLesson(id: "l1"))
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "g1", title: "Tenses II", skill: .grammar, minutes: 10, isDone: false)), .comingSoon(title: "Tenses II"))
        XCTAssertEqual(PlanTaskAction.action(for: .locked(id: "x", title: "Law · 1")), .locked(title: "Law · 1"))
    }
}
```

- [ ] **Step 2: Verify it would fail**

`PlanTaskAction` does not exist. Do not push.

- [ ] **Step 3: Implement**

`Today/PlanTaskAction.swift`:

```swift
import Foundation
import LearningEngine

/// What tapping a plan row does. Only vocabulary lessons have a lesson
/// screen in 6a; other lesson skills arrive with their content (Slice 7).
enum PlanTaskAction: Equatable {
    case startReview(cardCount: Int)
    case startLesson(id: String)
    case comingSoon(title: String)
    case locked(title: String)
    case none

    static func action(for task: PlanTask) -> PlanTaskAction {
        switch task {
        case .review(let count, _, let isDone):
            return isDone ? .none : .startReview(cardCount: count)
        case .lesson(let id, let title, let skill, _, let isDone):
            if isDone { return .none }
            return skill == .vocabulary ? .startLesson(id: id) : .comingSoon(title: title)
        case .locked(_, let title):
            return .locked(title: title)
        }
    }
}
```

`Today/TodayPlanView.swift`:

```swift
import SwiftUI
import SwiftData
import LearningEngine

struct TodayPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    private struct ActiveSession: Identifiable {
        let id = UUID()
        let mode: StudySessionViewModel.Mode
    }

    private enum LoadState { case loading, noContent, failed(String), ready(DailyPlan) }

    @State private var loadState: LoadState = .loading
    @State private var stats: LearnerStats?
    @State private var activeSession: ActiveSession?
    @State private var infoMessage: (title: String, body: String)?

    var body: some View {
        NavigationStack {
            ScrollView {
                content.padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .fullScreenCover(item: $activeSession) { session in
            StudySessionView(mode: session.mode) {
                activeSession = nil
                refresh()
            }
        }
        .alert(infoMessage?.title ?? "", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("Tamam", role: .cancel) { infoMessage = nil }
        } message: {
            Text(infoMessage?.body ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        case .noContent:
            ContentUnavailableView("İçerik yüklenemedi", systemImage: "books.vertical", description: Text("Profil sekmesindeki depolama uyarısına bak."))
        case .failed(let message):
            ContentUnavailableView("Plan hazırlanamadı", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready(let plan):
            planContent(plan)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: DailyPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text((stats?.packageName ?? "").uppercased(with: Locale(identifier: "tr_TR")))
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.primary)
                Spacer()
                StreakBadge(days: stats?.streak ?? 0)
            }
            Text("Bugünün planı").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

            let actionable = plan.tasks.filter { if case .locked = $0 { return false } else { return true } }
            if plan.tasks.isEmpty || plan.isComplete {
                PaperCard {
                    Label("Bugünlük hepsi bu", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.primary)
                }
            } else {
                Text("\(actionable.count) görev · yaklaşık \(PlanTaskText.minutes(plan.totalMinutes)) dk")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            let highlightIndex = plan.tasks.firstIndex { PlanTaskAction.action(for: $0) != .none && !isLocked($0) }
            ForEach(Array(plan.tasks.enumerated()), id: \.offset) { index, task in
                PlanTaskRow(task: task, isHighlighted: index == highlightIndex) { handle(task) }
            }

            if !plan.weeklyBalance.isEmpty {
                Text("Bu hafta beceri dengesi").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryInk).padding(.top, 8)
                ForEach(plan.weeklyBalance, id: \.skill) { balance in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(balance.skill.displayName).font(.footnote).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("hedef %\(percent(balance.targetShare)) · %\(percent(balance.actualShare))")
                                .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                        }
                        ProgressBar(progress: balance.targetShare > 0 ? balance.actualShare / balance.targetShare : 0)
                    }
                }
            }
        }
    }

    private func isLocked(_ task: PlanTask) -> Bool {
        if case .locked = task { return true } else { return false }
    }

    private func percent(_ share: Double) -> Int { Int((share * 100).rounded()) }

    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startReview(let count): activeSession = ActiveSession(mode: .review(cardCount: count))
        case .startLesson(let id): activeSession = ActiveSession(mode: .lesson(id: id))
        case .comingSoon(let title): infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)
        case .none: break
        }
    }

    private func refresh() {
        let coordinator = TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
        do {
            guard let plan = try coordinator.buildPlan() else {
                loadState = .noContent
                return
            }
            stats = try coordinator.stats()
            loadState = .ready(plan)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
```

`Profile/ProfileView.swift` (replaces `SettingsView`, keeping its storage warning and reset flow; the reset now also clears learner models):

```swift
import SwiftUI
import SwiftData
import LearningEngine

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage(DevelopmentPackageAccessProvider.unlockAllKey) private var unlockAll = false
    @State private var stats: LearnerStats?
    @State private var showResetConfirmation = false
    @State private var resetError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profil").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

                section("HEDEFİM") {
                    row("Aktif paket", stats?.packageName ?? "—", tint: Theme.primary)
                    Divider()
                    row("Erişim", stats?.accessLevel == .owned ? "Tam sürüm" : "Önizleme", tint: Theme.accent)
                    Divider()
                    row("Günlük süre", "\(stats?.dailyMinutes ?? LearnerProfile.defaultDailyMinutes) dk")
                }

                section("İSTATİSTİK") {
                    HStack(spacing: 8) {
                        StatTile(value: "\(stats?.streak ?? 0)", label: "gün seri", tint: Theme.accent)
                        StatTile(value: "\(stats?.wordsSeen ?? 0)", label: "kelime")
                        StatTile(value: "\(stats?.completedLessons ?? 0)/\(stats?.totalLessons ?? 0)", label: "ders")
                    }
                }

                if let storageError = AppModelContainer.containerCreationError {
                    section("DEPOLAMA UYARISI") {
                        Text("Yerel depolama açılamadı ya da içerik yüklenemedi. İlerlemen bu oturumdan sonra kaydedilmeyebilir.")
                            .font(.subheadline).foregroundStyle(Theme.danger)
                        Text(storageError).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }

                section("GELİŞTİRİCİ") {
                    Toggle("Tüm paketleri aç", isOn: $unlockAll)
                        .tint(Theme.primary)
                        .onChange(of: unlockAll) { _, _ in appState.bumpDataGeneration() }
                    Divider()
                    Button("Yerel verileri sıfırla", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Theme.danger)
                }

                Text("Sürüm \(appVersion) · Motor \(learningEngineVersion)")
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear(perform: refresh)
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .alert("Tüm yerel veriler silinsin mi?", isPresented: $showResetConfirmation) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive, action: resetAllData)
        }
        .alert(
            "Veriler sıfırlanamadı",
            isPresented: Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } }),
            presenting: resetError
        ) { _ in
            Button("Tamam", role: .cancel) { resetError = nil }
        } message: { Text($0) }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk)
            PaperCard { VStack(alignment: .leading, spacing: 10) { content() } }
        }
    }

    private func row(_ label: String, _ value: String, tint: Color = Theme.secondaryInk) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).foregroundStyle(tint)
        }
        .font(.subheadline)
    }

    private func refresh() {
        stats = try? TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider).stats()
    }

    private func resetAllData() {
        do {
            try context.delete(model: ContentPackage.self)
            try context.delete(model: ReviewLog.self)
            try context.delete(model: UserItemState.self)
            try context.delete(model: LessonProgress.self)
            try context.delete(model: LearnerProfile.self)
            try context.save()
            AppModelContainer.seedRealContentIfNeeded(in: context)
            appState.bumpDataGeneration()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
```

`RootTabView.swift` (replace the whole file):

```swift
import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayPlanView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            if appState.isTutorAvailable {
                TutorTabView()
                    .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
            }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(Theme.primary)
    }
}
```

`Resources/Localizable.xcstrings` (Xcode fills entries on build; Turkish is the source language):

```json
{
  "sourceLanguage" : "tr",
  "strings" : {},
  "version" : "1.0"
}
```

`App/project.yml` — under the top-level `options:` add `developmentLanguage: tr`:

```yaml
options:
  bundleIdPrefix: com.niinova22.englishapp
  developmentLanguage: tr
  deploymentTarget:
    iOS: "17.0"
```

Delete the three replaced files:

```bash
git rm App/Sources/EnglishApp/Today/TodayView.swift App/Sources/EnglishApp/Today/SessionSummaryView.swift App/Sources/EnglishApp/Settings/SettingsView.swift
```

After deleting, search for leftovers: `grep -rn "TodayView()\|SettingsView\|SessionSummaryView(" App/` must print nothing (`TodayPlanView` matches are fine only if you search for `TodayView()` exactly as written).

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Replace Today and Settings with the daily plan and Profile screens` (plus trailers).

```bash
git add App/Sources/EnglishApp/Today/PlanTaskAction.swift App/Sources/EnglishApp/Today/TodayPlanView.swift App/Sources/EnglishApp/Profile App/Sources/EnglishApp/Resources/Localizable.xcstrings App/Sources/EnglishApp/RootTabView.swift App/project.yml App/Tests/EnglishAppTests/PlanTaskActionTests.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green; `PlanTaskActionTests` pass; no references to the deleted views remain. If XcodeGen or the build rejects the `.xcstrings` file, keep the Turkish literals, remove the catalog and `developmentLanguage` change, and report it as a concern (localization readiness is not a 6a blocker).

---

### Task 10: Tutor screens — new style and Turkish copy

**Files:**
- Modify (replace whole files): `App/Sources/EnglishApp/Tutor/TutorChatView.swift`, `App/Sources/EnglishApp/Tutor/TutorSheetView.swift`, `App/Sources/EnglishApp/Tutor/TutorTabView.swift`

**Interfaces:**
- Consumes: `ChatViewModel` (`messages`, `isLoading`, `send(_:)`, `retryLastMessage()`, `startNewChat()`), `TutorViewModel` (`state`: `.idle/.loading/.response(String)/.failure(String)`, `ask(_:)`, `ask(freeText:)`), quick actions `.simplerExplanation`, `.anotherExample`, `.compareToSimilarWords`, design system (Task 6).
- Produces: no new API. Behaviour is unchanged: same view-model calls, Send disabled while loading, Retry only on the last failed message, auto-scroll, tab-level load/retry. Only colors, components and copy change.

No unit tests (the view models are already covered by `ChatViewModelTests` and `TutorViewModelTests`, which stay unchanged). The gate is the App Build.

- [ ] **Step 1: Replace `TutorChatView.swift`**

```swift
import SwiftUI
import TutorEngine

struct TutorChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var draftText = ""

    init(engine: any TutorEngine) {
        _viewModel = State(initialValue: ChatViewModel(engine: engine))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Tutor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Yeni sohbet") { viewModel.startNewChat() }
                        .tint(Theme.primary)
                }
            }
        }
    }

    private static let bottomAnchorID = "TutorChatView.bottom"

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        Text("İngilizce ile ilgili her şeyi sorabilirsin.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                    }
                    if viewModel.isLoading {
                        ProgressView().tint(Theme.primary)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .padding()
            }
            // Keep the newest message and the loading indicator on screen
            // once the conversation is longer than one screen.
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollToBottom(proxy)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    private func messageRow(_ message: ChatViewModel.DisplayMessage) -> some View {
        HStack {
            if message.turn.role == .assistant {
                bubble(for: message)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble(for: message)
            }
        }
    }

    private func bubble(for message: ChatViewModel.DisplayMessage) -> some View {
        let isUser = message.turn.role == .user
        return VStack(alignment: .trailing, spacing: 4) {
            Text(message.turn.text)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .padding(12)
                .background(isUser ? Theme.primary.opacity(0.14) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isUser ? Color.clear : Theme.border, lineWidth: 1)
                )
            if message.failed {
                Label("Yanıt yok", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
                if message.id == viewModel.messages.last?.id, !viewModel.isLoading {
                    Button("Tekrar dene") { Task { await viewModel.retryLastMessage() } }
                        .font(.caption.weight(.semibold))
                        .tint(Theme.primary)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Öğretmenine sor...", text: $draftText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Button {
                let text = draftText
                draftText = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primary, in: Circle())
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            .opacity(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading ? 0.4 : 1)
            .accessibilityLabel("Gönder")
        }
        .padding()
        .background(Theme.paper)
    }
}
```

- [ ] **Step 2: Replace `TutorSheetView.swift`**

```swift
import SwiftUI
import TutorEngine

struct TutorSheetView: View {
    @State private var viewModel: TutorViewModel
    @State private var freeTextQuestion = ""
    @Environment(\.dismiss) private var dismiss

    init(engine: any TutorEngine, context: TutorViewModel.TutorContext) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: context))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickActionButtons
                    freeTextField
                    responseArea
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Öğretmene sor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickAction("Daha basit anlat") { await viewModel.ask(.simplerExplanation) }
            quickAction("Başka bir örnek ver") { await viewModel.ask(.anotherExample) }
            quickAction("Benzer kelimelerden farkı ne?") { await viewModel.ask(.compareToSimilarWords) }
        }
    }

    private func quickAction(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var freeTextField: some View {
        HStack(spacing: 8) {
            TextField("Bu kelime hakkında bir şey sor...", text: $freeTextQuestion)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Button("Sor") {
                let question = freeTextQuestion
                freeTextQuestion = ""
                Task { await viewModel.ask(freeText: question) }
            }
            .font(.subheadline.weight(.semibold))
            .tint(Theme.primary)
            .disabled(freeTextQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var responseArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().tint(Theme.primary)
        case .response(let text):
            PaperCard {
                Text(text).font(.body).foregroundStyle(Theme.ink)
            }
        case .failure(let message):
            Text("Yanıt alınamadı: \(message)")
                .font(.subheadline)
                .foregroundStyle(Theme.danger)
        }
    }
}
```

- [ ] **Step 3: Replace `TutorTabView.swift`**

```swift
import SwiftUI

/// Bridges "the shared tutor engine hasn't been loaded yet" to
/// `TutorChatView`, which always requires a real, already-loaded
/// engine (mirroring `TutorSheetView`'s existing pattern in the
/// card-scoped feature). Shown only when `AppState.isTutorAvailable`
/// is true (see `RootTabView`) — this view's own states are about
/// "available but not yet loaded" / "available but failed to load",
/// never about total unavailability, which is handled by hiding the
/// tab entirely one level up.
struct TutorTabView: View {
    @Environment(AppState.self) private var appState
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let engine = appState.tutorEngine {
                TutorChatView(engine: engine)
            } else if isLoading {
                ProgressView("Öğretmen yükleniyor...")
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                VStack(spacing: 12) {
                    if loadFailed {
                        Text("Öğretmen yüklenemedi.")
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Button("Öğretmeni yükle") { Task { await load() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 240)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        guard appState.tutorEngine == nil, !isLoading else { return }
        isLoading = true
        await appState.loadTutorEngineIfNeeded()
        isLoading = false
        loadFailed = appState.tutorEngine == nil
    }
}
```

- [ ] **Step 4: Commit and verify via CI**

Commit subject: `Restyle tutor screens with the design system and Turkish copy` (plus trailers).

```bash
git add App/Sources/EnglishApp/Tutor/TutorChatView.swift App/Sources/EnglishApp/Tutor/TutorSheetView.swift App/Sources/EnglishApp/Tutor/TutorTabView.swift
git commit
bash scripts/ci-app-build.sh
```

Expected: App Build green; `ChatViewModelTests` and `TutorViewModelTests` unchanged and passing.

---

## Spec coverage check (for the executor)

| Spec section | Task |
|---|---|
| §1.1 Skill, weights, item mapping | 1 |
| §1.2 Document fields, importer rejection, YDS package | 1, 2 |
| §1.3 LearnerProfile, LessonProgress, derived streak | 3, 5 |
| §1.4 Content versioning, rollback, user state preserved | 5 |
| §1.5 Access policy + provider + dev toggle | 3, 5, 9 |
| §2 Daily plan builder (all rules, output) | 4 |
| §2.4 History window | 5 |
| §2.5 Streak | 3, 5 |
| §2.6 Executing tasks (review, lesson, resume, coming soon, locked) | 5, 7, 8, 9 |
| §3.1 Design system | 6 |
| §3.2 Screens 1–5, Tutor restyle, tabs | 8, 9, 10 |
| §3.3 Turkish UI + String Catalog | 6–10, 9 |
| §4 Error handling table | 5, 7, 8, 9 |
| §5 Testing | 1–7, 9 |
