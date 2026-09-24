# Onboarding, Level Test & Course Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-run onboarding (goal, exam date, daily minutes, skippable adaptive level test), a "Ders Yolu" course-path tab, and Profile display of the level-test result.

**Architecture:** Two new pure/testable layers on top of existing Slice 6a scaffolding — a `LevelTestEngine` (LearningEngine, SwiftData-free adaptive staircase over existing `LearningItem.baseDifficulty`) and an `OnboardingViewModel` state machine (App target) that composes a `LevelTestViewModel`. A `CoursePathViewModel` reuses the existing `PlanTask`/`PlanTaskAction`/`PlanTaskRow` vocabulary from Slice 6a's Bugün screen instead of inventing new UI types. `RootTabView` gates on `LearnerProfile.onboardingCompletedAt`.

**Tech Stack:** Swift/SwiftUI, SwiftData, XcodeGen-generated Xcode project, two local Swift packages (LearningEngine, TutorEngine) + App target.

**Spec:** `docs/superpowers/specs/2026-09-18-onboarding-level-test-course-path-design.md`

## Global Constraints

- This Windows machine has no Swift toolchain at all. Every task is verified by pushing to the `learning-engine` branch and running `scripts/ci-test.sh` (LearningEngine/TutorEngine changes) and/or `scripts/ci-app-build.sh` (App target changes) — never claim a local `swift test`/`xcodebuild` run.
- All user-facing copy is Turkish, written as inline string literals (the established pattern in this codebase — see `TodayPlanView.swift`, `ProfileView.swift`).
- Reuse existing DesignSystem primitives (`Theme`, `PaperCard`, `PrimaryButtonStyle`, `ProgressBar`, `SkillBadge`, `PlanTaskRow`) rather than inventing new styling.
- The level-test result is informational only: it must never write `UserItemState`/`ReviewLog` or otherwise influence FSRS scheduling.
- Every git commit message ends with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- `userID` is always `UserIdentity.current` (see `App/Sources/EnglishApp/UserIdentity.swift`); SwiftData predicates use the `let userIDValue = userID` local-copy pattern (Swift `#Predicate` can't close over `self.userID` directly) already used throughout `TodayPlanCoordinator.swift`.

---

## Task 1: Data model — LearnerProfile fields, LevelTestResult, schema

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/LevelTestResult.swift`
- Modify: `App/Sources/EnglishApp/AppModelContainer.swift`
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift` (only `resetAllData()`)
- Test: `LearningEngine/Tests/LearningEngineTests/LevelTestResultTests.swift`

**Interfaces:**
- Produces: `LearnerProfile.onboardingCompletedAt: Date?`, `LearnerProfile.hasSkippedLevelTest: Bool`; `CEFRLevel` enum (`.a2`/`.b1`/`.b2`/`.c1`, rawValues `"A2"`/`"B1"`/`"B2"`/`"C1"`); `LevelTestResult` `@Model` with `userID`, `cefrLevel`, `vocabularyScore`, `completedAt`; `AppModelContainer.schema` includes `LevelTestResult.self`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing test**

```swift
// LearningEngine/Tests/LearningEngineTests/LevelTestResultTests.swift
import XCTest
import SwiftData
@testable import LearningEngine

final class LevelTestResultTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([LevelTestResult.self, LearnerProfile.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_insertAndFetch_roundTripsAllFields() throws {
        let context = try makeContext()
        let completedAt = Date(timeIntervalSince1970: 1_000_000)
        context.insert(LevelTestResult(userID: "u1", cefrLevel: .b2, vocabularyScore: 0.75, completedAt: completedAt))
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<LevelTestResult>()).first)
        XCTAssertEqual(fetched.userID, "u1")
        XCTAssertEqual(fetched.cefrLevel, .b2)
        XCTAssertEqual(fetched.vocabularyScore, 0.75, accuracy: 1e-9)
        XCTAssertEqual(fetched.completedAt, completedAt)
    }

    func test_learnerProfile_onboardingFieldsDefaultToIncomplete() throws {
        let context = try makeContext()
        let profile = LearnerProfile(userID: "u1", activePackageID: "pkg", createdAt: Date())
        context.insert(profile)
        try context.save()

        XCTAssertNil(profile.onboardingCompletedAt)
        XCTAssertFalse(profile.hasSkippedLevelTest)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

This won't even compile yet (`LevelTestResult` and the two `LearnerProfile` fields don't exist) — that's the expected "fail" for a new-type step. Skip straight to implementation rather than pushing broken code to CI.

- [ ] **Step 3: Add the two fields to LearnerProfile**

```swift
// LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift
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
    /// Nil until the first-run onboarding flow finishes; `RootTabView` gates
    /// on this.
    public var onboardingCompletedAt: Date?
    /// Tracked separately from `onboardingCompletedAt` so Profil can offer a
    /// "take it now" entry point without conflating a skip with an
    /// incomplete onboarding.
    public var hasSkippedLevelTest: Bool

    public init(
        userID: String, activePackageID: String,
        dailyMinutes: Int = LearnerProfile.defaultDailyMinutes,
        examDate: Date? = nil, createdAt: Date,
        onboardingCompletedAt: Date? = nil, hasSkippedLevelTest: Bool = false
    ) {
        self.userID = userID
        self.activePackageID = activePackageID
        self.dailyMinutes = dailyMinutes
        self.examDate = examDate
        self.createdAt = createdAt
        self.onboardingCompletedAt = onboardingCompletedAt
        self.hasSkippedLevelTest = hasSkippedLevelTest
    }
}
```

- [ ] **Step 4: Create LevelTestResult**

```swift
// LearningEngine/Sources/LearningEngine/Models/LevelTestResult.swift
import Foundation
import SwiftData

/// Coarse CEFR estimate. Because the level test only draws on one curated
/// academic word list, this is an approximation of "how much of this word
/// list you know" rather than a general-language placement result — see the
/// design spec's caveat, surfaced to the learner in Profil.
public enum CEFRLevel: String, Codable, CaseIterable, Sendable {
    case a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"
}

/// At most one row per user — retaking the level test overwrites it. Purely
/// informational: never read by FSRS scheduling or DailyPlanBuilder.
@Model
public final class LevelTestResult {
    @Attribute(.unique) public var userID: String
    public var cefrLevel: CEFRLevel
    public var vocabularyScore: Double
    public var completedAt: Date

