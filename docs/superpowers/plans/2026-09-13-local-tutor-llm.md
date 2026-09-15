# On-Device Tutor (Local LLM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-session, on-device tutoring assistant (a small local LLM run via MLX Swift) that a learner can ask, from a revealed card in the Today session, to explain a word differently, give another example, or answer a free-text question — fully offline, no per-request network call.

**Architecture:** A new `TutorEngine` Swift package (sibling to `LearningEngine`, no dependency between them) holds the pure request/prompt types and the `TutorEngine` protocol, plus an MLX-Swift-backed `MLXTutorEngine` actor that loads a bundled model once and generates responses. The App target wires a `TutorViewModel` + `TutorSheetView` into `TodayView`'s revealed-answer state. The ~2GB model weight file is fetched by a build-time script (not committed to git) into a bundled-but-gitignored App resource directory.

**Tech Stack:** Swift 5.10+, Swift Package Manager, MLX Swift (via the `mlx-swift-examples` package's `MLXLLM`/`MLXLMCommon` products), SwiftUI, Python 3 + `huggingface_hub` (build-time model fetch only, not a runtime dependency).

**Spec:** `docs/superpowers/specs/2026-09-13-local-tutor-llm-design.md`

## Global Constraints

- No standalone chat tab in this slice — a separate future slice reuses `TutorEngine` for that.
- No speech/pronunciation practice in this slice — a different, already-planned future slice.
- No streaming token-by-token UI in v1 — show a loading state, then the complete response.
- No conversation memory across asks — each ask is independent; no history is persisted or fed back into later prompts.
- No changes to `LearningEngine`'s FSRS scheduling, review logging, or SwiftData schema — tutoring is not a review event and is not recorded as one.
- No automated CI verification of `MLXTutorEngine`'s actual generation quality or of MLX inference succeeding on a real device — this is a known, accepted gap for this slice (this dev machine is Windows and can't run MLX/Xcode at all; whether GitHub Actions' macOS Simulator runners can execute Metal-backed MLX inference reliably is unconfirmed). Tasks touching `MLXTutorEngine` are verified by successful compilation and by the rest of the test suite staying green, not by a new automated generation test.
- The model ships inside the installed app (not downloaded at runtime by end users) — but the ~1.5-2GB weight file itself is never committed to git (GitHub's 100MB per-file limit, and Git LFS's bandwidth-quota risk on a public repo, both rule it out). A build-time script fetches it into a git-ignored App resource directory instead, before every build (local or CI).
- Inference runtime: MLX Swift via the `mlx-swift-examples` package's `MLXLLM` and `MLXLMCommon` products. Model: `mlx-community/Llama-3.2-3B-Instruct-4bit`, pinned to an exact revision (not a moving branch).
- This choice (over Apple's Foundation Models framework) is deliberate: Foundation Models would restrict the feature to Apple Intelligence-capable hardware and iOS 26+, while broad device compatibility is a stated priority and the app's baseline target is iOS 17.

---

### Task 1: TutorEngine package — request types, protocol, prompt builder

**Files:**
- Create: `TutorEngine/Package.swift`
- Create: `TutorEngine/Sources/TutorEngine/TutorRequest.swift`
- Create: `TutorEngine/Sources/TutorEngine/PromptBuilder.swift`
- Create: `TutorEngine/Tests/TutorEngineTests/PromptBuilderTests.swift`

**Interfaces:**
- Produces: `QuickAction` (enum), `TutorAsk` (enum), `TutorRequest` (struct), `TutorEngine` (protocol: `func respond(to request: TutorRequest) async throws -> String`), `PromptBuilder.build(for: TutorRequest) -> String`

This is a brand-new Swift package, structured exactly like the existing `LearningEngine/` package at the repo root (sibling directory, same `swift-tools-version`, testable via `swift test` with no Xcode needed).

- [ ] **Step 1: Create the package manifest**

`TutorEngine/Package.swift`:

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TutorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TutorEngine", targets: ["TutorEngine"])
    ],
    targets: [
        .target(name: "TutorEngine"),
        .testTarget(
            name: "TutorEngineTests",
            dependencies: ["TutorEngine"]
        )
    ]
)
```

- [ ] **Step 2: Write the request types and protocol**

`TutorEngine/Sources/TutorEngine/TutorRequest.swift`:

```swift
import Foundation

