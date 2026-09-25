import SwiftUI
import LearningEngine

/// Premium coach card at the top of Today. Free learners get `CoachTeaserCard`.
struct CoachCardView: View {
    let briefing: CoachBriefing
    let viewModel: CoachViewModel
    let canAskModel: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        let plan = briefing.plan
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Your coach", systemImage: "figure.run.circle")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.primary)
                    Spacer()
                    Text(CoachMessageTemplates.badge(for: plan.status))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Text(viewModel.text)
                    .font(.subheadline).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CoachMessageTemplates.progressLine(for: plan, isExam: briefing.isExamGoal))
                    .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                ProgressBar(progress: plan.completedShare)
                if let locked = CoachMessageTemplates.lockedLine(for: plan) {
                    Text(locked).font(.caption).foregroundStyle(Theme.secondaryInk)
                }
                if case .unreachable = plan.status {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Button("Increase daily time", action: onOpenSettings)
                            Spacer()
                            Button(changeDateTitle, action: onOpenSettings)
                        }
                        VStack(alignment: .leading) {
                            Button("Increase daily time", action: onOpenSettings)
                            Button(changeDateTitle, action: onOpenSettings)
                        }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                } else if CoachMessageTemplates.needsExamDateInvite(plan) {
                    Button(plan.status == .examPassed ? changeDateTitle : addDateTitle, action: onOpenSettings)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                }
                if canAskModel && viewModel.source == .template {
                    Button {
                        Task { await viewModel.requestPersonalNote() }
                    } label: {
                        if viewModel.isGenerating {
                            HStack(spacing: 6) { ProgressView(); Text("Your coach is writing...") }
                        } else {
                            Label("Get a personal note from your coach", systemImage: "sparkles")
                        }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                    .disabled(viewModel.isGenerating)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var changeDateTitle: String {
        briefing.isExamGoal ? String(localized: "Change exam date") : String(localized: "Change target date")
    }

    private var addDateTitle: String {
        briefing.isExamGoal
            ? String(localized: "Add your exam date and I'll build your plan")
            : String(localized: "Add a target date and I'll build your plan")
    }
}

/// Free users see what their coach would say: the real status badge and
/// progress line, the message blurred, and a way to start the trial.
struct CoachTeaserCard: View {
    let briefing: CoachBriefing
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Coach", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primary)
                    Text(CoachMessageTemplates.badge(for: briefing.plan.status))
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryInk)
                    }
                    .accessibilityLabel("Hide for a week")
                }
                Text(CoachMessageTemplates.progressLine(for: briefing.plan, isExam: briefing.isExamGoal))
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                Text(CoachMessageTemplates.message(for: briefing))
                    .font(.subheadline).foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .blur(radius: 5)
                    .accessibilityHidden(true)
                Button("Try free for 7 days", action: onUpgrade)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

/// How long a dismissed coach teaser stays hidden.
enum TeaserPolicy {
    static let dismissedKey = "coach.teaser.dismissedAt"
    static let quietDays: Double = 7

    static func shouldShow(lastDismissed: Date?, now: Date) -> Bool {
        guard let lastDismissed else { return true }
        return now.timeIntervalSince(lastDismissed) >= quietDays * 86_400
    }
}
