import SwiftUI
import LearningEngine

/// Shown once per package, the first time it becomes the active goal: what
/// it prepares you for, how the free daily plan works, what AI Premium adds
/// and how you will progress. Re-openable from Profile.
struct PackageIntroView: View {
    let package: ContentPackage
    let dailyMinutes: Int
    var language: AppLanguage = .current
    let onDone: () -> Void

    @State private var page = 0
    private let pageCount = 4

    private var code: String { language == .turkish ? "tr" : "en" }
    private var facts: PackageIntroFacts { PackageIntroFacts(package: package, dailyMinutes: dailyMinutes) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button("Skip", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("package-intro-skip")
            }
            TabView(selection: $page) {
                pageView { aboutPage }.tag(0)
                pageView { freePlanPage }.tag(1)
                pageView { premiumPage }.tag(2)
                pageView { progressPage }.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            if page + 1 < pageCount {
                Button("Next") { withAnimation { page += 1 } }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("package-intro-next")
            } else {
                Button("Let's start", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("package-intro-done")
            }
        }
        .padding()
        .background(Theme.paper.ignoresSafeArea())
    }

    private func pageView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 40)
        }
    }

    private func header(_ symbol: String, _ title: String, tint: Color = Theme.primary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.appTitle(.title2))
                .foregroundStyle(Theme.ink)
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.body).foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.primary)
        }
    }

    // 1. What this package prepares you for.
    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("flag.checkered", package.name(for: code))
            Text("Level \(package.levelLower)–\(package.levelUpper)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            if let intro = package.intro(for: code) {
                PaperCard {
                    Text(intro).font(.body).foregroundStyle(Theme.ink)
                }
            }
        }
    }

    // 2. The free daily routine and the real skill mix.
    private var freePlanPage: some View {
        let facts = facts
        return VStack(alignment: .leading, spacing: 16) {
            header("calendar", String(localized: "Your daily plan"))
            bullet("arrow.triangle.2.circlepath", String(localized: "Reviews come first: each word comes back just before you would forget it."))
            bullet("plus.circle", String(localized: "Then new lessons, in order."))
            PaperCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT YOU STUDY")
                        .font(.caption2.weight(.semibold)).tracking(1.2)
                        .foregroundStyle(Theme.secondaryInk)
                    ForEach(facts.focusSkills, id: \.self) { skill in
                        HStack {
                            SkillBadge(skill: skill)
                            Spacer()
                            Text(PercentText.format(facts.percent(of: skill)))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    if !facts.skippedSkills.isEmpty {
                        Text("Not in this package: \(facts.skippedSkills.map(\.displayName).formatted(.list(type: .and).locale(language.locale)))")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
            }
            bullet("gift", String(localized: "The first unit is free."))
        }
    }

    // 3. What AI Premium adds.
    private var premiumPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("sparkles", String(localized: "With AI Premium"), tint: Theme.accent)
            bullet("calendar.badge.clock", package.goal.isExam
                ? String(localized: "Your coach plans your study around your exam date.")
                : String(localized: "Your coach plans your study around your target date."))
            bullet("arrow.up.forward.circle", String(localized: "Falling behind? The coach adds catch-up lessons."))
            bullet("checkmark.seal", String(localized: "In the final week you only review."))
            bullet("bubble.left.and.text.bubble.right", String(localized: "The tutor explains any word or question."))
        }
    }

    // 4. How you will progress.
    private var progressPage: some View {
        let facts = facts
        return VStack(alignment: .leading, spacing: 16) {
            header("map", String(localized: "How you'll progress"))
            bullet("list.number", String(localized: "Units open in order on the Course tab."))
            PaperCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(facts.units) units · \(facts.lessons) lessons")
                        .font(.headline).foregroundStyle(Theme.ink)
                    Text("About \(facts.averageLessonMinutes) min per lesson")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    Text("At \(facts.dailyMinutes) min a day: about \(String(localized: "\(facts.estimatedWeeks) weeks"))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primary)
                }
            }
        }
    }
}