/// A fixed, no-typing-required thing the learner can ask about the
/// current card.
public enum QuickAction: Equatable {
    case simplerExplanation
    case anotherExample
    case compareToSimilarWords
}

/// Either a quick action or a free-text question the learner typed.
public enum TutorAsk: Equatable {
    case quickAction(QuickAction)
    case freeText(String)
}

/// Everything needed to answer one tutor ask: the current card's
/// content plus what the learner is asking for. No conversation
/// history — each request is independent.
public struct TutorRequest: Equatable {
    public let headword: String
    public let definition: String
    public let exampleSentences: [String]
    public let translationTR: String
    public let ask: TutorAsk

    public init(
        headword: String,
        definition: String,
        exampleSentences: [String],
        translationTR: String,
        ask: TutorAsk
    ) {
        self.headword = headword
        self.definition = definition
        self.exampleSentences = exampleSentences
        self.translationTR = translationTR
        self.ask = ask
    }
}

/// Something that can answer a `TutorRequest`. `MLXTutorEngine` (Task 2)
/// is the real, on-device implementation; test code defines its own
/// fake conforming type rather than sharing one from this package.
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
}
```

- [ ] **Step 3: Write the failing prompt-builder tests**

`TutorEngine/Tests/TutorEngineTests/PromptBuilderTests.swift`:

```swift
import XCTest
@testable import TutorEngine

final class PromptBuilderTests: XCTestCase {
    private func makeRequest(ask: TutorAsk) -> TutorRequest {
        TutorRequest(
            headword: "economy",
            definition: "the system of production, trade, and management of money in a country or region",
            exampleSentences: ["The country's economy grew by three percent last year."],
            translationTR: "ekonomi",
            ask: ask
        )
    }

    func test_build_includesCardContextForEveryAsk() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.simplerExplanation)))

        XCTAssertTrue(prompt.contains("economy"))
        XCTAssertTrue(prompt.contains("the system of production, trade, and management of money in a country or region"))
        XCTAssertTrue(prompt.contains("The country's economy grew by three percent last year."))
        XCTAssertTrue(prompt.contains("ekonomi"))
    }

    func test_build_simplerExplanation_asksForSimplerWording() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.simplerExplanation)))
        XCTAssertTrue(prompt.contains("simpler"))
    }

    func test_build_anotherExample_asksForNewExampleSentence() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.anotherExample)))
        XCTAssertTrue(prompt.contains("new") && prompt.contains("example sentence"))
    }

    func test_build_compareToSimilarWords_asksForComparison() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.compareToSimilarWords)))
        XCTAssertTrue(prompt.contains("differs") || prompt.contains("different"))
    }

    func test_build_freeText_includesTheLearnersExactQuestion() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .freeText("Can I use this in a sentence about my own salary?")))
        XCTAssertTrue(prompt.contains("Can I use this in a sentence about my own salary?"))
    }
}
```

- [ ] **Step 4: Confirm the tests would fail**

This dev machine has no Swift toolchain installed at all (not just an
Apple/SwiftData limitation — plain `swift test` cannot run here
either), so there is no local RED run to execute. Confirm by reading:
`PromptBuilder` doesn't exist yet at this point, so the test file
above cannot compile — that's the expected RED state. The real,
binding verification of both RED-would-happen and GREEN-does-happen is
the single CI run in Step 6, after Step 5's implementation exists too.

- [ ] **Step 5: Implement PromptBuilder**

`TutorEngine/Sources/TutorEngine/PromptBuilder.swift`:

```swift
import Foundation

/// Turns a `TutorRequest` into the actual text prompt sent to the
/// model. Pure and deterministic — all prompt-wording iteration
/// happens here, with no model-loading code involved.
public enum PromptBuilder {
    public static func build(for request: TutorRequest) -> String {
        var prompt = """
        You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam.
        The learner is currently studying this word:

        Word: \(request.headword)
        Definition: \(request.definition)
        Example sentences: \(request.exampleSentences.joined(separator: " / "))
        Turkish translation: \(request.translationTR)


        """

        switch request.ask {
        case .quickAction(.simplerExplanation):
            prompt += "Explain the word \"\(request.headword)\" in simpler, plainer English than the definition above. Keep it to 2-3 short sentences."
        case .quickAction(.anotherExample):
            prompt += "Write one new example sentence using \"\(request.headword)\" that is different from the ones above."
        case .quickAction(.compareToSimilarWords):
            prompt += "Briefly explain how \"\(request.headword)\" differs in meaning or usage from one or two words learners commonly confuse it with. Keep it to 2-3 short sentences."
        case .freeText(let question):
            prompt += "The learner asks: \"\(question)\". Answer clearly and briefly, staying focused on the word \"\(request.headword)\" and its usage."
        }

        return prompt
    }
}
```

- [ ] **Step 6: Wire this package into CI**

`.github/workflows/swift-tests.yml` currently only runs `swift test`
inside `LearningEngine/`. Add a step that also runs it inside
`TutorEngine/` (its own `working-directory` override, since the job's
`defaults.run.working-directory` is `LearningEngine`):

```yaml
      - name: swift test (TutorEngine)
        working-directory: TutorEngine
        run: swift test --parallel
