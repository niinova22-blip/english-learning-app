# Content Generation Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A JSON content-authoring format + `ContentImporter` in `LearningEngine`, and a real first content package (120 AWL academic words, fully authored) that the app seeds from instead of the `SampleContent` test fixture.

**Architecture:** Plain `Decodable` document structs + a `ContentImporter.importPackage(from:into:)` function build the exact same `@Model` object graph `SampleContent` builds by hand, just from JSON instead of Swift code. Content authoring (Tasks 2-5) is a different kind of work than the rest of this plan — the deliverable is well-written linguistic content in a JSON file, not code, and "testing" is schema validation, not behavior verification.

**Tech Stack:** Swift 5.10+, Foundation `Codable`, SwiftData (unchanged), no new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-13-content-pipeline-design.md`

## Global Constraints

- No changes to `LearningEngine`'s existing `@Model` types, FSRS scheduler, or `DailySessionBuilder` — this plan is additive only.
- `SampleContent` is untouched and stays `LearningEngine`'s internal test fixture.
- Test verification via `bash scripts/ci-test.sh` (LearningEngine) and `bash scripts/ci-app-build.sh` (App) — this machine still can't run Xcode/Swift locally.
- Every JSON field in the content format is required — a decode failure must throw, never silently produce a partial `LearningItem`.
- Content generation tasks (2-5) are content-authoring work, not code: the "testing" step for those tasks is JSON validity + word-count/id-uniqueness checks, not TDD.
- Commit after every task.

---

### Task 1: Content JSON document types + ContentImporter + unit tests

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`
- Create: `LearningEngine/Sources/LearningEngine/Import/ContentImporter.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`

**Interfaces:**
- Consumes: `ContentPackage`, `Unit`, `Lesson`, `LearningItem`, `ItemContent`, `LearningGoal`, `LearningItemType` (existing `LearningEngine` models)
- Produces: `ContentPackageDocument`, `UnitDocument`, `LessonDocument`, `LearningItemDocument` (Decodable structs), `ContentImportError` (enum), `ContentImporter.importPackage(from: Data, into: ModelContext) throws -> ContentPackage`

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`:

```swift
import XCTest
import SwiftData
@testable import LearningEngine

