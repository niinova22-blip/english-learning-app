# Final polish — native look, one language, AI Premium trial

Date: 2026-09-25 · Status: approved in conversation (sections 1-3)
Branch: `release-prep`. **No build / TestFlight upload at the end** (user instruction).

## Why

TestFlight build 2 feedback: the user likes the app but wants (1) a more
iPhone-like look and better colors, (2) one consistent language (first launch
shows Turkish and English mixed), (3) a way to try the AI coach — a 1-week free
trial to drive purchases, (4) real prices for subscriptions and packages,
(5) a richer AI Premium page that sells everything the coach does, and
(6) whatever else is missing to call the app finished.

## Decisions (user-approved)

- Colors: **A** — Claude picks one palette for everyone (no user themes).
- Visual direction: **A** — native iOS with brand colors.
- Prices: **A** — Premium monthly $6.99 / ₺149,99; yearly $39.99 / ₺899,99;
  YDS $12.99 / ₺349,99; Business and Everyday $9.99 / ₺249,99 (one-time).
  1-week free intro offer on **both** subscriptions.
- Content language: **A+B** — bilingual titles; YDS hidden on English UI.
- Extras: all seven (onboarding trial offer, Today coach teaser, trial-end
  reminder, daily reminder, review prompt, pending reviews + parked content
  fixes, free preview unchanged).

## 1. Visual system

- `Theme`: background = iOS grouped background (`systemGroupedBackground` /
  `secondarySystemGroupedBackground` for cards); petrol `#0D9488`-family and
  orange kept, tuned per mode for contrast (WCAG AA for text on surfaces);
  skill colors unchanged. Role names stay (`paper`, `surface`, …) so screens
  compile unchanged; `border` becomes a hairline used only where needed.
- Typography: SF Pro titles (`.largeTitle.bold` etc.), SF Rounded for numbers
  (stats, streak, progress, prices). Serif only for the headword on the study
  card. `Font.serifTitle` is replaced by `Font.appTitle`; call sites updated.
- Cards: borderless, 20pt continuous corners, soft shadow (light mode only).
- Effects (new `DesignSystem/Effects.swift`), all respecting Reduce Motion:
  pressable spring scale for buttons/rows; `sensoryFeedback` on answer
  correct/wrong, rating, lesson complete, streak up, purchase success;
  `symbolEffect` (streak flame bounce, checkmark draw); `contentTransition(.numericText())`
  for counters; session-summary celebration (particle burst, 1.2 s);
  `glassEffect` on iOS 26 for tab bar-adjacent buttons and the primary CTA
  capsule, `.ultraThinMaterial` fallback on iOS 17-25.

## 2. One interface language

- Package JSON gains optional bilingual fields: `nameLocalized`,
  `summaryLocalized` (package), `themeLocalized` (unit), `titleLocalized`
  (lesson), each `{"en": "...", "tr": "..."}`. Importer copies them into new
  optional SwiftData properties (`nameEN/nameTR`, `summaryEN/summaryTR`,
  `themeEN/themeTR`, `titleEN/titleTR`) — additive, lightweight migration.
- `LocalizedContent` helpers pick the UI-language value, falling back to the
  base field. Every screen showing a package name, summary, unit theme or
  lesson title uses them (onboarding, goal switcher, Today, Course, Profile,
  paywall, practice/study headers, coach).
- All three packages get every title in both languages; versions bump
  (YDS 10, Business/Everyday +1). IDs unchanged → progress kept.
- Content lint (both assemble scripts): every package/unit/lesson must carry
  both languages; CI fails otherwise.
- Package visibility: `PackageOrdering.visible(_:language:activeID:owned:)` —
  on English UI, packages with `audience == "tr"` are hidden unless active or
  owned. Used by onboarding and the goal switcher.
- Learning content (items, questions, explanations) stays in the package's
  medium language by design.

## 3. Trial, prices, AI Premium page

- `Products.storekit`: prices above; both subscriptions get an introductory
  offer `P1W` free trial.
- `StoreProduct` gains `trialPeriodDays: Int?` (nil = no intro offer) and
  `isTrialEligible: Bool` (StoreKit `isEligibleForIntroOffer`), plus
  `pricePerMonthText` for yearly. The live service fills them; fakes in tests.
- `PaywallView` (premium mode) rebuilt: hero (on-device, offline, private),
  sections Coach / Word tutor / Question explainer / Free chat listing only
  shipped features (see list below), plan cards (yearly first, "Best value ·
  save 52%" computed from real prices, per-month text), trial timeline
  (Today → Day 6 reminder → Day 7 charged) shown only when eligible, CTA
  "Start 1-week free trial" / "Subscribe", renewal disclosure with the
  after-trial price, terms + privacy links, restore.
  Coach features: exam/target-date daily plan; extra lessons when behind;
  final-week review mode; weakest-skill focus; weekly summary and estimated
  finish date; personal note from the coach.
- Package paywall: unit/lesson/question counts computed from content, "first
  unit free" note.

## 4. Conversion and retention

- **Onboarding trial step** after the level-test result/skip: goal-personalised
  pitch (days to exam/target when set), "Try free for 1 week", "Not now".
  Profile is persisted before this step; skipped when not eligible or already
  premium.
- **Today coach teaser** (free users): real coach status badge + estimated
  finish, details blurred, "Try free for 7 days"; dismiss hides it 7 days
  (`UserDefaults` timestamp).
- **Notifications** (`Notifications/ReminderScheduler.swift`, pure rules +
  thin `UNUserNotificationCenter` adapter):
  - Daily reminder: onboarding step (default 20:00, skippable) + Profile
    toggle/time; permission asked only when enabling; today's reminder is
    removed once the day's plan is complete; rescheduled on app launch and
    plan completion (next 7 days scheduled individually).
  - Trial ending: when a subscription transaction with an introductory offer
    is active, schedule a reminder 24 h before `expirationDate`; cancel when
    the entitlement becomes inactive or auto-renew is off.
- **Review prompt**: on closing the session summary when the streak just
  reached 7, 30 or 100 days (`requestReview`); remembered per milestone.

## 5. Close

- L1 Task 7 + L2 Task 5 whole-branch reviews, one fix wave.
- Parked content fixes (7d: `yds-tech-grammar-questions-q06` duplicate idea,
  answer-length bias in unit 13 keys, listed meaning mismatches).
- Free preview unchanged (first unit of each package).
- `docs/store-setup.md`: step-by-step App Store Connect checklist (rename to
  Lexpath + subtitle, prices incl. Turkey, intro offers, Beta App
  Information, screenshots) + TestFlight device checks for this work.
- Green CI. **No Codemagic build.**

## Error handling

- Missing localized title → base field. Products fail to load → existing
  retry state; trial UI hidden. Eligibility unknown → treat as not eligible
  (never promise a trial we can't give). Notification permission denied →
  toggle off with a note linking to Settings. Scheduling failures are logged
  and ignored.

## Testing

Unit tests: localized-title fallback; package visibility (tr/en, active,
owned); trial eligibility → CTA/timeline texts; savings % computation;
reminder rules (skip completed day, 7-day window, trial 24 h before expiry,
cancel on inactive); review milestones once each; teaser dismiss window;
onboarding step order incl. trial/reminder steps. Content lint for bilingual
titles. Visual effects verified on device (TestFlight checklist).

## Out of scope

User-selectable themes, widgets, server-side receipts, win-back offers,
store screenshots production (separate task after this).