```

Add this step after the existing `swift test` step, so the file's
`steps:` list ends with both packages' tests running.

- [ ] **Step 7: Commit and verify via CI**

```bash
git add TutorEngine/ .github/workflows/swift-tests.yml
git commit -m "Add TutorEngine package: request types, protocol, prompt builder"
```

Run: `bash scripts/ci-test.sh`
Expected: PASS — the `Swift Tests` GitHub Actions run must show both
the existing `LearningEngine` tests and all 5 new `PromptBuilderTests`
passing. This is the actual, binding confirmation that Step 3's tests
compile and pass — there is no earlier local run to trust instead.

---

### Task 2: MLX Swift dependency + MLXTutorEngine

**Files:**
- Modify: `TutorEngine/Package.swift`
- Create: `TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift`

**Interfaces:**
- Consumes: `TutorRequest`, `TutorEngine` protocol, `PromptBuilder.build(for:)` (Task 1)
- Produces: `MLXTutorEngine` (actor, conforms to `TutorEngine`), `public init(modelDirectory: URL) async throws`

**No TDD for this task** — per this plan's Global Constraints, `MLXTutorEngine`'s real generation is not automatically tested (this dev machine can't run MLX at all, and CI's ability to run Metal-backed MLX inference is unconfirmed). This task's pass criterion is: it compiles, and Task 1's existing tests still pass with no regressions.

**A note on the exact API below:** the code uses the `mlx-swift-examples` package's `LLMModelFactory`/`ModelConfiguration`/`ChatSession` types as they exist as of this plan's writing. This external package's API may have moved by the time you implement this — if `swift build` reports a compile error against these exact names, read the actual installed package's README/DocC comments (Xcode/SPM will have resolved and fetched its source locally) and adapt the loading/generation calls to whatever the current API requires. The one invariant to preserve: load the model from a local directory (`modelDirectory`) with **no network access at runtime**, and expose generation only through `MLXTutorEngine.respond(to:)` conforming to `TutorEngine`. This is the same "adapt to the real error, don't guess speculatively" approach this project has already used successfully for other unfamiliar-API integration points (e.g. the `Bundle.module` resource-path fix in the content-pipeline slice).

- [ ] **Step 1: Add the MLX Swift dependency**

Before editing, check https://github.com/ml-explore/mlx-swift-examples/releases (or `tags`) for the latest stable release tag, and use that exact version below instead of guessing — pin an exact version, don't track a moving branch.

`TutorEngine/Package.swift` (replace the whole file):

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TutorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TutorEngine", targets: ["TutorEngine"])
    ],
    dependencies: [
        // Pin to the latest stable release tag at implementation time —
        // check https://github.com/ml-explore/mlx-swift-examples/releases
        // and replace "2.0.0" below with the real current version.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "TutorEngine",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ]
        ),
        .testTarget(
            name: "TutorEngineTests",
            dependencies: ["TutorEngine"]
        )
    ]
)
```

- [ ] **Step 2: Implement MLXTutorEngine**

`TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift`:

```swift
import Foundation
import MLXLLM
import MLXLMCommon

/// Loads the bundled on-device model once and serves tutor requests
/// through it. An actor because MLX generation is not safe to call
/// concurrently against the same loaded model state — asks are
/// naturally serialized, one at a time.
public actor MLXTutorEngine: TutorEngine {
    private let modelContainer: ModelContainer

    /// - Parameter modelDirectory: a local directory containing the
    ///   already-downloaded model weights + tokenizer files (see
    ///   `scripts/fetch-tutor-model.sh`). Never triggers a network
    ///   download itself.
    public init(modelDirectory: URL) async throws {
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfiguration(directory: modelDirectory)
        )
    }

    public func respond(to request: TutorRequest) async throws -> String {
        let prompt = PromptBuilder.build(for: request)
        let session = ChatSession(modelContainer)
        return try await session.respond(to: prompt)
    }
}
```