    public init(userID: String, cefrLevel: CEFRLevel, vocabularyScore: Double, completedAt: Date) {
        self.userID = userID
        self.cefrLevel = cefrLevel
        self.vocabularyScore = vocabularyScore
        self.completedAt = completedAt
    }
}
```

- [ ] **Step 5: Register the schema and update resetAllData**

```swift
// App/Sources/EnglishApp/AppModelContainer.swift — change the schema line only
static let schema = Schema([
    ContentPackage.self, Unit.self, Lesson.self, LearningItem.self, ItemContent.self,
    ReviewLog.self, UserItemState.self, LearnerProfile.self, LessonProgress.self, LevelTestResult.self
])
```

```swift
// App/Sources/EnglishApp/Profile/ProfileView.swift — resetAllData(), add one line
private func resetAllData() {
    do {
        try context.delete(model: ContentPackage.self)
        try context.delete(model: ReviewLog.self)
        try context.delete(model: UserItemState.self)
        try context.delete(model: LessonProgress.self)
        try context.delete(model: LearnerProfile.self)
        try context.delete(model: LevelTestResult.self)
        try context.save()
        AppModelContainer.seedRealContentIfNeeded(in: context)
        appState.bumpDataGeneration()
    } catch {
        resetError = error.localizedDescription
    }
}
```

- [ ] **Step 6: Run tests via CI and verify they pass**

Run: `scripts/ci-test.sh` (covers `LevelTestResultTests`) and `scripts/ci-app-build.sh` (covers the App target compiling with the new schema/resetAllData line).
Expected: both green.

- [ ] **Step 7: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Models/LearnerProfile.swift \
        LearningEngine/Sources/LearningEngine/Models/LevelTestResult.swift \
        LearningEngine/Tests/LearningEngineTests/LevelTestResultTests.swift \
        App/Sources/EnglishApp/AppModelContainer.swift \
        App/Sources/EnglishApp/Profile/ProfileView.swift
git commit -m "$(cat <<'EOF'
Add onboarding/level-test fields to the data model

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 2: LevelTestEngine (pure adaptive staircase)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Planning/LevelTestEngine.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/LevelTestEngineTests.swift`

**Interfaces:**
- Consumes: `CEFRLevel` (Task 1).
- Produces: `LevelTestCandidate`, `LevelTestQuestion`, `LevelTestOutcome`, `LevelTestEngine` with `public static let questionCount = 12`, `public init<RNG: RandomNumberGenerator>(candidates: [LevelTestCandidate], using rng: inout RNG)`, `public private(set) var currentQuestion: LevelTestQuestion?`, `public var isComplete: Bool`, `public mutating func answer<RNG: RandomNumberGenerator>(selectedIndex: Int, using rng: inout RNG) -> Bool`, `public func outcome() -> LevelTestOutcome`, `public static func cefrLevel(forDifficulty:) -> CEFRLevel`.

- [ ] **Step 1: Write the failing tests**

```swift
// LearningEngine/Tests/LearningEngineTests/LevelTestEngineTests.swift
import XCTest
@testable import LearningEngine

/// Deterministic RNG (splitmix64-style LCG) so tests are reproducible.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class LevelTestEngineTests: XCTestCase {
    func makeCandidates(count: Int = 30) -> [LevelTestCandidate] {
        (0..<count).map { i in
            LevelTestCandidate(
                itemID: "item-\(i)", headword: "word\(i)", translationTR: "anlam\(i)",
                baseDifficulty: 0.15 + Double(i) * (0.45 / Double(count - 1))
            )
        }
    }

    func test_correctAnswer_raisesNextQuestionsDifficulty() {
        var rng = SeededRNG(state: 1)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let first = try! XCTUnwrap(engine.currentQuestion)
        engine.answer(selectedIndex: first.correctIndex, using: &rng)
        let second = try! XCTUnwrap(engine.currentQuestion)
        XCTAssertGreaterThan(second.difficulty, first.difficulty)
    }

    func test_incorrectAnswer_lowersNextQuestionsDifficulty() {
        var rng = SeededRNG(state: 1)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let first = try! XCTUnwrap(engine.currentQuestion)
        let wrongIndex = (first.correctIndex + 1) % first.choices.count
        engine.answer(selectedIndex: wrongIndex, using: &rng)
        let second = try! XCTUnwrap(engine.currentQuestion)
        XCTAssertLessThan(second.difficulty, first.difficulty)
    }

    func test_twelveQuestions_noHeadwordRepeatsAsTarget() {
        var rng = SeededRNG(state: 42)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        var askedItemIDs: [String] = []
        while let question = engine.currentQuestion {
            askedItemIDs.append(question.itemID)
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
        XCTAssertEqual(askedItemIDs.count, LevelTestEngine.questionCount)
        XCTAssertEqual(Set(askedItemIDs).count, LevelTestEngine.questionCount)
        XCTAssertTrue(engine.isComplete)
    }

    func test_eachQuestion_hasFourChoicesAndCorrectTranslation() {
        var rng = SeededRNG(state: 7)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let candidatesByID = Dictionary(uniqueKeysWithValues: makeCandidates().map { ($0.itemID, $0) })
        while let question = engine.currentQuestion {
            XCTAssertEqual(question.choices.count, 4)
            let expected = try! XCTUnwrap(candidatesByID[question.itemID])
            XCTAssertEqual(question.choices[question.correctIndex], expected.translationTR)
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
    }

    func test_outcome_vocabularyScore_matchesCorrectFraction() {
        var rng = SeededRNG(state: 3)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        var correctSoFar = 0
        var questionIndex = 0
        while let question = engine.currentQuestion {
            let answerCorrectly = questionIndex % 3 != 0 // wrong on questions 0, 3, 6, 9 → 8 correct of 12
            if answerCorrectly { correctSoFar += 1 }
            let index = answerCorrectly ? question.correctIndex : (question.correctIndex + 1) % question.choices.count
            engine.answer(selectedIndex: index, using: &rng)
            questionIndex += 1
        }
        XCTAssertEqual(engine.outcome().vocabularyScore, Double(correctSoFar) / Double(LevelTestEngine.questionCount), accuracy: 1e-9)
    }

    func test_cefrBucketing_atThresholdBoundaries() {
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.15), .a2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.27), .a2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.28), .b1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.37), .b1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.38), .b2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.48), .b2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.49), .c1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.6), .c1)
    }

    func test_answeringAfterCompletion_isANoOpAndDoesNotCrash() {
        var rng = SeededRNG(state: 9)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        while let question = engine.currentQuestion {
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
        XCTAssertFalse(engine.answer(selectedIndex: 0, using: &rng))
        XCTAssertNil(engine.currentQuestion)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

CI won't build yet (`LevelTestEngine` doesn't exist) — proceed to implementation.

- [ ] **Step 3: Implement LevelTestEngine**

```swift
// LearningEngine/Sources/LearningEngine/Planning/LevelTestEngine.swift
import Foundation

/// SwiftData-free snapshot of one vocabulary item, as fed to the level test.
public struct LevelTestCandidate: Sendable, Equatable {
    public let itemID: String
    public let headword: String
    public let translationTR: String
    public let baseDifficulty: Double

    public init(itemID: String, headword: String, translationTR: String, baseDifficulty: Double) {
        self.itemID = itemID
        self.headword = headword
        self.translationTR = translationTR
        self.baseDifficulty = baseDifficulty
    }
}

public struct LevelTestQuestion: Sendable, Equatable {
    public let itemID: String
    public let headword: String
    /// Four Turkish meanings; exactly one (`choices[correctIndex]`) is correct.
    public let choices: [String]
    public let correctIndex: Int
    public let difficulty: Double
}

public struct LevelTestOutcome: Sendable, Equatable {
    public let cefrLevel: CEFRLevel
    public let vocabularyScore: Double
}

/// A single adaptive-staircase level test administration over a fixed
/// candidate pool. Pure value type — no SwiftData, no clock reads, no
/// hidden randomness (the caller threads an RNG through every call so runs
/// are reproducible in tests).
///
/// Distractors for one question may reappear as the *target* headword of a
/// later question, or vice versa — only the specific item asked as the
/// question's target headword is guaranteed not to repeat as a target
/// within one administration.
public struct LevelTestEngine: Sendable {
    public static let questionCount = 12

