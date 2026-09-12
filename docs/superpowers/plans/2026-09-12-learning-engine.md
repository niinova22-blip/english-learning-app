# Learning Engine & Content Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone, UI-free `LearningEngine` Swift Package containing the content data model, a real FSRS-6 spaced-repetition scheduler, an i+1 comprehensible-input difficulty calculator, and an interleaving daily-session scheduler — all unit-tested via `swift test`.

**Architecture:** Local SPM package (`LearningEngine/`) with SwiftData `@Model` types for content and per-user learning state, a stateless `FSRSScheduler` implementing FSRS-6, a `ComprehensibleInputCalculator` for i+1 zone scoring, and a `DailySessionBuilder` that combines both into an ordered session. No SwiftUI/UIKit/network/LLM code in this slice.

**Tech Stack:** Swift 5.10+, SwiftData (iOS 17+), Swift Testing or XCTest (this plan uses XCTest for broad toolchain compatibility), Foundation only — no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-12-learning-engine-design.md`

## Global Constraints

- **This machine cannot run `swift test` locally** (Windows, no Swift toolchain, and SwiftData is Apple-only regardless). Verification runs on GitHub Actions `macos-latest` instead. Wherever a task step says `Run: cd LearningEngine && swift test ...`, run `bash scripts/ci-test.sh` from the repo root instead — it commits are expected to already be made, then it pushes the current branch and streams the real `swift test` result from CI (~2-4 min). Treat its PASS/FAIL exactly as you would a local `swift test` result. `--filter` scoping isn't available through this path; the full suite runs every time, which is fine at this project's size.
- Package must build and all tests must pass via `swift test` (run through `scripts/ci-test.sh`, see above), with no simulator (`swift-tools-version: 5.10`, platform `.iOS(.v17)`).
- No UIKit/SwiftUI/Combine imports anywhere in `Sources/LearningEngine`.
- No network calls, no LLM calls, no media playback in this slice.
- FSRS implementation is FSRS-6 (21 parameters), matching `open-spaced-repetition/py-fsrs` `fsrs/scheduler.py` exactly — see reference formulas embedded in Task 3/4 steps below, verified against that source on 2026-09-12.
- Every SwiftData model gets an `id: String` with `@Attribute(.unique)`.
- Commit after every task.

---

### Task 1: SPM package scaffold

**Files:**
- Create: `LearningEngine/Package.swift`
- Create: `LearningEngine/Sources/LearningEngine/LearningEngine.swift`
- Create: `LearningEngine/Tests/LearningEngineTests/PackageSmokeTests.swift`

**Interfaces:**
- Produces: `public let learningEngineVersion: String` (sanity marker other tasks don't depend on)

- [ ] **Step 1: Create the package directory structure**

```bash
mkdir -p LearningEngine/Sources/LearningEngine
mkdir -p LearningEngine/Tests/LearningEngineTests
```

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LearningEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LearningEngine", targets: ["LearningEngine"])
    ],
    targets: [
        .target(name: "LearningEngine"),
        .testTarget(name: "LearningEngineTests", dependencies: ["LearningEngine"])
    ]
)
```

- [ ] **Step 3: Write the failing smoke test**

`LearningEngine/Tests/LearningEngineTests/PackageSmokeTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class PackageSmokeTests: XCTestCase {
    func test_learningEngineVersion_isNotEmpty() {
        XCTAssertFalse(learningEngineVersion.isEmpty)
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd LearningEngine && swift test`
Expected: FAIL — `learningEngineVersion` not defined.

- [ ] **Step 5: Write minimal implementation**

`LearningEngine/Sources/LearningEngine/LearningEngine.swift`:

```swift
public let learningEngineVersion = "0.1.0"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd LearningEngine && swift test`
Expected: PASS (1 test)

- [ ] **Step 7: Commit**

```bash
git add LearningEngine/Package.swift LearningEngine/Sources LearningEngine/Tests
git commit -m "Scaffold LearningEngine SPM package"
```

---

### Task 2: FSRS-6 core types (Rating, Card, Weights)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/FSRS/FSRSRating.swift`
- Create: `LearningEngine/Sources/LearningEngine/FSRS/FSRSCard.swift`
- Create: `LearningEngine/Sources/LearningEngine/FSRS/FSRSWeights.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/FSRSWeightsTests.swift`

**Interfaces:**
- Produces: `FSRSRating` (enum, rawValue Int 1...4), `FSRSCard` (struct: `stability: Double`, `difficulty: Double`, `reps: Int`, `lapses: Int`, `lastReviewedAt: Date?`), `FSRSWeights` (struct wrapping `values: [Double]`, static `.default`)

- [ ] **Step 1: Write the failing test for weight count and defaults**

`LearningEngine/Tests/LearningEngineTests/FSRSWeightsTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class FSRSWeightsTests: XCTestCase {
    func test_default_has21Weights() {
        XCTAssertEqual(FSRSWeights.default.values.count, 21)
    }

    func test_default_matchesReferenceImplementation() {
        let w = FSRSWeights.default.values
        XCTAssertEqual(w[0], 0.212, accuracy: 1e-9)
        XCTAssertEqual(w[4], 6.4133, accuracy: 1e-9)
        XCTAssertEqual(w[20], 0.1542, accuracy: 1e-9)
    }

    func test_init_rejectsWrongLength() {
        // FSRSWeights.init is not failable; document the invariant via
        // precondition instead — this test only exercises the happy path
        // for a custom (non-default) 21-length array.
        let custom = FSRSWeights(values: Array(repeating: 1.0, count: 21))
        XCTAssertEqual(custom.values.count, 21)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd LearningEngine && swift test --filter FSRSWeightsTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write `FSRSRating.swift`**

```swift
import Foundation

public enum FSRSRating: Int, Sendable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}
```

- [ ] **Step 4: Write `FSRSCard.swift`**

```swift
import Foundation

public struct FSRSCard: Sendable, Equatable {
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?

    public init(stability: Double, difficulty: Double, reps: Int, lapses: Int, lastReviewedAt: Date?) {
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
    }
}
```

- [ ] **Step 5: Write `FSRSWeights.swift`**

The default array below is the exact FSRS-6 `DEFAULT_PARAMETERS` from
`open-spaced-repetition/py-fsrs` (`fsrs/scheduler.py`), fetched and
verified directly from source on 2026-09-12. Do not alter these
numbers.

```swift
import Foundation