- [ ] **Step 3: Verify it compiles and nothing regressed**

Run: `bash scripts/ci-test.sh`
Expected: PASS. This pushes the branch and watches the `Swift Tests` GitHub Actions run — the run must add and resolve the new `mlx-swift-examples` dependency, compile `MLXTutorEngine`, and keep all of Task 1's `PromptBuilderTests` green (Task 1 already wired `TutorEngine/`'s `swift test` into `.github/workflows/swift-tests.yml`, so this run covers both packages).

If the CI run fails specifically on the `mlx-swift-examples` API surface (unknown type/member), that's the expected uncertainty called out above — read the real error, check the resolved package's actual source/docs, and adjust `MLXTutorEngine` accordingly, then re-run this step. Do not guess repeatedly without reading the actual compiler error each time.

- [ ] **Step 4: Commit**

```bash
git add TutorEngine/Package.swift TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift .github/workflows/swift-tests.yml
git commit -m "Add MLX Swift dependency and MLXTutorEngine"
```

---

### Task 3: Model fetch script + CI wiring

**Files:**
- Create: `scripts/fetch-tutor-model.sh`
- Modify: `.gitignore`
- Modify: `.github/workflows/app-build.yml`

**Interfaces:**
- Produces: a script that populates `App/Sources/EnglishApp/Resources/TutorModel/` with the pinned model's files; a CI cache+fetch step in `app-build.yml`

This task has no Swift code and no TDD cycle — it's build tooling, verified by actually running it.

- [ ] **Step 1: Look up the pinned model revision**

Visit https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit , find the commit hash of the revision you want to pin (the latest commit on its default branch is fine), and use that exact hash in the script below in place of `<PIN_EXACT_COMMIT_SHA_HERE>`.

- [ ] **Step 2: Write the fetch script**

`scripts/fetch-tutor-model.sh`:

```bash
#!/usr/bin/env bash
# Fetches the pinned on-device tutor model (MLX-format, 4-bit
# quantized Llama 3.2 3B Instruct) from Hugging Face into the App's
# bundled resources directory, if not already present at that exact
# revision. Run before building the App target — see
# .github/workflows/app-build.yml.
#
# The destination directory is git-ignored: this ~1.5-2GB weight file
# is too large for a normal git commit (GitHub's 100MB per-file limit)
# and isn't worth Git LFS's bandwidth-quota risk on a public repo.
#
# Usage: scripts/fetch-tutor-model.sh (run from the repo root)
set -euo pipefail

MODEL_REPO="mlx-community/Llama-3.2-3B-Instruct-4bit"
MODEL_REVISION="<PIN_EXACT_COMMIT_SHA_HERE>"
DEST_DIR="App/Sources/EnglishApp/Resources/TutorModel"

if [ -f "$DEST_DIR/.fetched-revision" ] && [ "$(cat "$DEST_DIR/.fetched-revision")" = "$MODEL_REVISION" ]; then
  echo "Tutor model already present at revision $MODEL_REVISION — skipping download."
  exit 0
fi

python3 -m pip install --quiet --upgrade huggingface_hub

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

huggingface-cli download "$MODEL_REPO" \
  --revision "$MODEL_REVISION" \
  --local-dir "$DEST_DIR"

echo "$MODEL_REVISION" > "$DEST_DIR/.fetched-revision"
echo "Fetched tutor model: $(du -sh "$DEST_DIR" | cut -f1)"
```

If `huggingface-cli` isn't found on PATH after the `pip install` (this can happen depending on how `pip` is configured, especially in Git Bash on Windows), use `python3 -m huggingface_hub.commands.huggingface_cli download ...` with the same arguments instead — verify by running the script and confirming files actually land under `$DEST_DIR`.

Make it executable:

```bash
chmod +x scripts/fetch-tutor-model.sh
```

- [ ] **Step 3: Run the script locally to verify it works**

Run: `bash scripts/fetch-tutor-model.sh`
Expected: downloads succeed, `App/Sources/EnglishApp/Resources/TutorModel/` contains the model's weight/config/tokenizer files, and a second run of the same command prints "already present ... skipping download" instead of re-downloading. This can be run directly on this Windows dev machine (it's a plain HTTPS download, no Xcode/MLX needed) — this is the actual verification for this step, not a placeholder to skip.