    /// One step per question, applied to move the *next* question's target
    /// difficulty after this question's result. Shrinks every 3 questions
    /// for coarse-to-fine convergence.
    private static let stepSizes: [Double] = [
        0.15, 0.15, 0.15, 0.08, 0.08, 0.08, 0.04, 0.04, 0.04, 0.02, 0.02, 0.02
    ]

    /// Fixed thresholds over the YDS package's observed baseDifficulty range
    /// (0.15-0.6, median ~0.3) — see the design spec.
    private static let cefrThresholds: [(max: Double, level: CEFRLevel)] = [
        (0.27, .a2), (0.37, .b1), (0.48, .b2), (.infinity, .c1)
    ]

    public static func cefrLevel(forDifficulty difficulty: Double) -> CEFRLevel {
        cefrThresholds.first { difficulty <= $0.max }?.level ?? .c1
    }

    private var remaining: [LevelTestCandidate]
    private var targetDifficulty: Double
    private var questionIndex = 0
    private var correctCount = 0
    private var lastDifficultyServed: Double

    public private(set) var currentQuestion: LevelTestQuestion?

    /// - Precondition: `candidates.count >= LevelTestEngine.questionCount`.
    ///   Callers must check this themselves (e.g. `LevelTestViewModel.isReady`)
    ///   before constructing a session.
    public init<RNG: RandomNumberGenerator>(candidates: [LevelTestCandidate], using rng: inout RNG) {
        precondition(candidates.count >= Self.questionCount, "LevelTestEngine needs at least \(Self.questionCount) candidates, got \(candidates.count)")
        self.remaining = candidates
        let sortedDifficulties = candidates.map(\.baseDifficulty).sorted()
        self.targetDifficulty = sortedDifficulties[sortedDifficulties.count / 2]
        self.lastDifficultyServed = targetDifficulty
        advance(using: &rng)
    }

    public var isComplete: Bool { currentQuestion == nil }

    /// Records the answer for `currentQuestion`, advances to the next
    /// question (or completes the session), and returns whether it was
    /// correct. A no-op returning `false` once the session is complete.
    @discardableResult
    public mutating func answer<RNG: RandomNumberGenerator>(selectedIndex: Int, using rng: inout RNG) -> Bool {
        guard let question = currentQuestion else { return false }
        let isCorrect = selectedIndex == question.correctIndex
        if isCorrect { correctCount += 1 }
        let step = Self.stepSizes[min(questionIndex, Self.stepSizes.count - 1)]
        targetDifficulty += isCorrect ? step : -step
        questionIndex += 1
        advance(using: &rng)
        return isCorrect
    }

    public func outcome() -> LevelTestOutcome {
        LevelTestOutcome(
            cefrLevel: Self.cefrLevel(forDifficulty: lastDifficultyServed),
            vocabularyScore: Double(correctCount) / Double(Self.questionCount)
        )
    }