public struct FSRSWeights: Sendable, Equatable {
    public let values: [Double]

    public init(values: [Double]) {
        precondition(values.count == 21, "FSRS-6 requires exactly 21 weights, got \(values.count)")
        self.values = values
    }

    /// FSRS-6 default parameters (open-spaced-repetition/py-fsrs, fsrs/scheduler.py).
    public static let `default` = FSRSWeights(values: [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
        1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ])
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd LearningEngine && swift test --filter FSRSWeightsTests`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/FSRS LearningEngine/Tests/LearningEngineTests/FSRSWeightsTests.swift
git commit -m "Add FSRS-6 core types and verified default weights"
```

---

### Task 3: FSRSScheduler — initial review (new card)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/FSRS/FSRSScheduler.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/FSRSSchedulerTests.swift`

**Interfaces:**
- Consumes: `FSRSRating`, `FSRSCard`, `FSRSWeights` (Task 2)
- Produces: `FSRSScheduler` (struct: `init(weights:requestedRetention:maximumIntervalDays:)`), `FSRSReviewResult` (struct: `card: FSRSCard`, `dueDate: Date`), `FSRSScheduler.review(card:rating:now:) -> FSRSReviewResult`, `FSRSScheduler.retrievability(of:at:) -> Double`

This task implements the full scheduler (new-card and existing-card
paths together, since they share private helpers) but tests only the
new-card path; Task 4 adds existing-card tests.

- [ ] **Step 1: Write the failing tests for new-card reviews**

These expected values were computed by hand-executing the FSRS-6
formulas (see Task 4 for the formula source) against the default
weights in Python, not guessed — reproducible via the snippet in
Task 4's header comment.

`LearningEngine/Tests/LearningEngineTests/FSRSSchedulerTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class FSRSSchedulerTests: XCTestCase {
    let scheduler = FSRSScheduler()
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed, arbitrary

    func test_newCard_ratedGood_producesReferenceStabilityAndDifficulty() {
        let result = scheduler.review(card: nil, rating: .good, now: referenceDate)
        XCTAssertEqual(result.card.stability, 2.3065, accuracy: 1e-4)
        XCTAssertEqual(result.card.difficulty, 2.118104, accuracy: 1e-4)
        XCTAssertEqual(result.card.reps, 1)
        XCTAssertEqual(result.card.lapses, 0)
    }

    func test_newCard_ratedAgain_producesReferenceStabilityAndDifficultyAndCountsAsLapse() {
        let result = scheduler.review(card: nil, rating: .again, now: referenceDate)
        XCTAssertEqual(result.card.stability, 0.212, accuracy: 1e-4)
        XCTAssertEqual(result.card.difficulty, 6.4133, accuracy: 1e-4)
        XCTAssertEqual(result.card.reps, 1)
        XCTAssertEqual(result.card.lapses, 1)
    }

    func test_newCard_dueDate_isAfterNow() {
        let result = scheduler.review(card: nil, rating: .good, now: referenceDate)
        XCTAssertGreaterThan(result.dueDate, referenceDate)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd LearningEngine && swift test --filter FSRSSchedulerTests`
Expected: FAIL — `FSRSScheduler` not defined.

- [ ] **Step 3: Write `FSRSScheduler.swift`**

```swift
import Foundation

/// FSRS-6 scheduler, ported from open-spaced-repetition/py-fsrs
/// (fsrs/scheduler.py), verified against that source on 2026-09-12.
public struct FSRSScheduler: Sendable {
    private static let stabilityMin = 0.001
    private static let difficultyMin = 1.0
    private static let difficultyMax = 10.0

    public let weights: FSRSWeights
    public let requestedRetention: Double
    public let maximumIntervalDays: Double

    private var decay: Double { -weights.values[20] }
    private var factor: Double { pow(0.9, 1 / decay) - 1 }

    public init(weights: FSRSWeights = .default, requestedRetention: Double = 0.9, maximumIntervalDays: Double = 36500) {
        precondition(requestedRetention > 0 && requestedRetention < 1, "requestedRetention must be in (0, 1)")
        self.weights = weights
        self.requestedRetention = requestedRetention
        self.maximumIntervalDays = maximumIntervalDays
    }

    public func retrievability(of card: FSRSCard, at date: Date) -> Double {
        guard let last = card.lastReviewedAt else { return 0 }
        let elapsedDays = Double(max(0, Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0))
        return pow(1 + factor * elapsedDays / card.stability, decay)
    }

    public func review(card: FSRSCard?, rating: FSRSRating, now: Date) -> FSRSReviewResult {
        let w = weights.values
        let newCard: FSRSCard
        if let card, card.reps > 0 {
            // IMPORTANT: both stability formulas below must use card.difficulty
            // (the OLD, pre-review difficulty), never the new one computed after
            // this block. The real py-fsrs reference computes stability first
            // from the old difficulty, then updates difficulty afterward —
            // verified directly against open-spaced-repetition/py-fsrs
            // scheduler.py's `review_card` (State.Review branch) during Task 3's
            // review. Swapping this order silently corrupts every scheduling
            // interval for existing cards.
            let r = retrievability(of: card, at: now)
            let newStability: Double
            if rating == .again {
                // _next_forget_stability: the real reference also caps this
                // long-term formula with a short-term cap (w[17], w[18]) via
                // min() — omitting the min() here (as an earlier draft of this
                // formula did) is a confirmed correctness gap, not a stylistic
                // choice.
                let longTerm = w[11] * pow(card.difficulty, -w[12]) * (pow(card.stability + 1, w[13]) - 1) * exp((1 - r) * w[14])
                let shortTerm = card.stability / exp(w[17] * w[18])
                newStability = min(longTerm, shortTerm)
            } else {
                let hardPenalty = rating == .hard ? w[15] : 1
                let easyBonus = rating == .easy ? w[16] : 1
                newStability = card.stability * (1 + exp(w[8]) * (11 - card.difficulty) * pow(card.stability, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
            }
            let newDifficulty = nextDifficulty(previous: card.difficulty, rating: rating, w: w)
            newCard = FSRSCard(
                stability: clampStability(newStability),
                difficulty: newDifficulty,
                reps: card.reps + 1,
                lapses: card.lapses + (rating == .again ? 1 : 0),
                lastReviewedAt: now
            )
        } else {
            let initialStability = clampStability(w[rating.rawValue - 1])
            let initialDifficulty = clampDifficulty(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1)
            newCard = FSRSCard(
                stability: initialStability,
                difficulty: initialDifficulty,
                reps: 1,
                lapses: rating == .again ? 1 : 0,
                lastReviewedAt: now
            )
        }
        let intervalDays = nextIntervalDays(stability: newCard.stability)
        let dueDate = Calendar.current.date(byAdding: .day, value: Int(intervalDays.rounded()), to: now) ?? now
        return FSRSReviewResult(card: newCard, dueDate: dueDate)
    }

    private func nextDifficulty(previous: Double, rating: FSRSRating, w: [Double]) -> Double {
        let easyReference = w[4] - exp(w[5] * Double(FSRSRating.easy.rawValue - 1)) + 1
        let deltaDifficulty = -(w[6] * (Double(rating.rawValue) - 3))
        let damped = previous + (10.0 - previous) * deltaDifficulty / 9.0
        let reverted = w[7] * easyReference + (1 - w[7]) * damped
        return clampDifficulty(reverted)
    }

    private func nextIntervalDays(stability: Double) -> Double {
        let raw = (stability / factor) * (pow(requestedRetention, 1 / decay) - 1)
        return min(max(raw, 1), maximumIntervalDays)
    }

    private func clampStability(_ value: Double) -> Double { max(value, Self.stabilityMin) }
    private func clampDifficulty(_ value: Double) -> Double { min(max(value, Self.difficultyMin), Self.difficultyMax) }
}

public struct FSRSReviewResult: Sendable, Equatable {
    public let card: FSRSCard
    public let dueDate: Date
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd LearningEngine && swift test --filter FSRSSchedulerTests`
Expected: PASS (3 tests). If any assertion is off by more than the
tolerance, re-derive the formula against the py-fsrs source
(`fsrs/scheduler.py`, methods `_initial_stability`,
`_initial_difficulty`, `_clamp_difficulty`) rather than adjusting the
expected numbers — the numbers are the ground truth, the Swift code is
what's suspect.

- [ ] **Step 5: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/FSRS/FSRSScheduler.swift LearningEngine/Tests/LearningEngineTests/FSRSSchedulerTests.swift
git commit -m "Implement FSRS-6 scheduler for new-card reviews"
```

---

### Task 4: FSRSScheduler — subsequent reviews (existing card)

**Files:**
- Modify: `LearningEngine/Tests/LearningEngineTests/FSRSSchedulerTests.swift`

**Interfaces:**
- Consumes: `FSRSScheduler.review(card:rating:now:)` (Task 3) — no production code changes, `review` already handles both branches.

These reference values were computed with this Python (not shipped in
the repo — recorded here for reproducibility if the fixtures ever need
regenerating):

```python
import math
w = [0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
     1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
     1.8729, 0.5425, 0.0912, 0.0658, 0.1542]
DECAY = -w[20]; FACTOR = 0.9 ** (1/DECAY) - 1
def clamp_d(d): return min(max(d, 1.0), 10.0)
def clamp_s(s): return max(s, 0.001)
def retrievability(t, s): return (1 + FACTOR*t/s) ** DECAY
s1, d1 = clamp_s(w[2]), clamp_d(w[4] - math.exp(w[5]*2) + 1)  # first review: Good
r = retrievability(2, s1)  # second review 2 days later
easy_ref = w[4] - math.exp(w[5]*3) + 1
# Both stability formulas use the OLD difficulty d1, never a newly-computed
# one — matches open-spaced-repetition/py-fsrs's review_card (State.Review):
# stability is derived first from card.difficulty, difficulty is updated after.
s2_good = clamp_s(s1 * (1 + math.exp(w[8])*(11-d1)*(s1**-w[9])*(math.exp((1-r)*w[10])-1)))
d2_good = clamp_d(w[7]*easy_ref + (1-w[7])*(d1 + (10-d1)*(-(w[6]*0))/9))
# _next_forget_stability also mins the long-term formula against a
# short-term cap (w[17], w[18]) — both terms shown for clarity.
s2_again_long = w[11] * (d1**-w[12]) * (((s1+1)**w[13])-1) * math.exp((1-r)*w[14])
s2_again_short = s1 / math.exp(w[17]*w[18])
s2_again = clamp_s(min(s2_again_long, s2_again_short))
d2_again = clamp_d(w[7]*easy_ref + (1-w[7])*(d1 + (10-d1)*(-(w[6]*-2))/9))
```

- [ ] **Step 1: Add the failing tests for a second review**

Append to `FSRSSchedulerTests.swift`:

```swift
    func test_secondReview_ratedGood_afterTwoDays_producesReferenceValues() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: referenceDate)!
        let second = scheduler.review(card: first.card, rating: .good, now: twoDaysLater)
        XCTAssertEqual(second.card.difficulty, 2.111214, accuracy: 1e-4)
        XCTAssertEqual(second.card.stability, 10.964332, accuracy: 1e-3)
        XCTAssertEqual(second.card.reps, 2)
        XCTAssertEqual(second.card.lapses, 0)
    }

    func test_secondReview_ratedAgain_afterTwoDays_producesReferenceValuesAndIncrementsLapses() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: referenceDate)!
        let second = scheduler.review(card: first.card, rating: .again, now: twoDaysLater)
        XCTAssertEqual(second.card.difficulty, 7.394503, accuracy: 1e-4)
        XCTAssertEqual(second.card.stability, 0.607580, accuracy: 1e-3)
        XCTAssertEqual(second.card.reps, 2)
        XCTAssertEqual(second.card.lapses, 1)
    }

    func test_retrievability_decreasesAsElapsedTimeIncreases() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let soon = Calendar.current.date(byAdding: .day, value: 1, to: referenceDate)!
        let later = Calendar.current.date(byAdding: .day, value: 10, to: referenceDate)!
        XCTAssertGreaterThan(
            scheduler.retrievability(of: first.card, at: soon),
            scheduler.retrievability(of: first.card, at: later)
        )
    }
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd LearningEngine && swift test --filter FSRSSchedulerTests`
Expected: the 3 new tests should actually already PASS if Task 3's
implementation is correct, since `review()` already handles the
existing-card branch — this task is validating that branch, not adding
new code. If they fail, fix `FSRSScheduler.swift`, not the test values.

- [ ] **Step 3: Run full FSRS test suite to confirm everything passes**

Run: `cd LearningEngine && swift test --filter FSRSSchedulerTests`
Expected: PASS (6 tests total)

- [ ] **Step 4: Commit**

```bash
git add LearningEngine/Tests/LearningEngineTests/FSRSSchedulerTests.swift
git commit -m "Add subsequent-review test coverage for FSRS-6 scheduler"
```

---

### Task 5: SwiftData content models

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/Unit.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/Lesson.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/LearningItem.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/ItemContent.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/ContentModelTests.swift`