- [ ] **Step 4: Ignore the fetched directory**

Add to `.gitignore` (repo root):

```
App/Sources/EnglishApp/Resources/TutorModel/
```

- [ ] **Step 5: Wire the fetch into CI, with caching**

`.github/workflows/app-build.yml` — add a cache step and a fetch step right after checkout, before `Select Xcode` (so the resource files exist before Xcode reads them). The `working-directory: ${{ github.workspace }}` override is needed because this job's default working directory is `App`, but the script's paths are repo-root-relative (the same pattern already used for the "Verify content assembly is up to date" step in `.github/workflows/swift-tests.yml`):

```yaml
      - uses: actions/checkout@v4
      - name: Cache tutor model
        uses: actions/cache@v4
        with:
          path: App/Sources/EnglishApp/Resources/TutorModel
          key: tutor-model-${{ hashFiles('scripts/fetch-tutor-model.sh') }}
      - name: Fetch tutor model
        working-directory: ${{ github.workspace }}
        run: bash scripts/fetch-tutor-model.sh
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
```

(Keep the rest of the existing file — `Install XcodeGen`, `Generate Xcode project`, `Build (unsigned)`, `Run unit tests` — unchanged below this.)

The cache key is tied to the fetch script's own content (which contains `MODEL_REVISION`), so bumping the pinned revision automatically invalidates the cache and re-downloads — no separate version string to keep in sync.

- [ ] **Step 6: Commit**

```bash
git add scripts/fetch-tutor-model.sh .gitignore .github/workflows/app-build.yml
git commit -m "Add tutor model fetch script and wire it into App Build CI"
```

Do not commit the fetched `App/Sources/EnglishApp/Resources/TutorModel/` directory itself — confirm `git status` shows it as ignored, not staged.

---

### Task 4: App project wiring — add TutorEngine package dependency

**Files:**
- Modify: `App/project.yml`

**Interfaces:**
- Consumes: the `TutorEngine` package existing at `TutorEngine/` (Task 1)
- Produces: `EnglishApp` and `EnglishAppTests` targets can `import TutorEngine`

- [ ] **Step 1: Add the package and both target dependencies**

`App/project.yml` — add a `TutorEngine` entry under `packages:` (alongside the existing `LearningEngine` one), and a `- package: TutorEngine` line under each target's `dependencies:`:

```yaml
name: EnglishApp
options:
  bundleIdPrefix: com.niinova22.englishapp
  deploymentTarget:
    iOS: "17.0"
packages:
  LearningEngine:
    path: ../LearningEngine
  TutorEngine:
    path: ../TutorEngine
targets:
  EnglishApp:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Sources/EnglishApp
    resources:
      - path: Sources/EnglishApp/Resources
    dependencies:
      - package: LearningEngine
      - package: TutorEngine
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.niinova22.englishapp
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_CFBundleDisplayName: "English App"
        TARGETED_DEVICE_FAMILY: "1"
        CODE_SIGN_STYLE: Automatic
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.10"
  EnglishAppTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Tests/EnglishAppTests
    dependencies:
      - target: EnglishApp
      - package: LearningEngine
      - package: TutorEngine
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "5.10"
```

Note: `resources: - path: Sources/EnglishApp/Resources` already covers the whole directory recursively (this is the same mechanism that already bundles `YDSAcademicVocabulary1.json` from a subpath of that same directory) — once Task 3's fetch script populates `Resources/TutorModel/`, no separate `resources:` entry is needed for it.

- [ ] **Step 2: Verify via CI**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS — `xcodegen generate` picks up the new package dependency, and both the app build and `EnglishAppTests` compile with `TutorEngine` importable (nothing needs to actually reference `TutorEngine` yet, so this step just proves the wiring resolves).

- [ ] **Step 3: Commit**

```bash
git add App/project.yml
git commit -m "Add TutorEngine package dependency to the App project"
```

---

### Task 5: TutorViewModel

**Files:**
- Create: `App/Sources/EnglishApp/Tutor/TutorViewModel.swift`
- Create: `App/Tests/EnglishAppTests/TutorViewModelTests.swift`

**Interfaces:**
- Consumes: `TutorEngine`, `TutorRequest`, `QuickAction`, `TutorAsk` (Task 1); `TutorEngine` importable in the App target (Task 4)
- Produces: `TutorViewModel` (class, `@Observable`), `TutorViewModel.TutorContext` (struct), `TutorViewModel.State` (enum: `.idle`, `.loading`, `.response(String)`, `.failure(String)`)