    private mutating func advance<RNG: RandomNumberGenerator>(using rng: inout RNG) {
        guard questionIndex < Self.questionCount, remaining.count >= 4 else {
            currentQuestion = nil
            return
        }
        let picked = remaining.min { lhs, rhs in
            let dl = abs(lhs.baseDifficulty - targetDifficulty)
            let dr = abs(rhs.baseDifficulty - targetDifficulty)
            if dl != dr { return dl < dr }
            return lhs.itemID < rhs.itemID // deterministic tie-break
        }!
        remaining.removeAll { $0.itemID == picked.itemID }
        lastDifficultyServed = picked.baseDifficulty

        let distractors = remaining.shuffled(using: &rng).prefix(3)
        var options = [picked.translationTR] + distractors.map(\.translationTR)
        options.shuffle(using: &rng)
        let correctIndex = options.firstIndex(of: picked.translationTR)!

        currentQuestion = LevelTestQuestion(
            itemID: picked.itemID, headword: picked.headword,
            choices: options, correctIndex: correctIndex, difficulty: picked.baseDifficulty
        )
    }
}
```

- [ ] **Step 4: Run tests via CI and verify they pass**

Run: `scripts/ci-test.sh`.
Expected: all `LevelTestEngineTests` green.

- [ ] **Step 5: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Planning/LevelTestEngine.swift \
        LearningEngine/Tests/LearningEngineTests/LevelTestEngineTests.swift
git commit -m "$(cat <<'EOF'
Add LevelTestEngine: adaptive vocabulary-only staircase test

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 3: LevelTestViewModel + candidate fetcher (App target)

**Files:**
- Create: `App/Sources/EnglishApp/LevelTest/LevelTestViewModel.swift`
- Test: `App/Tests/EnglishAppTests/LevelTestViewModelTests.swift`

**Interfaces:**
- Consumes: `LevelTestEngine`, `LevelTestCandidate`, `LevelTestQuestion`, `LevelTestOutcome` (Task 2); `LearningItem`, `ItemContent`, `ContentPackage`, `Unit`, `Lesson` (existing LearningEngine models).
- Produces: `LevelTestCandidateFetcher.fetch(packageID:in:) -> [LevelTestCandidate]`; `LevelTestViewModel` (`@MainActor @Observable`) with `init(candidates: [LevelTestCandidate])`, `var isReady: Bool`, `func start()`, `func answer(selectedIndex: Int)`, `private(set) var currentQuestion: LevelTestQuestion?`, `private(set) var questionNumber: Int`, `private(set) var outcome: LevelTestOutcome?`. Used by Task 4 (`OnboardingViewModel`) and Task 8 (Profil retake).

- [ ] **Step 1: Write the failing tests**

```swift
// App/Tests/EnglishAppTests/LevelTestViewModelTests.swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class LevelTestViewModelTests: XCTestCase {
    func makeCandidates(count: Int = 15) -> [LevelTestCandidate] {
        (0..<count).map { i in
            LevelTestCandidate(itemID: "item-\(i)", headword: "word\(i)", translationTR: "anlam\(i)", baseDifficulty: 0.15 + Double(i) * (0.45 / Double(count - 1)))
        }
    }

    @MainActor
    func test_isReady_falseWhenFewerThanQuestionCount() {
        let vm = LevelTestViewModel(candidates: makeCandidates(count: 5))
        XCTAssertFalse(vm.isReady)
    }

    @MainActor
    func test_start_loadsFirstQuestion() {
        let vm = LevelTestViewModel(candidates: makeCandidates())
        XCTAssertTrue(vm.isReady)
        vm.start()
        XCTAssertNotNil(vm.currentQuestion)
        XCTAssertEqual(vm.questionNumber, 1)
        XCTAssertNil(vm.outcome)
    }

    @MainActor
    func test_answeringAllQuestions_producesOutcome() {
        let vm = LevelTestViewModel(candidates: makeCandidates())
        vm.start()
        var iterations = 0
        while let question = vm.currentQuestion, iterations < LevelTestEngine.questionCount {
            vm.answer(selectedIndex: question.correctIndex)
            iterations += 1
        }
        XCTAssertEqual(iterations, LevelTestEngine.questionCount)
        XCTAssertNotNil(vm.outcome)
        XCTAssertEqual(vm.outcome?.vocabularyScore, 1.0, accuracy: 1e-9)
        XCTAssertNil(vm.currentQuestion)
    }

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_candidateFetcher_returnsOnlyVocabularyItemsFromThePackage() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(id: "pkg-a"), into: context)
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(id: "pkg-b"), into: context)

        let candidates = LevelTestCandidateFetcher.fetch(packageID: "pkg-a", in: context)
        XCTAssertEqual(candidates.count, 8) // TestPackageJSON: 2 units × 2 lessons × 2 items
        XCTAssertTrue(candidates.allSatisfy { $0.itemID.hasPrefix("item-") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

CI won't build yet — proceed to implementation.

- [ ] **Step 3: Implement LevelTestViewModel**

```swift
// App/Sources/EnglishApp/LevelTest/LevelTestViewModel.swift
import Foundation
import Observation
import SwiftData
import LearningEngine

/// Reads the active package's vocabulary items as level-test candidates.
/// Non-vocabulary items (grammarPoint/phrase/collocation) never appear —
/// the level test is vocabulary-only until Slice 7 adds gradeable grammar
/// content, at which point this can grow to include it.
enum LevelTestCandidateFetcher {
    static func fetch(packageID: String, in context: ModelContext) -> [LevelTestCandidate] {
        let items = (try? context.fetch(FetchDescriptor<LearningItem>())) ?? []
        return items
            .filter { $0.type == .vocabulary && $0.lesson?.unit?.package?.id == packageID }
            .compactMap { item -> LevelTestCandidate? in
                guard let content = item.content else { return nil }
                return LevelTestCandidate(itemID: item.id, headword: content.headword, translationTR: content.translationTR, baseDifficulty: item.baseDifficulty)
            }
    }
}

/// Drives one `LevelTestEngine` session for SwiftUI. Used both by onboarding
/// (Task 4) and by the Profil "retake" entry point (Task 8) — it knows
/// nothing about either caller's surrounding flow.
@MainActor
@Observable
final class LevelTestViewModel {
    let isReady: Bool
    private(set) var currentQuestion: LevelTestQuestion?
    private(set) var questionNumber = 0
    private(set) var outcome: LevelTestOutcome?

    private let candidates: [LevelTestCandidate]
    private var engine: LevelTestEngine?
    private var rng = SystemRandomNumberGenerator()

    init(candidates: [LevelTestCandidate]) {
        self.candidates = candidates
        self.isReady = candidates.count >= LevelTestEngine.questionCount
    }

    func start() {
        guard isReady, engine == nil else { return }
        var localRNG = rng
        let newEngine = LevelTestEngine(candidates: candidates, using: &localRNG)
        rng = localRNG
        engine = newEngine
        currentQuestion = newEngine.currentQuestion
        questionNumber = 1
        outcome = nil
    }

    func answer(selectedIndex: Int) {
        guard var engine else { return }
        var localRNG = rng
        engine.answer(selectedIndex: selectedIndex, using: &localRNG)
        rng = localRNG
        self.engine = engine
        if engine.isComplete {
            outcome = engine.outcome()
            currentQuestion = nil
        } else {
            currentQuestion = engine.currentQuestion
            questionNumber += 1
        }
    }
}
```

- [ ] **Step 4: Run tests via CI and verify they pass**

Run: `scripts/ci-app-build.sh`.
Expected: `LevelTestViewModelTests` all green.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/LevelTest/LevelTestViewModel.swift \
        App/Tests/EnglishAppTests/LevelTestViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add LevelTestViewModel and candidate fetcher

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 4: OnboardingViewModel (state machine)

**Files:**
- Create: `App/Sources/EnglishApp/Onboarding/OnboardingViewModel.swift`
- Test: `App/Tests/EnglishAppTests/OnboardingViewModelTests.swift`

**Interfaces:**
- Consumes: `LevelTestViewModel`, `LevelTestCandidateFetcher` (Task 3); `LearnerProfile`, `LevelTestResult`, `ContentPackage` (Task 1 + existing).
- Produces: `OnboardingStep` enum; `OnboardingViewModel` (`@MainActor @Observable`) with `init(context:userID:clock:)`, `private(set) var step`, `var selectedPackageID: String?`, `var examDate: Date?`, `var dailyMinutes: Int`, `private(set) var goalOptions: [GoalOption]`, `private(set) var levelTestViewModel: LevelTestViewModel?`, `private(set) var isOnboardingComplete: Bool`, `func advance()`, `func goBack()`, `var progressFraction: Double`, `func startLevelTest()`, `func answerLevelTestQuestion(selectedIndex:)`, `func skipLevelTest()`, `func finishFromResult()`. Used by Task 5 (`OnboardingFlowView`).

- [ ] **Step 1: Write the failing tests**

```swift
// App/Tests/EnglishAppTests/OnboardingViewModelTests.swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class OnboardingViewModelTests: XCTestCase {
    let userID = "u"
    lazy var now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext(richContent: Bool = false) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if richContent {
            _ = try ContentSeeder.seed(bundledData: RichLevelTestPackageJSON.make(), into: context)
        } else {
            _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        }
        return context
    }

    @MainActor
    func test_advance_movesThroughLinearSteps() throws {
        let vm = OnboardingViewModel(context: try makeContext(), userID: userID, clock: { self.now })
        XCTAssertEqual(vm.step, .goalSelection)
        vm.advance()
        XCTAssertEqual(vm.step, .examDate)
        vm.advance()
        XCTAssertEqual(vm.step, .dailyDuration)
        vm.advance()
        XCTAssertEqual(vm.step, .levelTestIntro)
    }

    @MainActor
    func test_goBack_returnsToPreviousStep() throws {
        let vm = OnboardingViewModel(context: try makeContext(), userID: userID, clock: { self.now })
        vm.advance() // examDate
        vm.advance() // dailyDuration
        vm.goBack()
        XCTAssertEqual(vm.step, .examDate)
    }

    @MainActor
    func test_quittingMidFlow_persistsNoProfile() throws {
        let context = try makeContext()
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.advance()
        vm.advance()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearnerProfile>()), 0)
    }

    @MainActor
    func test_notEnoughVocabularyCandidates_autoSkipsLevelTest() throws {
        // TestPackageJSON has only 8 vocabulary items, below LevelTestEngine.questionCount (12).
        let context = try makeContext()
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.dailyMinutes = 25
        vm.advance() // examDate
        vm.advance() // dailyDuration
        vm.advance() // levelTestIntro — prepares levelTestViewModel
        vm.startLevelTest()
        XCTAssertEqual(vm.step, .done)
        XCTAssertTrue(vm.isOnboardingComplete)

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertTrue(profile.hasSkippedLevelTest)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LevelTestResult>()), 0)
    }

    @MainActor
    func test_skipLevelTest_persistsProfileWithoutResult() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.examDate = now
        vm.dailyMinutes = 30
        vm.advance()
        vm.advance()
        vm.advance()
        vm.skipLevelTest()

        XCTAssertEqual(vm.step, .done)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 30)
        XCTAssertEqual(profile.examDate, now)
        XCTAssertEqual(profile.onboardingCompletedAt, now)
        XCTAssertTrue(profile.hasSkippedLevelTest)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LevelTestResult>()), 0)
    }

    @MainActor
    func test_completingLevelTest_persistsProfileAndResult() throws {
        let context = try makeContext(richContent: true)
        let vm = OnboardingViewModel(context: context, userID: userID, clock: { self.now })
        vm.advance()
        vm.advance()
        vm.advance()
        vm.startLevelTest()
        XCTAssertEqual(vm.step, .levelTest)

        var iterations = 0
        while let question = vm.levelTestViewModel?.currentQuestion, iterations < LevelTestEngine.questionCount {
            vm.answerLevelTestQuestion(selectedIndex: question.correctIndex)
            iterations += 1
        }
        XCTAssertEqual(vm.step, .levelTestResult)
        vm.finishFromResult()
        XCTAssertEqual(vm.step, .done)
        XCTAssertTrue(vm.isOnboardingComplete)

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertFalse(profile.hasSkippedLevelTest)
        let result = try XCTUnwrap(context.fetch(FetchDescriptor<LevelTestResult>()).first)
        XCTAssertEqual(result.userID, userID)
        XCTAssertEqual(result.vocabularyScore, 1.0, accuracy: 1e-9)
    }
}
```

This test file needs a richer fixture than `TestPackageJSON` (which has only 8 vocabulary items — below `LevelTestEngine.questionCount`). Add it alongside `TestPackageJSON`:

```swift
// App/Tests/EnglishAppTests/RichLevelTestPackageJSON.swift
import Foundation

/// One unit, one lesson, 15 vocabulary items with varied baseDifficulty
/// (0.15...0.6) — enough for LevelTestEngine.questionCount (12) to run for
/// real, unlike TestPackageJSON's 8 items.
enum RichLevelTestPackageJSON {
    static func make(id: String = "pkg") -> Data {
        let items = (0..<15).map { i -> String in
            let difficulty = 0.15 + Double(i) * (0.45 / 14.0)
            return """
            { "id": "rich-item-\(i)", "type": "vocabulary", "headword": "word\(i)",
              "frequencyRank": \(i), "baseDifficulty": \(difficulty),
              "definition": "d", "exampleSentences": ["e"], "translationTR": "anlam\(i)", "collocations": [] }
            """
        }.joined(separator: ",")
        return """
        { "id": "\(id)", "name": "Rich \(id)", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "version": 1,
          "skillWeights": { "vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0 },
          "units": [{ "id": "unit-0", "theme": "Unit 0", "order": 0, "lessons": [
            { "id": "lesson-0", "order": 0, "estimatedDurationMinutes": 20, "title": "Lesson 1", "skill": "vocabulary", "items": [\(items)] }
          ] }] }
        """.data(using: .utf8)!
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

CI won't build yet — proceed to implementation.

- [ ] **Step 3: Implement OnboardingViewModel**

```swift
// App/Sources/EnglishApp/Onboarding/OnboardingViewModel.swift
import Foundation
import Observation
import SwiftData
import LearningEngine

enum OnboardingStep: Equatable {
    case goalSelection, examDate, dailyDuration, levelTestIntro, levelTest, levelTestResult, done
}

@MainActor
@Observable
final class OnboardingViewModel {
    struct GoalOption: Identifiable, Equatable {
        let id: String
        let name: String
        let levelLower: String
        let levelUpper: String
    }

    private(set) var step: OnboardingStep = .goalSelection
    private(set) var goalOptions: [GoalOption] = []
    var selectedPackageID: String?
    var examDate: Date?
    var dailyMinutes: Int = LearnerProfile.defaultDailyMinutes
    private(set) var levelTestViewModel: LevelTestViewModel?
    private(set) var isOnboardingComplete = false
    private(set) var loadError: String?

    private let context: ModelContext
    private let userID: String
    private let clock: () -> Date

    init(context: ModelContext, userID: String, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.userID = userID
        self.clock = clock
        loadGoalOptions()
    }

    private func loadGoalOptions() {
        let packages = (try? context.fetch(FetchDescriptor<ContentPackage>(sortBy: [SortDescriptor(\.id)]))) ?? []
        goalOptions = packages.map { GoalOption(id: $0.id, name: $0.name, levelLower: $0.levelLower, levelUpper: $0.levelUpper) }
        selectedPackageID = goalOptions.first?.id
    }

    func advance() {
        switch step {
        case .goalSelection: step = .examDate
        case .examDate: step = .dailyDuration
        case .dailyDuration:
            prepareLevelTest()
            step = .levelTestIntro
        case .levelTestIntro, .levelTest, .levelTestResult, .done: break
        }
    }

    func goBack() {
        switch step {
        case .goalSelection, .done: break
        case .examDate: step = .goalSelection
        case .dailyDuration: step = .examDate
        case .levelTestIntro: step = .dailyDuration
        case .levelTest: step = .levelTestIntro
        case .levelTestResult: step = .levelTestIntro
        }
    }

    /// Fraction complete across the 5 user-visible stops (levelTest itself
    /// counts as still "on" levelTestIntro for progress display purposes).
    var progressFraction: Double {
        let order: [OnboardingStep] = [.goalSelection, .examDate, .dailyDuration, .levelTestIntro, .levelTestResult]
        let effective = step == .levelTest ? .levelTestIntro : step
        guard let index = order.firstIndex(of: effective) else { return 1 }
        return Double(index + 1) / Double(order.count)
    }

    private func prepareLevelTest() {
        guard let packageID = selectedPackageID else { return }
        let candidates = LevelTestCandidateFetcher.fetch(packageID: packageID, in: context)
        levelTestViewModel = LevelTestViewModel(candidates: candidates)
    }

    func startLevelTest() {
        guard let levelTestViewModel, levelTestViewModel.isReady else {
            skipLevelTest()
            return
        }
        levelTestViewModel.start()
        step = .levelTest
    }

    func answerLevelTestQuestion(selectedIndex: Int) {
        guard let levelTestViewModel else { return }
        levelTestViewModel.answer(selectedIndex: selectedIndex)
        if levelTestViewModel.outcome != nil {
            step = .levelTestResult
        }
    }

    func skipLevelTest() {
        persist(outcome: nil, skippedLevelTest: true)
    }

    func finishFromResult() {
        persist(outcome: levelTestViewModel?.outcome, skippedLevelTest: false)
    }

    private func persist(outcome: LevelTestOutcome?, skippedLevelTest: Bool) {
        do {
            let userIDValue = userID
            let existingProfile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first
            let profile: LearnerProfile
            if let existingProfile {
                profile = existingProfile
            } else {
                profile = LearnerProfile(userID: userID, activePackageID: selectedPackageID ?? "", createdAt: clock())
                context.insert(profile)
            }
            if let selectedPackageID { profile.activePackageID = selectedPackageID }
            profile.dailyMinutes = dailyMinutes
            profile.examDate = examDate
            profile.onboardingCompletedAt = clock()
            profile.hasSkippedLevelTest = skippedLevelTest

            if let outcome {
                if let existingResult = try context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userIDValue })).first {
                    existingResult.cefrLevel = outcome.cefrLevel
                    existingResult.vocabularyScore = outcome.vocabularyScore
                    existingResult.completedAt = clock()
                } else {
                    context.insert(LevelTestResult(userID: userID, cefrLevel: outcome.cefrLevel, vocabularyScore: outcome.vocabularyScore, completedAt: clock()))
                }
            }
            try context.save()
            step = .done
            isOnboardingComplete = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Run tests via CI and verify they pass**

Run: `scripts/ci-app-build.sh`.
Expected: all `OnboardingViewModelTests` green.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/Onboarding/OnboardingViewModel.swift \
        App/Tests/EnglishAppTests/OnboardingViewModelTests.swift \
        App/Tests/EnglishAppTests/RichLevelTestPackageJSON.swift
git commit -m "$(cat <<'EOF'
Add OnboardingViewModel state machine

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 5: Onboarding UI + RootTabView gating

**Files:**
- Create: `App/Sources/EnglishApp/LevelTest/LevelTestQuestionView.swift`
- Create: `App/Sources/EnglishApp/LevelTest/LevelTestResultView.swift`
- Create: `App/Sources/EnglishApp/Onboarding/OnboardingFlowView.swift`
- Modify: `App/Sources/EnglishApp/RootTabView.swift`

**Interfaces:**
- Consumes: `OnboardingViewModel` (Task 4), `LevelTestViewModel`/`LevelTestQuestion`/`LevelTestOutcome` (Task 3/2), `UserIdentity.current` (existing).
- Produces: `LevelTestQuestionView`, `LevelTestResultView` (reused by Task 8); `OnboardingFlowView`; `RootTabView` gates on `LearnerProfile.onboardingCompletedAt`.

No new unit tests — views are verified by App Build CI compiling successfully (existing project convention; see spec's Testing approach).

- [ ] **Step 1: Add the two shared level-test view components**

```swift
// App/Sources/EnglishApp/LevelTest/LevelTestQuestionView.swift
import SwiftUI
import LearningEngine

struct LevelTestQuestionView: View {
    let question: LevelTestQuestion
    let questionNumber: Int
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Soru \(questionNumber)/\(LevelTestEngine.questionCount)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
            Text(question.headword).font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("Türkçe anlamı hangisi?").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    onAnswer(index)
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

```swift
// App/Sources/EnglishApp/LevelTest/LevelTestResultView.swift
import SwiftUI
import LearningEngine

struct LevelTestResultView: View {
    let outcome: LevelTestOutcome
    let buttonTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tahmini seviyen").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text(outcome.cefrLevel.rawValue)
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(Theme.primary)
            Text("Kelime bilgisi: %\(Int((outcome.vocabularyScore * 100).rounded()))")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Text("Bu, sadece bu paketin kelime listesine göre kaba bir tahmindir.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button(buttonTitle, action: onContinue).buttonStyle(PrimaryButtonStyle())
        }
    }
}
```

- [ ] **Step 2: Add OnboardingFlowView**

```swift
// App/Sources/EnglishApp/Onboarding/OnboardingFlowView.swift
import SwiftUI
import SwiftData
import LearningEngine

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    VStack(spacing: 0) {
                        ProgressBar(progress: viewModel.progressFraction)
                            .padding(.horizontal).padding(.top, 12)
                        ScrollView { stepContent(viewModel).padding() }
                    }
                    .background(Theme.paper.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(context: context, userID: UserIdentity.current)
            }
        }
        .onChange(of: viewModel?.isOnboardingComplete) { _, isComplete in
            if isComplete == true { appState.bumpDataGeneration() }
        }
    }

    @ViewBuilder
    private func stepContent(_ viewModel: OnboardingViewModel) -> some View {
        switch viewModel.step {
        case .goalSelection:
            GoalSelectionStep(viewModel: viewModel)
        case .examDate:
            ExamDateStep(viewModel: viewModel)
        case .dailyDuration:
            DailyDurationStep(viewModel: viewModel)
        case .levelTestIntro:
            LevelTestIntroStep(viewModel: viewModel)
        case .levelTest:
            if let question = viewModel.levelTestViewModel?.currentQuestion {
                LevelTestQuestionView(question: question, questionNumber: viewModel.levelTestViewModel?.questionNumber ?? 1) { index in
                    viewModel.answerLevelTestQuestion(selectedIndex: index)
                }
            }
        case .levelTestResult:
            if let outcome = viewModel.levelTestViewModel?.outcome {
                LevelTestResultView(outcome: outcome, buttonTitle: "Bugüne başla") {
                    viewModel.finishFromResult()
                }
            }
        case .done:
            EmptyView()
        }
    }
}