**Interfaces:**
- Produces: `LearningGoal` (enum), `ContentPackage`, `Unit`, `Lesson`, `LearningItemType` (enum), `LearningItem`, `ItemContent` — all SwiftData `@Model` classes (except the enums).

- [ ] **Step 1: Write the failing persistence round-trip test**

`LearningEngine/Tests/LearningEngineTests/ContentModelTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd LearningEngine && swift test --filter ContentModelTests`
Expected: FAIL — model types not defined.

- [ ] **Step 3: Write `ContentPackage.swift`**

```swift
import Foundation
import SwiftData

public enum LearningGoal: String, Codable, CaseIterable, Sendable {
    case yds, toefl, business, conversational, custom
}

@Model
public final class ContentPackage {
    @Attribute(.unique) public var id: String
    public var name: String
    public var goal: LearningGoal
    public var levelLower: String
    public var levelUpper: String
    @Relationship(deleteRule: .cascade, inverse: \Unit.package)
    public var units: [Unit] = []

    public init(id: String, name: String, goal: LearningGoal, levelLower: String, levelUpper: String) {
        self.id = id
        self.name = name
        self.goal = goal
        self.levelLower = levelLower
        self.levelUpper = levelUpper
    }
}
```

- [ ] **Step 4: Write `Unit.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class Unit {
    @Attribute(.unique) public var id: String
    public var theme: String
    public var order: Int
    public var package: ContentPackage?
    @Relationship(deleteRule: .cascade, inverse: \Lesson.unit)
    public var lessons: [Lesson] = []

    public init(id: String, theme: String, order: Int) {
        self.id = id
        self.theme = theme
        self.order = order
    }
}
```