- [ ] **Step 1: Write the failing tests**

`App/Tests/EnglishAppTests/TutorViewModelTests.swift`:

```swift
import XCTest
import TutorEngine
@testable import EnglishApp

private final class FakeTutorEngine: TutorEngine {
    var stubbedResponse = "stub response"
    var stubbedError: Error?
    private(set) var lastRequest: TutorRequest?

    func respond(to request: TutorRequest) async throws -> String {
        lastRequest = request
        if let stubbedError { throw stubbedError }
        return stubbedResponse
    }
}

private struct StubError: Error {}

final class TutorViewModelTests: XCTestCase {
    private let context = TutorViewModel.TutorContext(
        headword: "economy",
        definition: "the system of production, trade, and management of money in a country or region",
        exampleSentences: ["The country's economy grew by three percent last year."],
        translationTR: "ekonomi"
    )

    func test_initialState_isIdle() {
        let viewModel = TutorViewModel(engine: FakeTutorEngine(), context: context)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_askQuickAction_onSuccess_setsResponseState() async {
        let engine = FakeTutorEngine()
        engine.stubbedResponse = "Here's a simpler explanation."
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(.simplerExplanation)

        XCTAssertEqual(viewModel.state, .response("Here's a simpler explanation."))
        XCTAssertEqual(engine.lastRequest?.ask, .quickAction(.simplerExplanation))
        XCTAssertEqual(engine.lastRequest?.headword, "economy")
    }

    func test_askQuickAction_onFailure_setsFailureState() async {
        let engine = FakeTutorEngine()
        engine.stubbedError = StubError()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(.anotherExample)

        guard case .failure = viewModel.state else {
            return XCTFail("expected .failure state, got \(viewModel.state)")
        }
    }

    func test_askFreeText_trimsAndSendsTheQuestion() async {
        let engine = FakeTutorEngine()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(freeText: "  Can you use it in a sentence about salary?  ")

        XCTAssertEqual(engine.lastRequest?.ask, .freeText("Can you use it in a sentence about salary?"))
    }

    func test_askFreeText_ignoresBlankQuestion() async {
        let engine = FakeTutorEngine()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(freeText: "   ")

        XCTAssertNil(engine.lastRequest)
        XCTAssertEqual(viewModel.state, .idle)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/ci-app-build.sh`
Expected: FAIL — `TutorViewModel` doesn't exist yet (compile error). (This machine can't run `xcodebuild test` locally, so this "red" step is confirmed via CI, same as every other App-target test in this project.)

- [ ] **Step 3: Implement TutorViewModel**

`App/Sources/EnglishApp/Tutor/TutorViewModel.swift`:

```swift
import Foundation
import TutorEngine

/// Thrown when a tutor request takes longer than `TutorViewModel`'s
/// timeout to respond. The spec requires generation timeouts to
/// surface as an inline, retryable error rather than an infinite
/// spinner — this is what makes that possible even though
/// `TutorEngine` itself has no timeout of its own.
struct TutorTimeoutError: LocalizedError {
    var errorDescription: String? { "The tutor took too long to respond. Please try again." }
}

@Observable
final class TutorViewModel {
    enum State: Equatable {
        case idle
        case loading
        case response(String)
        case failure(String)
    }

    struct TutorContext {
        let headword: String
        let definition: String
        let exampleSentences: [String]
        let translationTR: String
    }

    private(set) var state: State = .idle
    private let engine: any TutorEngine
    private let context: TutorContext
    private let timeoutNanoseconds: UInt64

    init(engine: any TutorEngine, context: TutorContext, timeoutSeconds: UInt64 = 30) {
        self.engine = engine
        self.context = context
        self.timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }

    func ask(_ quickAction: QuickAction) async {
        await send(.quickAction(quickAction))
    }

    func ask(freeText question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await send(.freeText(trimmed))
    }

    private func send(_ ask: TutorAsk) async {
        state = .loading
        let request = TutorRequest(
            headword: context.headword,
            definition: context.definition,
            exampleSentences: context.exampleSentences,
            translationTR: context.translationTR,
            ask: ask
        )
        do {
            let response = try await respondWithTimeout(to: request)
            state = .response(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    private func respondWithTimeout(to request: TutorRequest) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await self.engine.respond(to: request) }
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
}
```