private struct GoalSelectionStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hedefini seç").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("Çalışma planın seçtiğin hedefe göre kurulur.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            ForEach(viewModel.goalOptions) { option in
                Button {
                    viewModel.selectedPackageID = option.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.name).font(.headline).foregroundStyle(Theme.ink)
                            Text("\(option.levelLower)–\(option.levelUpper)").font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                        Spacer()
                        if viewModel.selectedPackageID == option.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                        }
                    }
                    .padding()
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(viewModel.selectedPackageID == option.id ? Theme.primary : Theme.border, lineWidth: viewModel.selectedPackageID == option.id ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button("Devam et") { viewModel.advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.selectedPackageID == nil)
        }
    }
}

private struct ExamDateStep: View {
    let viewModel: OnboardingViewModel
    @State private var hasExamDate = true
    @State private var date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sınav tarihin var mı?").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Toggle("Bir sınav tarihim var", isOn: $hasExamDate).tint(Theme.primary)
            if hasExamDate {
                DatePicker("Sınav tarihi", selection: $date, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Geri") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Devam et") {
                    viewModel.examDate = hasExamDate ? date : nil
                    viewModel.advance()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
            }
        }
        .onAppear {
            hasExamDate = viewModel.examDate != nil
            date = viewModel.examDate ?? Date()
        }
    }
}

