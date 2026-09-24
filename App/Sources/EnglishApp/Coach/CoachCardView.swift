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
                    Label("Koçun", systemImage: "figure.run.circle")
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
                Text(CoachMessageTemplates.progressLine(for: plan))
                    .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                ProgressBar(progress: plan.completedShare)
                if let locked = CoachMessageTemplates.lockedLine(for: plan) {
                    Text(locked).font(.caption).foregroundStyle(Theme.secondaryInk)
                }
                if case .unreachable = plan.status {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Button("Günlük süreyi artır", action: onOpenSettings)
                            Spacer()
                            Button("Sınav tarihini değiştir", action: onOpenSettings)
                        }
                        VStack(alignment: .leading) {
                            Button("Günlük süreyi artır", action: onOpenSettings)
                            Button("Sınav tarihini değiştir", action: onOpenSettings)
                        }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                } else if CoachMessageTemplates.needsExamDateInvite(plan) {
                    Button(plan.status == .examPassed ? "Sınav tarihini değiştir" : "Sınav tarihini ekle, programını kurayım", action: onOpenSettings)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                }
                if canAskModel && viewModel.source == .template {
                    Button {
                        Task { await viewModel.requestPersonalNote() }
                    } label: {
                        if viewModel.isGenerating {
                            HStack(spacing: 6) { ProgressView(); Text("Koçun yazıyor...") }
                        } else {
                            Label("Koçtan kişisel not al", systemImage: "sparkles")
                        }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                    .disabled(viewModel.isGenerating)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct CoachTeaserCard: View {
    let onUpgrade: () -> Void

    var body: some View {
        Button(action: onUpgrade) {
            PaperCard {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.secondaryInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Koç").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("Sınav tarihine göre kişisel program").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Koç, kilitli. Sınav tarihine göre kişisel program. AI Premium'a geçmek için dokun.")
    }
}