final class ContentImporterTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_importPackage_validJSON_buildsFullHierarchyWithWiredRelationships() throws {
        let json = """
        {
          "id": "test-package",
          "name": "Test Package",
          "goal": "yds",
          "levelLower": "B2",
          "levelUpper": "C1",
          "units": [
            {
              "id": "test-unit-1",
              "theme": "Test Theme",
              "order": 0,
              "lessons": [
                {
                  "id": "test-lesson-1",
                  "order": 0,
                  "estimatedDurationMinutes": 5,
                  "items": [
                    {
                      "id": "test-item-economy",
                      "type": "vocabulary",
                      "headword": "economy",
                      "frequencyRank": 100,
                      "baseDifficulty": 0.3,
                      "definition": "the system of production and trade",
                      "exampleSentences": ["The economy grew."],
                      "translationTR": "ekonomi",
                      "collocations": ["global economy"]
                    },
                    {
                      "id": "test-item-finance",
                      "type": "vocabulary",
                      "headword": "finance",
                      "frequencyRank": 101,
                      "baseDifficulty": 0.3,
                      "definition": "the management of money",
                      "exampleSentences": ["She works in finance."],
                      "translationTR": "finans",
                      "collocations": ["personal finance"]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: json, into: context)
        try context.save()

        XCTAssertEqual(package.goal, .yds)
        XCTAssertEqual(package.units.count, 1)
        let unit = package.units[0]
        XCTAssertEqual(unit.package?.id, package.id)
        let lesson = unit.lessons[0]
        XCTAssertEqual(lesson.unit?.id, unit.id)
        XCTAssertEqual(lesson.items.count, 2)
        for item in lesson.items {
            XCTAssertNotNil(item.content)
            XCTAssertEqual(item.lesson?.id, lesson.id)
            XCTAssertEqual(item.content?.item?.id, item.id)
        }
    }

    func test_importPackage_unrecognizedGoal_throwsInvalidGoal() throws {
        let json = """
        {"id":"p","name":"P","goal":"not-a-real-goal","levelLower":"B2","levelUpper":"C1","units":[]}
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.invalidGoal(let value) = error else {
                return XCTFail("expected invalidGoal, got \(error)")
            }
            XCTAssertEqual(value, "not-a-real-goal")
        }
    }

    func test_importPackage_unrecognizedItemType_throwsInvalidItemType() throws {
        let json = """
        {
          "id": "p", "name": "P", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "units": [{
            "id": "u", "theme": "T", "order": 0,
            "lessons": [{
              "id": "l", "order": 0, "estimatedDurationMinutes": 5,
              "items": [{
                "id": "i", "type": "not-a-real-type", "headword": "x", "frequencyRank": 1,
                "baseDifficulty": 0.1, "definition": "d", "exampleSentences": ["e"],
                "translationTR": "t", "collocations": []
              }]
            }]
          }]
        }
        """.data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.invalidItemType(let value) = error else {
                return XCTFail("expected invalidItemType, got \(error)")
            }
            XCTAssertEqual(value, "not-a-real-type")
        }
    }

    func test_importPackage_malformedJSON_throwsDecodingFailed() throws {
        let json = "{ this is not valid json".data(using: .utf8)!
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(try ContentImporter.importPackage(from: json, into: context)) { error in
            guard case ContentImportError.decodingFailed = error else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/ci-test.sh`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write `ContentDocuments.swift`**

```swift
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
}

public struct LessonDocument: Decodable {
    public let id: String
    public let order: Int
    public let estimatedDurationMinutes: Int
    public let items: [LearningItemDocument]
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
    public let units: [UnitDocument]
}
```

- [ ] **Step 4: Write `ContentImporter.swift`**

```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash scripts/ci-test.sh`
Expected: PASS (4 new tests).

- [ ] **Step 6: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Import LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift
git commit -m "Add JSON content document format and ContentImporter"
```

---

### Task 2: Content batch — Business & Economics (30 words)

**Files:**
- Create: `content/yds-academic-vocab-1/batches/business-economics.json`

**This is a content-authoring task, not a code task.** The deliverable is a single JSON file matching the `UnitDocument` shape from Task 1 (`id`, `theme`, `order`, `lessons: [LessonDocument]`). Use `"id": "yds-vocab1-unit-business-economics"`, `"theme": "Business & Economics"`, `"order": 0`. Split the 30 words below into 3 lessons of 10 (`"id"` values `yds-vocab1-lesson-business-1/2/3`, `"order"` 0/1/2, `"estimatedDurationMinutes": 5`).

**Words (word, exact `frequencyRank` to use — these come from the word's real position across the two AWL sublists this batch spans, not this batch's own order, so frequency stays meaningful across the whole package):**

Lesson 1 (order 0): economy(19), finance(26), income(30), percent(42), sector(53), contract(13), export(24), distribute(18), labour(36), policy(44)
Lesson 2 (order 1): major(39), source(56), benefit(8), factor(25), function(28), achieve(61), acquire(62), commission(70), consume(78), credit(79)
Lesson 3 (order 2): invest(92), purchase(104), resource(110), strategy(116), survey(117), transfer(120), administrate(63), impact(89), secure(112), item(93)

**For each word, write (per the spec's quality bar):**
- `id`: `"yds-vocab1-item-<word>"` (lowercase, e.g. `yds-vocab1-item-economy`)
- `type`: `"vocabulary"` for all 30 (none of these are grammar points/phrases in this batch)
- `headword`: the word itself
- `baseDifficulty`: your judgment, 0.0-1.0 (these are moderately-high-frequency academic words — most should land in the 0.25-0.55 range; reserve higher values for the genuinely harder/rarer-feeling ones like "administrate" or "consequent"-type words)
- `definition`: one clear, exam-register-appropriate English definition (not a dictionary copy-paste, not oversimplified)
- `exampleSentences`: 2-3 natural sentences that actually demonstrate real usage in a business/economics context — not sentences that just restate the definition
- `translationTR`: an accurate, idiomatic Turkish translation (not a literal/machine-translation-style gloss)
- `collocations`: 2-3 natural collocations a learner would actually encounter; if a word genuinely has no strong natural collocation, use its single most common phrase pairing instead of leaving the array thin

- [ ] **Step 1: Write the 30-word JSON file**

Write `content/yds-academic-vocab-1/batches/business-economics.json` as one `UnitDocument`-shaped JSON object per the format and word list above.

- [ ] **Step 2: Self-validate**

Confirm: valid JSON (no trailing commas, proper escaping), exactly 30 items across the 3 lessons, all 30 `id` values unique, every field present and non-empty for every item, `frequencyRank` values match the list above exactly.

- [ ] **Step 3: Commit**

```bash
git add content/yds-academic-vocab-1/batches/business-economics.json
git commit -m "Add YDS vocabulary content: Business & Economics unit"
```

---

### Task 3: Content batch — Science & Research Methods (30 words)

**Files:**
- Create: `content/yds-academic-vocab-1/batches/science-research.json`

Same format/quality bar as Task 2. `"id": "yds-vocab1-unit-science-research"`, `"theme": "Science & Research Methods"`, `"order": 1`. Lessons: `yds-vocab1-lesson-science-1/2/3`, orders 0/1/2.

**Words:**

Lesson 1 (order 0): analyse(1), assess(4), assume(5), data(15), define(16), derive(17), estimate(22), evident(23), formula(27), identify(29)
Lesson 2 (order 1): indicate(31), interpret(33), method(40), process(47), research(49), structure(58), theory(59), vary(60), compute(73), conduct(75)
Lesson 3 (order 2): construct(77), evaluate(85), feature(86), obtain(97), category(68), complex(72), element(83), equate(84), distinct(82), normal(96)

Write example sentences in a science/research-methods register (studies, experiments, data, analysis) rather than business — vary the register naturally per unit's theme rather than reusing generic sentences.

- [ ] **Step 1: Write the 30-word JSON file**
- [ ] **Step 2: Self-validate** (same checks as Task 2, against this file)
- [ ] **Step 3: Commit**

```bash
git add content/yds-academic-vocab-1/batches/science-research.json
git commit -m "Add YDS vocabulary content: Science & Research Methods unit"
```

---

### Task 4: Content batch — Law, Policy & Society (30 words)

**Files:**
- Create: `content/yds-academic-vocab-1/batches/law-policy-society.json`

Same format/quality bar. `"id": "yds-vocab1-unit-law-policy-society"`, `"theme": "Law, Policy & Society"`, `"order": 2`. Lessons: `yds-vocab1-lesson-law-1/2/3`, orders 0/1/2.

**Words:**

Lesson 1 (order 0): authority(6), area(3), constitute(11), environment(20), establish(21), issue(35), legal(37), legislate(38), principle(45), proceed(46)
Lesson 2 (order 1): require(48), role(51), significant(54), individual(32), involve(34), community(71), culture(80), institute(91), participate(98), potential(101)
Lesson 3 (order 2): previous(102), region(106), regulate(107), relevant(108), restrict(111), tradition(119), affect(64), injure(90), reside(109), consequent(76)

Write example sentences in a law/policy/society register (governments, regulations, communities, social issues).

- [ ] **Step 1: Write the 30-word JSON file**
- [ ] **Step 2: Self-validate**
- [ ] **Step 3: Commit**

```bash
git add content/yds-academic-vocab-1/batches/law-policy-society.json
git commit -m "Add YDS vocabulary content: Law, Policy & Society unit"
```

---

### Task 5: Content batch — Academic Writing & Communication (30 words)

**Files:**
- Create: `content/yds-academic-vocab-1/batches/academic-writing.json`

Same format/quality bar. `"id": "yds-vocab1-unit-academic-writing"`, `"theme": "Academic Writing & Communication"`, `"order": 3`. Lessons: `yds-vocab1-lesson-writing-1/2/3`, orders 0/1/2.

**Words:**

Lesson 1 (order 0): approach(2), available(7), concept(9), consist(10), context(12), create(14), occur(41), period(43), respond(50), section(52)
Lesson 2 (order 1): similar(55), specific(57), chapter(69), conclude(74), design(81), final(87), focus(88), journal(94), maintain(95), perceive(99)
Lesson 3 (order 2): positive(100), primary(103), range(105), seek(113), select(114), site(115), text(118), appropriate(65), aspect(66), assist(67)

Write example sentences in an academic-writing/communication register (essays, arguments, texts, chapters).

- [ ] **Step 1: Write the 30-word JSON file**
- [ ] **Step 2: Self-validate**
- [ ] **Step 3: Commit**

```bash
git add content/yds-academic-vocab-1/batches/academic-writing.json
git commit -m "Add YDS vocabulary content: Academic Writing & Communication unit"
```

---

### Task 6: Assemble the package and validate via ContentImporter

**Files:**
- Create: `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift` (add one real-data validation test)

**Interfaces:**
- Consumes: the 4 batch JSON files from Tasks 2-5, `ContentImporter` (Task 1)

- [ ] **Step 1: Assemble the 4 unit JSON files into one package document**

Read `content/yds-academic-vocab-1/batches/business-economics.json`,
`science-research.json`, `law-policy-society.json`, and
`academic-writing.json`. Wrap their contents as the `units` array of
one `ContentPackageDocument`:

```json
{
  "id": "yds-academic-vocab-1",
  "name": "YDS: Academic Vocabulary I",
  "goal": "yds",
  "levelLower": "B2",
  "levelUpper": "C1",
  "units": [ /* the 4 unit objects, in order 0-3 */ ]
}
```

Write the result to `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`.

- [ ] **Step 2: Add a real-data validation test**

Append to `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`. This test loads the actual generated file, so it needs the file accessible to the test target — copy it into a test-accessible location or read it via a relative path from the test bundle. Simplest: add the same JSON file to the test target's resources too (create `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json` as a copy, and add a `resources:` entry for it if `Package.swift` needs one — check whether `LearningEngine/Package.swift`'s test target needs a `resources:` parameter added to its `.testTarget(...)` declaration for `Bundle.module` access to work; if so, add `resources: [.copy("Fixtures/YDSAcademicVocabulary1.json")]`).

```swift
    func test_importPackage_realYDSVocabularyBatch_importsAll120ItemsAcrossFourUnits() throws {
        guard let url = Bundle.module.url(forResource: "YDSAcademicVocabulary1", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("Fixture file not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: data, into: context)
        try context.save()

        XCTAssertEqual(package.units.count, 4)
        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertEqual(allItems.count, 120)
        let uniqueIDs = Set(allItems.map(\.id))
        XCTAssertEqual(uniqueIDs.count, 120, "duplicate item ids found")
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
    }
```

If `Bundle.module`/`subdirectory:` doesn't resolve the way expected once CI actually runs this (resource bundling paths are one of the few things that can only be confirmed by a real SPM build), adjust based on the actual CI error — this is the same kind of "verify via real CI, iterate on the real error" situation prior plans in this project have hit with Xcode/XcodeGen specifics.

- [ ] **Step 3: Run to verify**

Run: `bash scripts/ci-test.sh`
Expected: PASS (5 tests in `ContentImporterTests` total). If the fixture-loading approach needs adjustment, fix based on the real error, not guesswork.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift LearningEngine/Tests/LearningEngineTests/Fixtures LearningEngine/Package.swift
git commit -m "Assemble YDS Academic Vocabulary I package and validate via ContentImporter"
```

---

### Task 7: App integration — seed from real content instead of SampleContent

**Files:**
- Modify: `App/project.yml` (bundle the JSON resource)
- Modify: `App/Sources/EnglishApp/AppModelContainer.swift`

**Interfaces:**
- Consumes: `ContentImporter.importPackage(from:into:)` (Task 1), `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` (Task 6)

- [ ] **Step 1: Add the resource to `App/project.yml`**

Add a `resources:` entry to the `EnglishApp` target so the JSON file is
bundled into the app:

```yaml
    sources:
      - path: Sources/EnglishApp
    resources:
      - path: Sources/EnglishApp/Resources
```

(Merge this into the existing `EnglishApp` target block rather than duplicating the `sources:` key — XcodeGen targets take one `sources:` list and, separately, one `resources:` list.)

- [ ] **Step 2: Swap the seeding call in `AppModelContainer.swift`**

Replace the body of `seedSampleContentIfNeeded` (or add a new function
and update the call site in `EnglishAppApp.swift` — your call on which
reads cleaner) so that instead of inserting
`SampleContent.ydsStarterPackage()`, it loads
`YDSAcademicVocabulary1.json` from the app bundle and imports it via
`ContentImporter.importPackage(from:into:)`:

```swift
static func seedRealContentIfNeeded(in context: ModelContext) {
    let existingCount = (try? context.fetchCount(FetchDescriptor<ContentPackage>())) ?? 0
    guard existingCount == 0 else { return }
    guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
        assertionFailure("YDSAcademicVocabulary1.json missing from app bundle")
        return
    }
    do {
        let data = try Data(contentsOf: url)
        _ = try ContentImporter.importPackage(from: data, into: context)
        try context.save()
    } catch {
        containerCreationError = "Failed to seed content: \(error.localizedDescription)"
    }
}
```

Update `EnglishAppApp.init()`'s call site from
`seedSampleContentIfNeeded` to this new function. `SampleContent` and
the old `seedSampleContentIfNeeded` function can stay in
`LearningEngine`/`AppModelContainer` unused-by-the-app if removing them
cleanly is awkward, but the app must no longer call the sample-content
path — real content only, from here on.

- [ ] **Step 3: Verify via CI**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS (build + existing tests green). If the resource bundling
doesn't resolve at runtime the way expected (Xcode resource bundling
via XcodeGen `resources:` has a few possible configurations), this
would only surface as a runtime issue, not a build failure — there is
no automated UI test in this app yet to catch it, so this is a case
where the CI green light means "compiles," not "the seeded content is
guaranteed correct on a real device." Note this explicitly in the
report so the controller can decide whether it's worth a lightweight
runtime-smoke-test addition (e.g., extending `TodaySessionCoordinatorTests`
to load the real bundled JSON instead of `SampleContent` for one test)
before calling this task done.

- [ ] **Step 4: Commit**

```bash
git add App/project.yml App/Sources/EnglishApp/AppModelContainer.swift
git commit -m "Seed the app from the real YDS content package instead of SampleContent"
```

## Future work

More AWL sublists (3-10) or an NGSL-based list for non-YDS packages —
same JSON format, same `ContentImporter`, no engine changes needed.