- [ ] **Step 5: Write `Lesson.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class Lesson {
    @Attribute(.unique) public var id: String
    public var order: Int
    public var estimatedDurationMinutes: Int
    public var unit: Unit?
    @Relationship(deleteRule: .cascade, inverse: \LearningItem.lesson)
    public var items: [LearningItem] = []

    public init(id: String, order: Int, estimatedDurationMinutes: Int) {
        self.id = id
        self.order = order
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }
}
```

- [ ] **Step 6: Write `LearningItem.swift`**

```swift
import Foundation
import SwiftData

public enum LearningItemType: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammarPoint, phrase, collocation
}

@Model
public final class LearningItem {
    @Attribute(.unique) public var id: String
    public var type: LearningItemType
    public var frequencyRank: Int
    public var baseDifficulty: Double
    public var lesson: Lesson?
    @Relationship(deleteRule: .cascade, inverse: \ItemContent.item)
    public var content: ItemContent?

    public init(id: String, type: LearningItemType, frequencyRank: Int, baseDifficulty: Double) {
        self.id = id
        self.type = type
        self.frequencyRank = frequencyRank
        self.baseDifficulty = baseDifficulty
    }
}
```

- [ ] **Step 7: Write `ItemContent.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class ItemContent {
    @Attribute(.unique) public var id: String
    public var definition: String
    public var exampleSentences: [String]
    public var translationTR: String
    public var collocations: [String]
    public var videoURL: URL?
    public var audioURL: URL?
    public var imageURL: URL?
    public var item: LearningItem?

    public init(
        id: String,
        definition: String,
        exampleSentences: [String],
        translationTR: String,
        collocations: [String],
        videoURL: URL? = nil,
        audioURL: URL? = nil,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.definition = definition
        self.exampleSentences = exampleSentences
        self.translationTR = translationTR
        self.collocations = collocations
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.imageURL = imageURL
    }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd LearningEngine && swift test --filter ContentModelTests`
Expected: PASS (1 test)

- [ ] **Step 9: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Models LearningEngine/Tests/LearningEngineTests/ContentModelTests.swift
git commit -m "Add SwiftData content model (package/unit/lesson/item/content)"
```

---

### Task 6: SwiftData user-state models + FSRS bridge

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Models/ReviewLog.swift`
- Create: `LearningEngine/Sources/LearningEngine/Models/UserItemState.swift`
- Create: `LearningEngine/Sources/LearningEngine/FSRS/FSRSStateStore.swift`
- Modify: `LearningEngine/Sources/LearningEngine/FSRS/FSRSRating.swift` (add `Codable` conformance, see Step 4)
- Test: `LearningEngine/Tests/LearningEngineTests/FSRSStateStoreTests.swift`

**Interfaces:**
- Consumes: `FSRSScheduler`, `FSRSCard`, `FSRSRating`, `FSRSReviewResult` (Tasks 2-4)
- Produces: `ReviewLog`, `UserItemState` (SwiftData models), `FSRSStateStore.recordReview(userID:itemID:rating:now:in:scheduler:) throws -> UserItemState`

- [ ] **Step 1: Write the failing test**

`LearningEngine/Tests/LearningEngineTests/FSRSStateStoreTests.swift`:

