# Why `swift-transformers` is mirrored to a fork

The on-device tutor (`TutorEngine`) depends on `mlx-swift-examples`, which in
turn depends on `swift-transformers`. Under Xcode's native SwiftPM
integration (not plain `swift build`/`swift test`), `swift-transformers`'s
`Hub` module fails to link: it uses `OrderedCollections.OrderedDictionary`
(re-exported transitively from `swift-jinja`) without declaring an explicit
dependency on `swift-collections` in its own `Package.swift`. Xcode builds
each package product as an isolated dynamic framework, so `Hub`'s link step
fails with an undefined `OrderedCollections` symbol. This is already fixed
upstream (`huggingface/swift-transformers` PR #299, released in 1.1.5), but
`mlx-swift-examples` 2.29.1 constrains `swift-transformers` to
`.upToNextMinor(from: "1.0.0")`, which excludes the fix.

Until a `mlx-swift-examples` release accepts `swift-transformers` >= 1.1.5,
this repo resolves `swift-transformers` to
`niinova22-blip/swift-transformers` tag `1.0.1` — a fork of the affected
`1.0.0` tag carrying only that one cherry-picked, already-upstream-merged
commit — via SwiftPM's dependency-mirror mechanism.

## Where the mirror is configured

- **CI** (`.github/workflows/swift-tests.yml`, `.github/workflows/app-build.yml`):
  both jobs set `SWIFTPM_MIRROR_CONFIG` to point at `ci/swiftpm-mirrors.json`
  at the repo root. This is honored by both plain `swift test` and Xcode's
  `xcodebuild`, confirmed by real CI runs (see the "Swift Tests" and
  "App Build" GitHub Actions workflow histories for this repo).
- **Local `TutorEngine` package builds**: `TutorEngine/.swiftpm/configuration/mirrors.json`
  carries the same mirror entry. This is SwiftPM's own local-config fallback
  path — it's consulted automatically whenever `SWIFTPM_MIRROR_CONFIG` is
  *not* set, so running `swift build`/`swift test` directly inside
  `TutorEngine/` picks it up with no extra setup.
- **Local App target builds in Xcode**: **not verified.** It's unconfirmed
  whether Xcode/XcodeGen, when building the generated `EnglishApp.xcodeproj`,
  consults `TutorEngine/.swiftpm/configuration/mirrors.json` (the dependent
  package's own local mirror config) for its transitive resolution, or
  whether it would need `SWIFTPM_MIRROR_CONFIG` set in the local shell/Xcode
  environment before running `xcodegen generate` / opening the project. If
  you hit the `OrderedCollections`/`Hub` link error while building the App
  target locally in Xcode, set `SWIFTPM_MIRROR_CONFIG` to an absolute path
  to `ci/swiftpm-mirrors.json` in your shell before generating/opening the
  project, and please update this note with what you find.

## Fetching the model

The tutor model itself is unrelated to this mirror — see
`scripts/fetch-tutor-model.sh`, run before building the App target (CI does
this automatically; see `.github/workflows/app-build.yml`).

## Retiring this mirror

Once `mlx-swift-examples` ships a release that accepts `swift-transformers`
>= 1.1.5, remove:

- `ci/swiftpm-mirrors.json`
- `TutorEngine/.swiftpm/configuration/mirrors.json`
- the `SWIFTPM_MIRROR_CONFIG` env block in both
  `.github/workflows/swift-tests.yml` and `.github/workflows/app-build.yml`
- the fork itself (`niinova22-blip/swift-transformers`)