The `timeoutSeconds` initializer parameter (defaulting to 30) exists so a future test could inject a very short timeout to test that path deterministically without a real 30-second wait — this plan doesn't add such a test itself (it would need an injectable-delay `FakeTutorEngine`, more machinery than this v1 needs), but the seam is there rather than a hardcoded magic number. The existing tests in Step 1 are unaffected: `FakeTutorEngine` resolves synchronously-fast, always well under the 30-second default.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS — all 5 new `TutorViewModelTests` green, plus every pre-existing App test still passing.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/Tutor/TutorViewModel.swift App/Tests/EnglishAppTests/TutorViewModelTests.swift
git commit -m "Add TutorViewModel"
```

---

### Task 6: TutorSheetView, TodayView integration, and app-level wiring

**Files:**
- Create: `App/Sources/EnglishApp/Tutor/TutorSheetView.swift`
- Modify: `App/Sources/EnglishApp/AppState.swift`
- Modify: `App/Sources/EnglishApp/RootTabView.swift`
- Modify: `App/Sources/EnglishApp/Today/TodayView.swift`

**Interfaces:**
- Consumes: `TutorViewModel`, `TutorViewModel.TutorContext`, `TutorViewModel.State` (Task 5); `MLXTutorEngine`, `TutorEngine` protocol (Task 2); the fetched model at `App/Sources/EnglishApp/Resources/TutorModel/` (Task 3, for real end-to-end verification)

This is the final task: it wires a real `MLXTutorEngine` into the app once at launch, and adds the "Ask Tutor" entry point to `TodayView`. Per this plan's Global Constraints, the feature must be **completely hidden** (not shown-and-erroring) whenever the model can't be loaded — this is the mechanism that keeps a resource-bundling or MLX-loading problem from ever blocking the review session itself.

**A known uncertain point:** `Bundle.main.url(forResource: "TutorModel", withExtension: nil)` (Step 1 below) assumes XcodeGen bundles the `Resources/TutorModel/` directory as a locatable folder resource. The content-pipeline slice hit a similar surprise with a single-file resource (`.copy()` flattening a file to bundle root instead of preserving a subdirectory, requiring a `subdirectory:` argument to be removed) — a multi-file directory like `TutorModel/` could have analogous quirks depending on how XcodeGen's `resources:` handles nested directories. If manual/device testing later shows `Bundle.main.url(forResource:withExtension:)` never finds it even though the fetch script populated the directory correctly, that's this exact class of issue — inspect the actual built `.app` bundle's contents (e.g. via Xcode's build products folder) to see how the directory landed, and adjust the lookup (or the `project.yml` resource declaration) to match reality, the same "adapt to the real environment" approach already used successfully elsewhere in this project. Since the failure mode is "feature silently stays unavailable" rather than a crash, this is not a blocker for finishing this task now — only something to watch for once real-device testing happens (see Future work).

- [ ] **Step 1: Add a lazily-loaded tutor engine to AppState**

`App/Sources/EnglishApp/AppState.swift` (replace the whole file):

```swift
import Foundation
import TutorEngine

@Observable
final class AppState {
    private(set) var dataGeneration = 0
    private(set) var tutorEngine: (any TutorEngine)?

    func bumpDataGeneration() {
        dataGeneration += 1
    }

    /// Attempts to load the on-device tutor model, if not already
    /// loaded. Leaves `tutorEngine` nil on any failure (missing
    /// resource, unsupported device, load error) — callers must treat
    /// nil as "the feature isn't available right now" and hide its UI
    /// entirely, never show it and then fail per-request.
    func loadTutorEngineIfNeeded() async {
        guard tutorEngine == nil else { return }
        guard let modelURL = Bundle.main.url(forResource: "TutorModel", withExtension: nil) else {
            return
        }
        do {
            tutorEngine = try await MLXTutorEngine(modelDirectory: modelURL)
        } catch {
            tutorEngine = nil
        }
    }
}
```

- [ ] **Step 2: Trigger the load once at launch**

`App/Sources/EnglishApp/RootTabView.swift` (replace the whole file):

```swift
import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            await appState.loadTutorEngineIfNeeded()
        }
    }
}
```

- [ ] **Step 3: Write TutorSheetView**

`App/Sources/EnglishApp/Tutor/TutorSheetView.swift`:

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
            VStack(alignment: .leading, spacing: 16) {
                quickActionButtons
                freeTextField
                responseArea
                Spacer()
            }
            .padding()
            .navigationTitle("Ask Tutor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Explain more simply") { Task { await viewModel.ask(.simplerExplanation) } }
            Button("Give another example") { Task { await viewModel.ask(.anotherExample) } }
            Button("How is this different from similar words?") { Task { await viewModel.ask(.compareToSimilarWords) } }
        }
        .buttonStyle(.bordered)
    }

    private var freeTextField: some View {
        HStack {
            TextField("Ask anything about this word...", text: $freeTextQuestion)
                .textFieldStyle(.roundedBorder)
            Button("Ask") {
                let question = freeTextQuestion
                freeTextQuestion = ""
                Task { await viewModel.ask(freeText: question) }
            }
            .disabled(freeTextQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var responseArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
        case .response(let text):
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .failure(let message):
            Text("Couldn't get a response: \(message)")
                .foregroundStyle(.red)
        }
    }
}
```