```swift
import XCTest
import SwiftData
@testable import LearningEngine

final class FSRSStateStoreTests: XCTestCase {
    func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ReviewLog.self, UserItemState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func test_recordReview_createsStateOnFirstReview() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let store = FSRSStateStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let state = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: now, in: context, scheduler: FSRSScheduler())

        XCTAssertEqual(state.userID, "u1")
        XCTAssertEqual(state.itemID, "item-1")
        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.stability, 2.3065, accuracy: 1e-4)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.rating, .good)
    }

    func test_recordReview_updatesExistingStateOnSecondReview() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let store = FSRSStateStore()
        let scheduler = FSRSScheduler()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Calendar.current.date(byAdding: .day, value: 2, to: first)!

        _ = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: first, in: context, scheduler: scheduler)
        let updated = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: second, in: context, scheduler: scheduler)

        XCTAssertEqual(updated.reps, 2)
        XCTAssertEqual(updated.stability, 10.964332, accuracy: 1e-3)

        let states = try context.fetch(FetchDescriptor<UserItemState>())
        XCTAssertEqual(states.count, 1, "second review must update the existing state, not create a duplicate")

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd LearningEngine && swift test --filter FSRSStateStoreTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write `ReviewLog.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class ReviewLog {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var itemID: String
    public var rating: FSRSRating
    public var reviewedAt: Date
    public var reactionTimeMs: Int

    public init(id: String = UUID().uuidString, userID: String, itemID: String, rating: FSRSRating, reviewedAt: Date, reactionTimeMs: Int = 0) {
        self.id = id
        self.userID = userID
        self.itemID = itemID
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.reactionTimeMs = reactionTimeMs
    }
}
```

`FSRSRating` needs `Codable` for SwiftData to store it as an attribute — add conformance:

- [ ] **Step 4: Make `FSRSRating` `Codable`**

In `LearningEngine/Sources/LearningEngine/FSRS/FSRSRating.swift`, change:

```swift
public enum FSRSRating: Int, Sendable, CaseIterable {
```

to:

```swift
public enum FSRSRating: Int, Codable, Sendable, CaseIterable {
```

- [ ] **Step 5: Write `UserItemState.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class UserItemState {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var itemID: String
    public var stability: Double
    public var difficulty: Double
    public var dueDate: Date
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?

    public init(userID: String, itemID: String, stability: Double, difficulty: Double, dueDate: Date, reps: Int, lapses: Int, lastReviewedAt: Date?) {
        self.id = "\(userID)_\(itemID)"
        self.userID = userID
        self.itemID = itemID
        self.stability = stability
        self.difficulty = difficulty
        self.dueDate = dueDate
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
    }

    func apply(_ result: FSRSReviewResult) {
        stability = result.card.stability
        difficulty = result.card.difficulty
        dueDate = result.dueDate
        reps = result.card.reps
        lapses = result.card.lapses
        lastReviewedAt = result.card.lastReviewedAt
    }
}
```

- [ ] **Step 6: Write `FSRSStateStore.swift`**

```swift
import Foundation
import SwiftData

/// Bridges SwiftData-persisted UserItemState/ReviewLog to the stateless FSRSScheduler.
public struct FSRSStateStore: Sendable {
    public init() {}

