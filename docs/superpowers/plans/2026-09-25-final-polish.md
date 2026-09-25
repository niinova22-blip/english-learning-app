# Final Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native iOS look, one interface language (content titles included), AI Premium 1-week trial with real prices and a full sales page, conversion/retention features, and a clean close — without a TestFlight build.

**Architecture:** Bilingual titles travel as optional content fields → SwiftData → `display*` helpers chosen by `AppLanguage`. Store trial data is added to the `PurchaseService` boundary so all decisions stay testable with fakes. Notification and review rules are pure types with thin system adapters.

**Tech Stack:** Swift 5.10, SwiftUI (iOS 17 floor, iOS 26 `glassEffect` behind `#available`), SwiftData, StoreKit 2, UserNotifications, Python content scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-final-polish-design.md`

## Global Constraints

- No local Swift toolchain: verify every task by pushing `release-prep` and reading both CI workflows (Swift Tests, App Build incl. "Check Turkish translations").
- Python: `C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe` only.
- Every new UI string: English key in code + Turkish via `scripts/l10n.py add` (never hand-edit the catalog).
- SwiftData changes: additive optional properties only. Item/lesson/unit IDs never change.
- YDS Turkish tutor prompt stays byte-identical (existing GoalPromptTests).
- Prices: Premium monthly $6.99 / ₺149,99; yearly $39.99 / ₺899,99; YDS $12.99 / ₺349,99; Business/Everyday $9.99 / ₺249,99. Intro offer: 1 week free on both subscriptions.
- All motion respects Reduce Motion. Never amend or force-push. **No Codemagic build at the end.**

## Review Focus

1. English UI user whose active package is YDS (changed phone language) — YDS must stay visible and selectable, not vanish.
2. Trial eligibility unknown/failed to load — paywall must show the plain price, never a trial promise.
3. Daily reminder when today's plan is already complete — no reminder today, tomorrow's still scheduled.
4. Old installed data without localized titles (before reseed) — screens show the base title, never an empty string.
5. Onboarding purchase cancelled on the trial step — learner still lands in the app with the profile saved.

---

### Task 1: Bilingual metadata in LearningEngine

**Files:** Modify `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`, `Import/ContentImporter.swift`, `Models/ContentPackage.swift`, `Models/Unit.swift`, `Models/Lesson.swift`. Create `Models/LocalizedTitles.swift`. Test `LearningEngine/Tests/LearningEngineTests/LocalizedTitlesTests.swift`.

**Produces:** `LocalizedTextDocument { en: String?; tr: String? }` (Decodable); documents gain `nameLocalized`, `summaryLocalized` (package), `themeLocalized` (unit), `titleLocalized` (lesson), all optional. Models gain optional `nameEN/nameTR/summaryEN/summaryTR`, `themeEN/themeTR`, `titleEN/titleTR`. Pure helper `LocalizedTitles.pick(base: String, en: String?, tr: String?, languageCode: String) -> String` (non-empty localized value for "tr"/"en", else base). Model methods `name(for:)`, `summary(for:) -> String?`, `theme(for:)`, `title(for:)` taking a language code.

- [ ] Write tests: pick returns tr/en value; empty or nil falls back to base; importer copies all localized fields; document without them still imports (fields nil).
- [ ] Implement documents, models (`public var nameEN: String? = nil` etc.), importer copy, helper.
- [ ] Push; Swift Tests green. Commit "Add bilingual package/unit/lesson titles to the content model".

### Task 2: Bilingual titles in all three packages

**Files:** Create `content/yds-academic-vocab-1/titles.json`, `content/business-english-1/titles.json`, `content/everyday-english-1/titles.json`, `scripts/list-titles.py`. Modify `scripts/assemble-content.py` (merge + lint + `PACKAGE_VERSION = 10`), `scripts/assemble-package.py` (merge + lint), `content/*/package.json` version +1, regenerated resources + YDS fixture; version assertions in `RealContentSeedingTests`/`ContentImporterTests`.

**titles.json format:** `{"package": {"name": {"en","tr"}, "summary": {"en","tr"}}, "units": {"<unitID>": {"en","tr"}}, "lessons": {"<lessonID>": {"en","tr"}}}`.

- [ ] `list-titles.py <package-id>` prints every package/unit/lesson id with its base title (reads the assembled resource) — used to author the files.
- [ ] Author all three files: natural, short titles; Turkish uses correct characters; English YDS titles translate the Turkish ones; Business/Everyday Turkish titles translate the English ones. Package names: "YDS Hazırlık"/"YDS Prep", "İş İngilizcesi"/"Business English", "Günlük İngilizce"/"Everyday English".
- [ ] Assemblers write `nameLocalized`/`summaryLocalized`/`themeLocalized`/`titleLocalized`; lint fails when any id is missing either language, has an empty value, or titles.json names an unknown id.
- [ ] Regenerate; update version assertions (YDS 10, packages 2); push; both CI green. Commit.

### Task 3: App shows localized titles; YDS hidden on English UI

**Files:** Create `App/Sources/EnglishApp/Access/DisplayText.swift` (`extension ContentPackage { var displayName: String; var displaySummary: String? }`, `Unit.displayTheme`, `Lesson.displayTitle` using `AppLanguage.current`; `AppLanguage.code`). Modify every call site listed below and `PackageOrdering` (+ `visible(_:language:activeID:ownedIDs:)`), `OnboardingViewModel`, `GoalSwitcherViewModel`. Tests in `App/Tests/EnglishAppTests/GoalSwitchingTests.swift`.

Call sites: `PackageOrdering.swift:45,48`, `AppState.swift:41`, `CoursePathViewModel.swift:63,65,68`, `PracticeSessionViewModel.swift:121`, `StudySessionViewModel.swift:80`, `TodayPlanCoordinator.swift:81,128,198,219`, plus `PaywallTarget` package name.

- [ ] Tests: `visible` hides `audience == "tr"` on English unless active or owned; Turkish shows all; onboarding (no profile yet) on English hides YDS; switcher on English with YDS active keeps it.
- [ ] Implement; `PackageOption` uses `displayName/displaySummary`; ordering compares display names.
- [ ] Push; CI green. Commit.

### Task 4: Native iOS visual system and effects

**Files:** Modify `DesignSystem/Theme.swift`, `DesignSystem/Components.swift`, `DesignSystem/PackageOptionRow.swift`, `DesignSystem/PlanTaskRow.swift`; create `DesignSystem/Effects.swift`; replace `Font.serifTitle` with `Font.appTitle` at every call site (keep serif only for the study-card headword via `Font.headword`); summary views get the celebration; `DesignSystemTests`.

- Theme: `paper` = `UIColor.systemGroupedBackground`, `surface` = `secondarySystemGroupedBackground`, `border` = `separator`; `primary` light `0x0F8A80` dark `0x2DD4BF`; `accent` light `0xF26B1D` dark `0xFB923C`; ink/secondaryInk = `label`/`secondaryLabel`.
- `Font.appTitle(_ style)` = `.system(style, design: .default).weight(.bold)`; `Font.number(_ style)` = rounded semibold; `Font.headword` = serif bold title.
- `PaperCard`: no stroke, radius 20, `shadow(color: .black.opacity(0.06), radius: 12, y: 4)` in light mode only.
- Effects.swift: `PressableButtonStyle` (scale 0.97 spring, disabled under Reduce Motion), `PrimaryButtonStyle` capsule using it; `View.appGlass()` (`glassEffect()` on iOS 26, `.ultraThinMaterial` else); `CelebrationView` (SF Symbol sparkles burst, 1.2 s, static under Reduce Motion); counters use `.contentTransition(.numericText())`; streak flame `.symbolEffect(.bounce, value:)`; `sensoryFeedback` on rating, answer result, lesson complete.
- [ ] Tests: `DesignSystemTests` updated for new values (colors resolve in both modes; `Font.appTitle` exists).
- [ ] Implement; grep confirms no `serifTitle` left; push; CI green. Commit.

### Task 5: Prices, intro offers and trial data at the store boundary

**Files:** `App/StoreKit/Products.storekit`; `Store/StoreTypes.swift`; `Store/StoreKitPurchaseService.swift`; `Store/EntitlementStore.swift`; create `Store/PlanPricing.swift`; tests `App/Tests/EnglishAppTests/Store/PlanPricingTests.swift` + existing store fakes.

**Produces:** `StoreProduct` + `price: Decimal`, `trialDays: Int?`, `isTrialEligible: Bool`; `StoreEntitlement` + `trialEndsAt: Date?` (set when the active transaction's `offerType == .introductory` and it auto-renews). `PlanPricing.savingsPercent(monthly: Decimal, yearly: Decimal) -> Int?` (rounded down, nil when ≤ 0), `PlanPricing.perMonth(yearly:) -> Decimal`, `PlanPricing.showsTrial(_ product: StoreProduct) -> Bool` (`trialDays != nil && isTrialEligible`). `EntitlementStore.trialEndsAt: Date?`.

- [ ] storekit prices (USD file), both subscriptions `introductoryOffer` `{"paymentMode":"free","subscriptionPeriod":"P1W","numberOfPeriods":1}`, packages 12.99/9.99/9.99, premium 6.99/39.99.
- [ ] Tests: savings 6.99/39.99 → 52; 149.99/899.99 → 50; equal → nil; showsTrial false when ineligible or no offer; entitlement store keeps latest `trialEndsAt`, clears on inactive.
- [ ] Implement (live service reads `subscription?.introductoryOffer`, `await subscription?.isEligibleForIntroOffer`, `transaction.offerType`, `transaction.subscriptionStatus?.renewalInfo` willAutoRenew); update fakes. Push; CI green. Commit.

### Task 6: AI Premium sales page and package page

**Files:** `Store/PaywallView.swift` (split into `Store/PremiumPaywallContent.swift` + `Store/PackagePaywallContent.swift`), `Store/PaywallViewModel.swift`, `Store/LockedLessonPrompt.swift`/`PaywallTarget` (package stats), catalog. Tests `PaywallViewModelTests` additions.

- Premium: hero ("Your personal coach and tutor, right on your phone" + on-device/offline/private line), four feature sections with SF Symbols (Coach: date-based daily plan, catch-up lessons when behind, final-week review mode, weakest-skill focus, weekly summary + estimated finish, personal note; Word tutor: simpler explanation, another example, compare similar words, ask anything; Question explainer: why my answer is wrong, why other options fail; Free chat in your language), plan cards (yearly first with "Best value · save N%" and "≈ X / month", monthly), trial timeline when `showsTrial`, CTA "Start 1-week free trial" else "Subscribe · price", disclosure "Free for 7 days, then X/year. Cancel anytime." + existing renewal text, links, restore.
- Package: title = display name, counts line "N units · M lessons · K questions" computed from the package, "The first unit is free" note, one-time purchase line.
- [ ] Tests: VM exposes `ctaTitle`, `showsTrialTimeline`, `savingsBadge` for eligible/ineligible fakes; package stats counts from a test package.
- [ ] Implement + Turkish strings; push; CI green. Commit.

### Task 7: Onboarding trial + reminder steps, Today teaser

**Files:** `Onboarding/OnboardingViewModel.swift` (steps `.reminder` after `.dailyDuration`, `.trialOffer` after result/skip; profile persisted before `.trialOffer`; `isOnboardingComplete` after trial step), `Onboarding/OnboardingFlowView.swift`, create `Onboarding/TrialOfferStep.swift`; `Coach/CoachCardView.swift` teaser (`CoachTeaserCard` shows real status badge + finish date, blurred details, dismiss) + `Coach/TeaserPolicy.swift` (`shouldShow(lastDismissed: Date?, now: Date) -> Bool`, 7 days). Tests: `OnboardingViewModelTests`, `TeaserPolicyTests`.

- [ ] Tests: step order goal→date→duration→reminder→levelTestIntro→…→trialOffer→done; skip test goes to trialOffer when eligible else done; profile exists when entering trialOffer; teaser hidden within 7 days of dismiss.
- [ ] Implement; push; CI green. Commit.

### Task 8: Notifications — daily reminder and trial ending

**Files:** create `Notifications/ReminderRules.swift` (pure), `Notifications/ReminderScheduler.swift` (UNUserNotificationCenter adapter behind `NotificationCenterClient` protocol), `Notifications/ReminderSettings.swift` (UserDefaults: enabled, hour, minute); modify `EnglishAppApp`/`RootTabView` (reschedule on launch + on `dataGeneration`), `Profile/ProfileView.swift` (REMINDERS section: toggle + time picker, permission-denied note), `Store/EntitlementStore` hook for trial reminder. Tests `ReminderRulesTests`, `ReminderSchedulerTests` (fake client).

**Rules:** `dailyFireDates(now:, hour:, minute:, todayComplete:, calendar:) -> [Date]` = next 7 occurrences, skipping today when `todayComplete` or the time has passed; `trialReminderDate(trialEndsAt:, now:) -> Date?` = end − 24 h if in the future.

- [ ] Tests for both rules (incl. DST-safe calendar arithmetic) and scheduler replacing only its own identifiers (`daily-*`, `trial-end`).
- [ ] Implement, strings in both languages ("Time for today's English" / "Bugünkü İngilizce zamanı" etc.); push; CI green. Commit.

### Task 9: Review prompt at streak milestones

**Files:** create `Study/ReviewPromptPolicy.swift` (`milestone(forStreak:alreadyPrompted:) -> Int?` for 7/30/100); modify `StudySummaryView`/`PracticeSummaryView` done action to call `requestReview` when a milestone is newly reached; tests `ReviewPromptPolicyTests`.

- [ ] Tests: 7 → 7 once; 8 → nil; 30 after 7 prompted → 30; repeated → nil.
- [ ] Implement; push; CI green. Commit.

### Task 10: Parked content fixes

**Files:** `content/yds-academic-vocab-1/tech/*` (replace `yds-tech-grammar-questions-q06` with a new idea; rebalance unit-13 keys so the key is the longest option in ≤ 50%), vocab2 meaning mismatches listed in `Desktop/ENGLISH_KALANLAR.txt` 7d parked list; regenerate; tests counts unchanged.

- [ ] Apply, run assemble lint, push, CI green. Commit.

### Task 11: Whole-branch review and close

- [ ] Fresh reviewer (most capable model) over `efd8eda..HEAD` covering L1 Task 7 + L2 Task 5 + this plan; one fix wave; CI green.
- [ ] `docs/store-setup.md`: App Store Connect checklist (rename Lexpath + subtitle, prices incl. Turkey overrides, intro offers, Beta App Information, screenshots) + TestFlight device checks for this plan.
- [ ] Update `Desktop/ENGLISH_KALANLAR.txt`. **Do not start a Codemagic build.**