private struct DailyDurationStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Günde ne kadar çalışacaksın?").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Stepper("Günlük \(viewModel.dailyMinutes) dakika", value: Binding(
                get: { viewModel.dailyMinutes },
                set: { viewModel.dailyMinutes = $0 }
            ), in: 10...60, step: 5)
            Spacer(minLength: 0)
            HStack {
                Button("Geri") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Devam et") { viewModel.advance() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 200)
            }
        }
    }
}

private struct LevelTestIntroStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kısa bir seviye kontrolü").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("5-8 dakikada, bildiğin kelimelere göre yaklaşık seviyeni tahmin ederiz. İstersen atlayabilirsin.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button("Başla") { viewModel.startLevelTest() }.buttonStyle(PrimaryButtonStyle())
            Button("Atla") { viewModel.skipLevelTest() }
                .buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 3: Gate RootTabView on onboarding completion**

```swift
// App/Sources/EnglishApp/RootTabView.swift
import SwiftUI
import SwiftData
import LearningEngine

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [LearnerProfile]

    init() {
        let userID = UserIdentity.current
        _profiles = Query(filter: #Predicate<LearnerProfile> { $0.userID == userID })
    }

    private var hasCompletedOnboarding: Bool {
        profiles.first?.onboardingCompletedAt != nil
    }

    var body: some View {
        if hasCompletedOnboarding {
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
        } else {
            OnboardingFlowView()
        }
    }
}
```

(The "Ders Yolu" tab is added here in Task 7, once `CoursePathView` exists, to keep this diff reviewable on its own.)

- [ ] **Step 4: Verify via CI**