    @discardableResult
    public func recordReview(
        userID: String,
        itemID: String,
        rating: FSRSRating,
        now: Date,
        in context: ModelContext,
        scheduler: FSRSScheduler
    ) throws -> UserItemState {
        let stateID = "\(userID)_\(itemID)"
        let descriptor = FetchDescriptor<UserItemState>(predicate: #Predicate { $0.id == stateID })
        let existing = try context.fetch(descriptor).first

        let priorCard = existing.map {
            FSRSCard(stability: $0.stability, difficulty: $0.difficulty, reps: $0.reps, lapses: $0.lapses, lastReviewedAt: $0.lastReviewedAt)
        }
        let result = scheduler.review(card: priorCard, rating: rating, now: now)

        let state: UserItemState
        if let existing {
            existing.apply(result)
            state = existing
        } else {
            state = UserItemState(
                userID: userID,
                itemID: itemID,
                stability: result.card.stability,
                difficulty: result.card.difficulty,
                dueDate: result.dueDate,
                reps: result.card.reps,
                lapses: result.card.lapses,
                lastReviewedAt: result.card.lastReviewedAt
            )
            context.insert(state)
        }

        let log = ReviewLog(userID: userID, itemID: itemID, rating: rating, reviewedAt: now)
        context.insert(log)
        try context.save()
        return state
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd LearningEngine && swift test --filter FSRSStateStoreTests`
Expected: PASS (2 tests)

- [ ] **Step 8: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Models/ReviewLog.swift LearningEngine/Sources/LearningEngine/Models/UserItemState.swift LearningEngine/Sources/LearningEngine/FSRS/FSRSStateStore.swift LearningEngine/Sources/LearningEngine/FSRS/FSRSRating.swift LearningEngine/Tests/LearningEngineTests/FSRSStateStoreTests.swift
git commit -m "Add per-user FSRS state persistence bridge"
```

---

### Task 7: Sample content fixtures

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/SampleData/SampleContent.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/SampleContentTests.swift`

**Interfaces:**
- Consumes: `ContentPackage`, `Unit`, `Lesson`, `LearningItem`, `ItemContent`, `LearningGoal`, `LearningItemType` (Task 5)
- Produces: `SampleContent.ydsStarterPackage() -> ContentPackage` (fully wired package/unit/lesson/items, not yet inserted into any context)

- [ ] **Step 1: Write the failing test**

`LearningEngine/Tests/LearningEngineTests/SampleContentTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class SampleContentTests: XCTestCase {
    func test_ydsStarterPackage_hasWiredHierarchy() {
        let package = SampleContent.ydsStarterPackage()

        XCTAssertEqual(package.goal, .yds)
        XCTAssertFalse(package.units.isEmpty)

        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertGreaterThanOrEqual(allItems.count, 15)
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
        XCTAssertTrue(allItems.allSatisfy { $0.lesson != nil })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd LearningEngine && swift test --filter SampleContentTests`
Expected: FAIL — `SampleContent` not defined.

- [ ] **Step 3: Write `SampleContent.swift`**

Build a small but real YDS starter package: 1 package, 2 units, 2
lessons per unit, ~4-5 items per lesson (18 items total), each with
real definitions/examples so later slices have something legible to
preview against.

```swift
import Foundation

public enum SampleContent {
    public static func ydsStarterPackage() -> ContentPackage {
        let package = ContentPackage(id: "sample-yds", name: "YDS Başlangıç", goal: .yds, levelLower: "B2", levelUpper: "C1")

        let businessUnit = Unit(id: "sample-unit-business", theme: "Business & Finance", order: 0)
        businessUnit.lessons = [
            makeLesson(id: "sample-lesson-business-1", order: 0, items: [
                item("serendipity", .vocabulary, frequencyRank: 4821, definition: "a pleasant surprise found by chance", examples: ["Meeting her was pure serendipity."], tr: "tesadüfi mutluluk", collocations: ["pure serendipity"]),
                item("leverage", .vocabulary, frequencyRank: 1890, definition: "use something to maximum advantage", examples: ["The company leveraged its brand to enter new markets."], tr: "kaldıraç etkisi kullanmak", collocations: ["leverage resources", "leverage a position"]),
                item("in the long run", .phrase, frequencyRank: 2200, definition: "over a long period of time, eventually", examples: ["It will save money in the long run."], tr: "uzun vadede", collocations: []),
                item("mitigate", .vocabulary, frequencyRank: 3100, definition: "make something less severe", examples: ["They took steps to mitigate the risk."], tr: "hafifletmek", collocations: ["mitigate risk", "mitigate damage"])
            ]),
            makeLesson(id: "sample-lesson-business-2", order: 1, items: [
                item("present perfect for unfinished actions", .grammarPoint, frequencyRank: 1, definition: "use 'have/has + past participle' for actions started in the past and continuing now", examples: ["She has worked here since 2019."], tr: "geçmişte başlayıp devam eden eylemler için present perfect", collocations: []),
                item("stakeholder", .vocabulary, frequencyRank: 2650, definition: "a person with an interest in a business", examples: ["All stakeholders were informed of the decision."], tr: "paydaş", collocations: ["key stakeholder"]),
                item("bear in mind", .phrase, frequencyRank: 3400, definition: "remember, take into consideration", examples: ["Bear in mind that prices may change."], tr: "aklında bulundurmak", collocations: []),
                item("streamline", .vocabulary, frequencyRank: 3900, definition: "make a process more efficient", examples: ["The new software streamlined our workflow."], tr: "kolaylaştırmak", collocations: ["streamline a process"]),
                item("make a decision", .collocation, frequencyRank: 500, definition: "decide", examples: ["The board will make a decision next week."], tr: "karar vermek", collocations: ["make a quick decision"])
            ])
        ]

        let scienceUnit = Unit(id: "sample-unit-science", theme: "Science & Technology", order: 1)
        scienceUnit.lessons = [
            makeLesson(id: "sample-lesson-science-1", order: 0, items: [
                item("unprecedented", .vocabulary, frequencyRank: 4300, definition: "never having happened before", examples: ["The research showed unprecedented results."], tr: "eşi görülmemiş", collocations: ["unprecedented growth"]),
                item("albeit", .vocabulary, frequencyRank: 3700, definition: "although", examples: ["The plan worked, albeit slowly."], tr: "gerçi, her ne kadar", collocations: []),
                item("hypothesis", .vocabulary, frequencyRank: 2900, definition: "a proposed explanation to be tested", examples: ["The hypothesis was confirmed by the experiment."], tr: "hipotez", collocations: ["test a hypothesis"]),
                item("passive voice in academic writing", .grammarPoint, frequencyRank: 2, definition: "using 'be + past participle' to focus on the action, common in academic texts", examples: ["The data were collected over six months."], tr: "akademik yazımda edilgen çatı", collocations: [])
            ]),
            makeLesson(id: "sample-lesson-science-2", order: 1, items: [
                item("ubiquitous", .vocabulary, frequencyRank: 4600, definition: "present everywhere", examples: ["Smartphones have become ubiquitous."], tr: "her yerde bulunan", collocations: []),
                item("counterintuitive", .vocabulary, frequencyRank: 4950, definition: "opposite to what you would expect", examples: ["The result was counterintuitive."], tr: "sezgiye aykırı", collocations: []),
                item("draw a conclusion", .collocation, frequencyRank: 1200, definition: "reach a judgment after considering facts", examples: ["It's too early to draw a conclusion."], tr: "sonuca varmak", collocations: []),
                item("shed light on", .phrase, frequencyRank: 2800, definition: "help explain something", examples: ["The study sheds light on climate patterns."], tr: "aydınlatmak, açıklık getirmek", collocations: []),
                item("empirical evidence", .collocation, frequencyRank: 3300, definition: "evidence based on observation or experiment", examples: ["The claim lacks empirical evidence."], tr: "ampirik kanıt", collocations: [])
            ])
        ]

        package.units = [businessUnit, scienceUnit]
        return package
    }

    private static func makeLesson(id: String, order: Int, items: [LearningItem]) -> Lesson {
        let lesson = Lesson(id: id, order: order, estimatedDurationMinutes: 4)
        lesson.items = items
        for item in items { item.lesson = lesson }
        return lesson
    }

    private static func item(_ headword: String, _ type: LearningItemType, frequencyRank: Int, definition: String, examples: [String], tr: String, collocations: [String]) -> LearningItem {
        let id = "sample-item-\(headword.lowercased().replacingOccurrences(of: " ", with: "-"))"
        let learningItem = LearningItem(id: id, type: type, frequencyRank: frequencyRank, baseDifficulty: Double(frequencyRank) / 5000.0)
        let content = ItemContent(id: "\(id)-content", definition: definition, exampleSentences: examples, translationTR: tr, collocations: collocations)
        learningItem.content = content
        content.item = learningItem
        return learningItem
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd LearningEngine && swift test --filter SampleContentTests`
Expected: PASS (1 test, 18 items)

- [ ] **Step 5: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/SampleData LearningEngine/Tests/LearningEngineTests/SampleContentTests.swift
git commit -m "Add sample YDS content fixtures"
```

---

### Task 8: ComprehensibleInputCalculator (i+1 difficulty fit)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Adaptive/UserLevelSnapshot.swift`
- Create: `LearningEngine/Sources/LearningEngine/Adaptive/DifficultyFit.swift`
- Create: `LearningEngine/Sources/LearningEngine/Adaptive/ComprehensibleInputCalculator.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/ComprehensibleInputCalculatorTests.swift`

**Interfaces:**
- Consumes: `LearningItem` (Task 5)
- Produces: `UserLevelSnapshot` (struct: `knownItemIDs: Set<String>`, `rollingComprehensionAccuracy: Double`, `averageReactionTimeMs: Double`), `DifficultyFit` (enum: `.tooEasy`, `.optimal`, `.tooHard`), `ComprehensibleInputCalculator.fit(of:for:) -> DifficultyFit`

Thresholds come from the approved design spec: ≥85% comprehension →
too easy (skip ahead), 70-84% → optimal ("+1"), ≤50% → too hard (fall
back to review); 51-69% is also treated as optimal (the productive
struggle zone between "too hard" and "clearly too easy").

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/ComprehensibleInputCalculatorTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class ComprehensibleInputCalculatorTests: XCTestCase {
    let calculator = ComprehensibleInputCalculator()
    let candidate = LearningItem(id: "candidate", type: .vocabulary, frequencyRank: 3000, baseDifficulty: 0.5)

    func test_fit_returnsTooEasy_whenAccuracyAtOrAbove85Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.85, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .tooEasy)
    }

    func test_fit_returnsOptimal_atExactly70Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.70, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal)
    }

    func test_fit_returnsOptimal_atExactly51Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.51, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal)
    }

    func test_fit_returnsTooHard_atOrBelow50Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.50, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .tooHard)
    }