The quick-action buttons and free-text field stay visible and tappable regardless of `viewModel.state` — after a `.failure`, tapping the same (or any other) action tries again, which is this v1's retry mechanism; no separate retry button is needed.

- [ ] **Step 4: Wire "Ask Tutor" into TodayView**

`App/Sources/EnglishApp/Today/TodayView.swift` — add a `showTutorSheet` state property alongside the existing `@State` properties near the top of the struct:

```swift
    @State private var showTutorSheet = false
```

Then modify the `itemCard(_:)` method's revealed-answer branch (the `if isAnswerRevealed, let content = item.content` block) to add the "Ask Tutor" button and sheet after the existing rating buttons `HStack`:

```swift
    private func itemCard(_ item: LearningItem) -> some View {
        VStack(spacing: 20) {
            Text(headword(for: item))
                .font(.largeTitle.bold())

            if isAnswerRevealed, let content = item.content {
                VStack(alignment: .leading, spacing: 12) {
                    Text(content.definition)
                    ForEach(content.exampleSentences, id: \.self) { sentence in
                        Text("“\(sentence)”").italic()
                    }
                    Text(content.translationTR)
                        .foregroundStyle(.secondary)
                }
                .padding()

                HStack {
                    ratingButton("Again", .again, color: .red)
                    ratingButton("Hard", .hard, color: .orange)
                    ratingButton("Good", .good, color: .green)
                    ratingButton("Easy", .easy, color: .blue)
                }

                if let engine = appState.tutorEngine {
                    Button("Ask Tutor") { showTutorSheet = true }
                        .buttonStyle(.bordered)
                        .sheet(isPresented: $showTutorSheet) {
                            TutorSheetView(
                                engine: engine,
                                context: TutorViewModel.TutorContext(
                                    headword: content.headword,
                                    definition: content.definition,
                                    exampleSentences: content.exampleSentences,
                                    translationTR: content.translationTR
                                )
                            )
                        }
                }
            } else {
                Button("Show Answer") { isAnswerRevealed = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
```

(`TodayView` already declares `@Environment(AppState.self) private var appState` for `dataGeneration` — reuse it here, no new environment property needed.)

- [ ] **Step 5: Verify via CI**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS — app builds and all App tests (including Task 5's `TutorViewModelTests`) pass. This does not prove the real `MLXTutorEngine` successfully loads the actual bundled model on a real device (see Global Constraints) — it proves the wiring compiles and degrades gracefully when the engine can't be constructed in whatever environment the Simulator test run provides.

If this step reveals that `MLXTutorEngine`'s initializer actually can be exercised in the Simulator CI environment (i.e. it succeeds or fails in an informative way rather than the whole run erroring unexpectedly), note that finding in your report — it's useful information for later slices, but not a requirement to act on now.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/EnglishApp/Tutor/TutorSheetView.swift App/Sources/EnglishApp/AppState.swift App/Sources/EnglishApp/RootTabView.swift App/Sources/EnglishApp/Today/TodayView.swift
git commit -m "Wire on-device tutor into TodayView"
```

## Future work this unblocks

- A standalone general-purpose "Tutor" chat tab, reusing `TutorEngine`/`PromptBuilder` with a conversational, multi-turn request shape.
- Streaming responses instead of wait-then-show.
- Manual on-device verification of real generation quality (this plan builds the plumbing; a human trying it on a real device, once TestFlight distribution is set up, is what confirms the model choice and prompts actually work well).
- Swapping the pinned model for a different size/quality if real-device testing shows it's mis-sized.