Run: `scripts/ci-app-build.sh`.
Expected: green — this is a UI-only task, verified by successful compilation (per this project's established pattern of not unit-testing SwiftUI views).

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/LevelTest/LevelTestQuestionView.swift \
        App/Sources/EnglishApp/LevelTest/LevelTestResultView.swift \
        App/Sources/EnglishApp/Onboarding/OnboardingFlowView.swift \
        App/Sources/EnglishApp/RootTabView.swift
git commit -m "$(cat <<'EOF'
Add onboarding UI and gate RootTabView on onboarding completion

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 6: CoursePathViewModel

**Files:**
- Create: `App/Sources/EnglishApp/CoursePath/CoursePathViewModel.swift`
- Test: `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: `PlanTask`, `PackageOutline`, `UnitOutline`, `LessonAccessPolicy` (existing LearningEngine); `TodayPlanCoordinator.ensureProfile()` (existing).
- Produces: `CoursePathSection` (`unitID`, `theme`, `tasks: [PlanTask]`); `CoursePathViewModel` (`@MainActor @Observable`) with `init(context:userID:accessProvider:)`, `func load()`, `private(set) var sections: [CoursePathSection]`, `private(set) var loadError: String?`. Used by Task 7 (`CoursePathView`).

- [ ] **Step 1: Write the failing tests**

```swift
// App/Tests/EnglishAppTests/CoursePathViewModelTests.swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class CoursePathViewModelTests: XCTestCase {
    let userID = "u"

    func makeContext(seed: Bool = true) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if seed { _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context) }
        return context
    }

    @MainActor
    func test_load_groupsLessonsByUnitInOrder() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        XCTAssertEqual(vm.sections.map(\.unitID), ["unit-0", "unit-1"])
        XCTAssertEqual(vm.sections[0].tasks.count, 2)
        guard case .lesson(let id, _, _, _, _) = vm.sections[0].tasks[0] else {
            return XCTFail("expected a lesson task")
        }
        XCTAssertEqual(id, "lesson-u0-l0")
    }

    @MainActor
    func test_load_previewAccess_locksSecondUnit() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview))
        vm.load()
        for task in vm.sections[0].tasks {
            if case .locked = task { return XCTFail("first unit should be accessible under preview") }
        }
        for task in vm.sections[1].tasks {
            guard case .locked = task else { return XCTFail("second unit should be locked under preview") }
        }
    }

    @MainActor
    func test_load_ownedAccess_nothingLocked() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        for section in vm.sections {
            for task in section.tasks {
                if case .locked = task { XCTFail("nothing should be locked under owned access") }
            }
        }
    }

    @MainActor
    func test_load_completedLesson_marksTaskDone() throws {
        let context = try makeContext()
        _ = try TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned)).ensureProfile()
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: Date())
        progress.completedAt = Date()
        context.insert(progress)
        try context.save()

        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        guard case .lesson(_, _, _, _, let isDone) = vm.sections[0].tasks[0] else {
            return XCTFail("expected a lesson task")
        }
        XCTAssertTrue(isDone)
    }

    @MainActor
    func test_load_noPackages_emptySections() throws {
        let context = try makeContext(seed: false)
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        XCTAssertTrue(vm.sections.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

CI won't build yet — proceed to implementation.

- [ ] **Step 3: Implement CoursePathViewModel**

```swift
// App/Sources/EnglishApp/CoursePath/CoursePathViewModel.swift
import Foundation
import Observation
import SwiftData
import LearningEngine

struct CoursePathSection: Equatable {
    let unitID: String
    let theme: String
    let tasks: [PlanTask]
}

/// Shows the whole course path (every unit/lesson of the active package),
/// as opposed to TodayPlanCoordinator's "what to do today". Reuses
/// PlanTask/PlanTaskAction/PlanTaskRow exactly as Bugün does — no new study
/// flow.
@MainActor
@Observable
final class CoursePathViewModel {
    private(set) var sections: [CoursePathSection] = []
    private(set) var loadError: String?

    private let context: ModelContext
    private let userID: String
    private let accessProvider: any PackageAccessProvider

    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider) {
        self.context = context
        self.userID = userID
        self.accessProvider = accessProvider
    }

    func load() {
        do {
            let coordinator = TodayPlanCoordinator(context: context, userID: userID, accessProvider: accessProvider)
            guard let profile = try coordinator.ensureProfile() else {
                sections = []
                return
            }
            let packageID = profile.activePackageID
            guard let package = try context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first else {
                sections = []
                return
            }
            sections = try Self.buildSections(package: package, userID: userID, accessProvider: accessProvider, context: context)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func buildSections(package: ContentPackage, userID: String, accessProvider: any PackageAccessProvider, context: ModelContext) throws -> [CoursePathSection] {
        let units = package.units.sorted { $0.order < $1.order }
        let outline = PackageOutline(units: units.map { UnitOutline(id: $0.id, order: $0.order, lessonIDs: $0.lessons.map(\.id)) })
        let accessible = LessonAccessPolicy().accessibleLessonIDs(in: outline, level: accessProvider.accessLevel(forPackageID: package.id))

        let userIDValue = userID
        let progressRows = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.userID == userIDValue }))
        let completion = Dictionary(uniqueKeysWithValues: progressRows.compactMap { row in row.completedAt.map { (row.lessonID, $0) } })

        return units.map { unit in
            let lessons = unit.lessons.sorted { $0.order < $1.order }
            let tasks: [PlanTask] = lessons.map { lesson in
                if accessible.contains(lesson.id) {
                    return .lesson(id: lesson.id, title: lesson.title, skill: lesson.skill, minutes: Double(lesson.estimatedDurationMinutes), isDone: completion[lesson.id] != nil)
                } else {
                    return .locked(id: lesson.id, title: lesson.title)
                }
            }
            return CoursePathSection(unitID: unit.id, theme: unit.theme, tasks: tasks)
        }
    }
}
```

- [ ] **Step 4: Run tests via CI and verify they pass**

Run: `scripts/ci-app-build.sh`.
Expected: all `CoursePathViewModelTests` green.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/CoursePath/CoursePathViewModel.swift \
        App/Tests/EnglishAppTests/CoursePathViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add CoursePathViewModel

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 7: CoursePathView UI + 4th RootTabView tab

**Files:**
- Create: `App/Sources/EnglishApp/CoursePath/CoursePathView.swift`
- Modify: `App/Sources/EnglishApp/RootTabView.swift`

**Interfaces:**
- Consumes: `CoursePathViewModel` (Task 6), `PlanTaskRow`/`PlanTaskAction` (existing, Slice 6a), `StudySessionView` (existing).
- Produces: `CoursePathView`; `RootTabView` gains a 4th tab (Bugün · Ders Yolu · Tutor · Profil).

No new unit tests — UI-only, verified by App Build CI.

- [ ] **Step 1: Implement CoursePathView**

```swift
// App/Sources/EnglishApp/CoursePath/CoursePathView.swift
import SwiftUI
import SwiftData
import LearningEngine

struct CoursePathView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    private struct ActiveLessonSession: Identifiable {
        let id = UUID()
        let lessonID: String
    }

    @State private var viewModel: CoursePathViewModel?
    @State private var activeSession: ActiveLessonSession?
    @State private var infoMessage: (title: String, body: String)?

    var body: some View {
        NavigationStack {
            ScrollView { content.padding() }
                .background(Theme.paper.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .fullScreenCover(item: $activeSession) { session in
            StudySessionView(mode: .lesson(id: session.lessonID)) {
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
        VStack(alignment: .leading, spacing: 18) {
            Text("Ders Yolu").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            if let viewModel, !viewModel.sections.isEmpty {
                ForEach(viewModel.sections, id: \.unitID) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.theme.uppercased(with: Locale(identifier: "tr_TR")))
                            .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.secondaryInk)
                        ForEach(Array(section.tasks.enumerated()), id: \.offset) { _, task in
                            PlanTaskRow(task: task, isHighlighted: false) { handle(task) }
                        }
                    }
                }
            } else if viewModel != nil {
                ContentUnavailableView("İçerik yüklenemedi", systemImage: "map")
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
        }
    }

    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startLesson(let id): activeSession = ActiveLessonSession(lessonID: id)
        case .comingSoon(let title): infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)
        case .startReview, .none: break
        }
    }

    private func refresh() {
        let vm = viewModel ?? CoursePathViewModel(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
        vm.load()
        viewModel = vm
    }
}
```

- [ ] **Step 2: Add the tab to RootTabView**

```swift
// App/Sources/EnglishApp/RootTabView.swift — inside the `if hasCompletedOnboarding` TabView, add the second tabItem
TabView {
    TodayPlanView()
        .tabItem { Label("Bugün", systemImage: "sun.max") }
    CoursePathView()
        .tabItem { Label("Ders Yolu", systemImage: "map") }
    if appState.isTutorAvailable {
        TutorTabView()
            .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
    }
    ProfileView()
        .tabItem { Label("Profil", systemImage: "person.crop.circle") }
}
.tint(Theme.primary)
```

- [ ] **Step 3: Verify via CI**

Run: `scripts/ci-app-build.sh`.
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/EnglishApp/CoursePath/CoursePathView.swift \
        App/Sources/EnglishApp/RootTabView.swift
git commit -m "$(cat <<'EOF'
Add Ders Yolu tab

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Task 8: Profil additions — CEFR badge and level-test retake

**Files:**
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift`
- Create: `App/Sources/EnglishApp/Profile/LevelTestRetakeSheet.swift`

**Interfaces:**
- Consumes: `LevelTestResult`, `CEFRLevel` (Task 1), `LevelTestViewModel`, `LevelTestCandidateFetcher` (Task 3), `LevelTestQuestionView`/`LevelTestResultView` (Task 5).
- Produces: `LevelTestRetakeSheet`; `ProfileView` shows the CEFR badge/disclaimer and a retake entry point.

No new unit tests — UI-only, verified by App Build CI (the underlying `LevelTestViewModel`/`LevelTestCandidateFetcher` logic it reuses is already covered by Task 3's tests).

- [ ] **Step 1: Add the retake sheet**

```swift
// App/Sources/EnglishApp/Profile/LevelTestRetakeSheet.swift
import SwiftUI
import SwiftData
import LearningEngine

/// Standalone re-run of the level test from Profil, for someone who skipped
/// it during onboarding (or wants a fresh estimate). Reuses the same
/// question/result views as onboarding; owns its own tiny intro screen
/// since the copy differs from the first-run context.
struct LevelTestRetakeSheet: View {
    let packageID: String
    let onFinished: (LevelTestOutcome) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LevelTestViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                content.padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LevelTestViewModel(candidates: LevelTestCandidateFetcher.fetch(packageID: packageID, in: context))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if let outcome = viewModel.outcome {
                LevelTestResultView(outcome: outcome, buttonTitle: "Tamam") {
                    onFinished(outcome)
                    dismiss()
                }
            } else if let question = viewModel.currentQuestion {
                LevelTestQuestionView(question: question, questionNumber: viewModel.questionNumber) { index in
                    viewModel.answer(selectedIndex: index)
                }
            } else if viewModel.isReady {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Seviyeni yeniden test et").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
                    Text("5-8 dakikada kelime bilgine göre yaklaşık bir seviye tahmini üretir.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    Spacer(minLength: 0)
                    Button("Başla") { viewModel.start() }.buttonStyle(PrimaryButtonStyle())
                }
            } else {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "exclamationmark.circle")
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        }
    }
}
```

- [ ] **Step 2: Wire the badge and retake entry into ProfileView**

```swift
// App/Sources/EnglishApp/Profile/ProfileView.swift — full updated file
import SwiftUI
import SwiftData
import LearningEngine

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage(DevelopmentPackageAccessProvider.unlockAllKey) private var unlockAll = false
    @State private var stats: LearnerStats?
    @State private var levelTestResult: LevelTestResult?
    @State private var hasSkippedLevelTest = false
    @State private var showLevelTestSheet = false
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

                section("SEVİYEM") {
                    if let levelTestResult {
                        row("Tahmini seviye", levelTestResult.cefrLevel.rawValue, tint: Theme.primary)
                        Divider()
                        row("Kelime bilgisi", "%\(Int((levelTestResult.vocabularyScore * 100).rounded()))")
                        Text("Bu, sadece bu paketin kelime listesine göre kaba bir tahmindir.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    } else {
                        Text(hasSkippedLevelTest ? "Seviye testini atladın." : "Henüz bir seviye tahmini yok.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                    Button(levelTestResult == nil ? "Seviye testini şimdi yap" : "Yeniden test et") {
                        showLevelTestSheet = true
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
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
        .sheet(isPresented: $showLevelTestSheet) {
            if let packageID = try? TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider).activePackage()?.id {
                LevelTestRetakeSheet(packageID: packageID) { _ in
                    appState.bumpDataGeneration()
                }
            }
        }
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
        let userID = UserIdentity.current
        stats = try? TodayPlanCoordinator(context: context, userID: userID, accessProvider: appState.accessProvider).stats()
        levelTestResult = try? context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userID })).first
        hasSkippedLevelTest = (try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first?.hasSkippedLevelTest) ?? false
    }

    private func resetAllData() {
        do {
            try context.delete(model: ContentPackage.self)
            try context.delete(model: ReviewLog.self)
            try context.delete(model: UserItemState.self)
            try context.delete(model: LessonProgress.self)
            try context.delete(model: LearnerProfile.self)
            try context.delete(model: LevelTestResult.self)
            try context.save()
            AppModelContainer.seedRealContentIfNeeded(in: context)
            appState.bumpDataGeneration()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 3: Verify via CI**

Run: `scripts/ci-app-build.sh`.
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/EnglishApp/Profile/ProfileView.swift \
        App/Sources/EnglishApp/Profile/LevelTestRetakeSheet.swift
git commit -m "$(cat <<'EOF'
Show CEFR level-test result in Profil, with a retake entry point

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin learning-engine
```

---

## Self-Review

**Spec coverage:**
- Data model changes (LearnerProfile fields, LevelTestResult, schema) → Task 1.
- Onboarding flow (state machine, step order, back-nav, deferred persistence, skip) → Tasks 4-5.
- Level test engine (staircase, distractors, CEFR bucketing, no FSRS writes) → Task 2.
- "Ders Yolu" tab (grouping, lock/access/completed, reusing PlanTaskAction) → Tasks 6-7.
- Profil CEFR badge + disclaimer + retake entry → Task 8.
- Testing approach (LevelTestEngine/OnboardingViewModel/CoursePathViewModel unit tests, views via App Build CI only) → covered in each task.

**Placeholder scan:** no TBD/TODO; every step has concrete code; no "similar to Task N" references.

**Type consistency:** `LevelTestCandidate`/`LevelTestQuestion`/`LevelTestOutcome`/`LevelTestEngine` (Task 2) are used identically in Tasks 3, 4, 5, 8. `OnboardingStep` cases match between Task 4's `OnboardingViewModel` and Task 5's `OnboardingFlowView` switch. `CoursePathSection`/`CoursePathViewModel` (Task 6) match Task 7's `CoursePathView` usage. `PlanTask`/`PlanTaskAction`/`PlanTaskRow` are reused unmodified from Slice 6a, not redefined.

**Deviation from spec, made explicit here:** the spec described `LevelTestResult.cefrLevel: String`; this plan uses a `CEFRLevel: String` rawValue enum instead, matching the codebase's existing convention for constrained string fields (`LearningGoal`, `LearningItemType`, `Skill`) — functionally equivalent, more type-safe.