    func test_fit_returnsOptimal_forFirstEverItem_withNoHistory() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal, "cold start must not fall into 'too hard' just because accuracy defaults to 0")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd LearningEngine && swift test --filter ComprehensibleInputCalculatorTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write `UserLevelSnapshot.swift`**

```swift
import Foundation

public struct UserLevelSnapshot: Sendable, Equatable {
    public var knownItemIDs: Set<String>
    public var rollingComprehensionAccuracy: Double
    public var averageReactionTimeMs: Double

    public init(knownItemIDs: Set<String>, rollingComprehensionAccuracy: Double, averageReactionTimeMs: Double) {
        self.knownItemIDs = knownItemIDs
        self.rollingComprehensionAccuracy = rollingComprehensionAccuracy
        self.averageReactionTimeMs = averageReactionTimeMs
    }

    /// True when there's no meaningful review history yet (both fields still at their defaults).
    public var isColdStart: Bool {
        rollingComprehensionAccuracy == 0 && averageReactionTimeMs == 0
    }
}
```

- [ ] **Step 4: Write `DifficultyFit.swift`**

```swift
public enum DifficultyFit: Sendable, Equatable {
    case tooEasy
    case optimal
    case tooHard
}
```

- [ ] **Step 5: Write `ComprehensibleInputCalculator.swift`**

```swift
import Foundation

public struct ComprehensibleInputCalculator: Sendable {
    public var tooEasyThreshold: Double
    public var tooHardThreshold: Double

    public init(tooEasyThreshold: Double = 0.85, tooHardThreshold: Double = 0.50) {
        self.tooEasyThreshold = tooEasyThreshold
        self.tooHardThreshold = tooHardThreshold
    }

    public func fit(of item: LearningItem, for snapshot: UserLevelSnapshot) -> DifficultyFit {
        if snapshot.isColdStart { return .optimal }
        if snapshot.rollingComprehensionAccuracy >= tooEasyThreshold { return .tooEasy }
        if snapshot.rollingComprehensionAccuracy <= tooHardThreshold { return .tooHard }
        return .optimal
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd LearningEngine && swift test --filter ComprehensibleInputCalculatorTests`
Expected: PASS (5 tests)

- [ ] **Step 7: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Adaptive LearningEngine/Tests/LearningEngineTests/ComprehensibleInputCalculatorTests.swift
git commit -m "Add i+1 comprehensible-input difficulty calculator"
```

---

### Task 9: DailySessionBuilder (interleaving scheduler)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Scheduling/LearningPhase.swift`
- Create: `LearningEngine/Sources/LearningEngine/Scheduling/DailySessionBuilder.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/DailySessionBuilderTests.swift`

**Interfaces:**
- Consumes: `LearningItem`, `LearningItemType` (Task 5), `UserItemState` (Task 6), `FSRSScheduler.retrievability(of:at:)` (Task 3), `ComprehensibleInputCalculator`, `UserLevelSnapshot`, `DifficultyFit` (Task 8)
- Produces: `LearningPhase` (enum: `.blocked`, `.hybrid`, `.fullInterleaving`), `DailySessionBuilder.buildSession(candidateItems:dueStates:phase:topicAccuracy:snapshot:sessionSize:) -> [LearningItem]`

- [ ] **Step 1: Write the failing tests**

`LearningEngine/Tests/LearningEngineTests/DailySessionBuilderTests.swift`:

```swift
import XCTest
@testable import LearningEngine

final class DailySessionBuilderTests: XCTestCase {
    let builder = DailySessionBuilder()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ id: String, _ type: LearningItemType) -> LearningItem {
        LearningItem(id: id, type: type, frequencyRank: 1000, baseDifficulty: 0.5)
    }

    func test_buildSession_prioritizesLowestRetrievabilityDueItems() {
        let staleItem = item("stale", .vocabulary)
        let freshItem = item("fresh", .vocabulary)
        let staleState = UserItemState(userID: "u1", itemID: "stale", stability: 2, difficulty: 5, dueDate: now, reps: 1, lapses: 0, lastReviewedAt: Calendar.current.date(byAdding: .day, value: -10, to: now))
        let freshState = UserItemState(userID: "u1", itemID: "fresh", stability: 2, difficulty: 5, dueDate: now, reps: 1, lapses: 0, lastReviewedAt: Calendar.current.date(byAdding: .day, value: -1, to: now))

        let session = builder.buildSession(
            candidateItems: [staleItem, freshItem],
            dueStates: [staleState, freshState],
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 2
        )

        XCTAssertEqual(session.first?.id, "stale", "the item closer to being forgotten should come first")
    }

    func test_buildSession_blockedPhase_onlyIncludesSingleDominantTopic() {
        let items = [item("verb-1", .grammarPoint), item("verb-2", .grammarPoint), item("noun-1", .vocabulary)]

        let session = builder.buildSession(
            candidateItems: items,
            dueStates: [],
            phase: .blocked(dominantTopic: .grammarPoint),
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0),
            sessionSize: 5
        )

        XCTAssertTrue(session.allSatisfy { $0.type == .grammarPoint })
    }

    func test_buildSession_fullInterleaving_favorsWeakestTopic() {
        let phrasalItems = (0..<10).map { item("phrasal-\($0)", .phrase) }
        let vocabItems = (0..<10).map { item("vocab-\($0)", .vocabulary) }

        let session = builder.buildSession(
            candidateItems: phrasalItems + vocabItems,
            dueStates: [],
            phase: .fullInterleaving,
            topicAccuracy: [.phrase: 0.40, .vocabulary: 0.95],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 10
        )

        let phrasalCount = session.filter { $0.type == .phrase }.count
        XCTAssertGreaterThan(phrasalCount, session.count / 2, "weakest topic (phrasal verbs, 40% accuracy) should dominate the session")
    }

    func test_buildSession_respectsSessionSize() {
        let items = (0..<50).map { item("item-\($0)", .vocabulary) }
        let session = builder.buildSession(
            candidateItems: items,
            dueStates: [],
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 12
        )
        XCTAssertEqual(session.count, 12)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd LearningEngine && swift test --filter DailySessionBuilderTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write `LearningPhase.swift`**

```swift
public enum LearningPhase: Sendable, Equatable {
    case blocked(dominantTopic: LearningItemType)
    case hybrid(primaryWeakTopic: LearningItemType)
    case fullInterleaving
}
```

- [ ] **Step 4: Write `DailySessionBuilder.swift`**

```swift
import Foundation

public struct DailySessionBuilder: Sendable {
    private let scheduler: FSRSScheduler
    private let calculator: ComprehensibleInputCalculator

    public init(scheduler: FSRSScheduler = FSRSScheduler(), calculator: ComprehensibleInputCalculator = ComprehensibleInputCalculator()) {
        self.scheduler = scheduler
        self.calculator = calculator
    }

    public func buildSession(
        candidateItems: [LearningItem],
        dueStates: [UserItemState],
        phase: LearningPhase,
        topicAccuracy: [LearningItemType: Double],
        snapshot: UserLevelSnapshot,
        sessionSize: Int,
        now: Date = Date()
    ) -> [LearningItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: candidateItems.map { ($0.id, $0) })

        let dueItems = dueStates
            .sorted { lhs, rhs in
                retrievability(of: lhs, at: now) < retrievability(of: rhs, at: now)
            }
            .compactMap { itemsByID[$0.itemID] }

        let dueIDs = Set(dueItems.map(\.id))
        let newCandidates = candidateItems
            .filter { !dueIDs.contains($0.id) }
            .filter { calculator.fit(of: $0, for: snapshot) == .optimal }

        let pool = orderByPhase(dueItems + newCandidates, phase: phase, topicAccuracy: topicAccuracy)
        return Array(pool.prefix(sessionSize))
    }

    private func retrievability(of state: UserItemState, at date: Date) -> Double {
        let card = FSRSCard(stability: state.stability, difficulty: state.difficulty, reps: state.reps, lapses: state.lapses, lastReviewedAt: state.lastReviewedAt)
        return scheduler.retrievability(of: card, at: date)
    }

    private func orderByPhase(_ items: [LearningItem], phase: LearningPhase, topicAccuracy: [LearningItemType: Double]) -> [LearningItem] {
        switch phase {
        case .blocked(let dominantTopic):
            return items.filter { $0.type == dominantTopic }

        case .hybrid(let primaryWeakTopic):
            let weak = items.filter { $0.type == primaryWeakTopic }
            let rest = items.filter { $0.type != primaryWeakTopic }
            return weightedRoundRobin(groups: [(weak, 0.4), (rest, 0.6)])

        case .fullInterleaving:
            let grouped = Dictionary(grouping: items, by: \.type)
            let maxShare = 0.6
            var weights = grouped.keys.reduce(into: [LearningItemType: Double]()) { result, type in
                // Lower accuracy -> higher weight, so the weakest topic gets a
                // bigger share. Topics with no recorded accuracy default to 0.7
                // (moderately known) so unmeasured topics don't dominate.
                result[type] = 1 - (topicAccuracy[type] ?? 0.7)
            }
            normalize(&weights)
            for key in weights.keys { weights[key] = min(weights[key] ?? 0, maxShare) }
            normalize(&weights)
            let groups = grouped.map { (type, groupItems) in (groupItems, weights[type] ?? 0) }
            return weightedRoundRobin(groups: groups)
        }
    }

    private func normalize(_ weights: inout [LearningItemType: Double]) {
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return }
        for key in weights.keys { weights[key]! /= total }
    }

    /// Deficit-style weighted round robin: at each step, emits from whichever
    /// group is furthest behind the share of output its weight entitles it to,
    /// so groups interleave roughly proportionally instead of one group
    /// exhausting itself before the next starts.
    private func weightedRoundRobin(groups: [(items: [LearningItem], weight: Double)]) -> [LearningItem] {
        var remaining = groups.map { $0.items }
        let weights = groups.map { $0.weight }
        var taken = Array(repeating: 0, count: groups.count)
        var result: [LearningItem] = []
        let total = remaining.reduce(0) { $0 + $1.count }

        while result.count < total {
            var bestIndex: Int?
            var bestDeficit = -Double.infinity
            for i in remaining.indices where !remaining[i].isEmpty {
                let deserved = weights[i] * Double(result.count + 1)
                let deficit = deserved - Double(taken[i])
                if deficit > bestDeficit {
                    bestDeficit = deficit
                    bestIndex = i
                }
            }
            guard let index = bestIndex else { break }
            result.append(remaining[index].removeFirst())
            taken[index] += 1
        }
        return result
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd LearningEngine && swift test --filter DailySessionBuilderTests`
Expected: PASS (4 tests). If `test_buildSession_fullInterleaving_favorsWeakestTopic`
fails, check that weights in `orderByPhase`'s `.fullInterleaving` branch
are keyed by `LearningItemType` (not by individual item id) before
changing the test — the deficit-round-robin weighting only works if all
items of the same type share one weight.

- [ ] **Step 6: Commit**

```bash
git add LearningEngine/Sources/LearningEngine/Scheduling LearningEngine/Tests/LearningEngineTests/DailySessionBuilderTests.swift
git commit -m "Add interleaving daily session builder"
```

---

### Task 10: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the entire test suite**

Run: `cd LearningEngine && swift test`
Expected: PASS — all tests across `PackageSmokeTests`, `FSRSWeightsTests`,
`FSRSSchedulerTests`, `ContentModelTests`, `FSRSStateStoreTests`,
`SampleContentTests`, `ComprehensibleInputCalculatorTests`,
`DailySessionBuilderTests` (22 tests total).

- [ ] **Step 2: Confirm no UIKit/SwiftUI/network imports leaked in**

Run: `grep -rn "import UIKit\|import SwiftUI\|import Combine\|URLSession" LearningEngine/Sources`
Expected: no output.

- [ ] **Step 3: Commit if anything changed**

```bash
git add -A
git commit -m "Verify LearningEngine test suite passes end to end" --allow-empty
```

## Future slices

Tracked in the spec's "Future slices" section — not part of this plan:
LLM-based content generation, SwiftUI app shell, on-device LLM tutoring,
speech/pronunciation pipeline, subscriptions/monetization.
