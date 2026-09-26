import SwiftUI
import LearningEngine

/// Front shows only the headword; back shows meaning, example and
/// collocations. Flips in 3D, or cross-fades when Reduce Motion is on.
struct StudyCardView: View {
    let card: StudySessionViewModel.Card
    let isRevealed: Bool
    let showsTutorButton: Bool
    let isLoadingTutor: Bool
    var language: AppLanguage = .current
    let onTutor: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            front
                .opacity(isRevealed ? 0 : 1)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (isRevealed ? 180 : 0)), axis: (x: 0, y: 1, z: 0))
            back
                .opacity(isRevealed ? 1 : 0)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (isRevealed ? 0 : -180)), axis: (x: 0, y: 1, z: 0))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45), value: isRevealed)
    }

    private var front: some View {
        VStack(spacing: 12) {
            SkillBadge(skill: card.skill)
            Text(card.headword)
                .font(.headword(.largeTitle))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Try to recall the meaning")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
        .background(cardBackground)
    }

    private var back: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.headword).font(.headword(.title)).foregroundStyle(Theme.ink)
                    Spacer()
                    if showsTutorButton {
                        Button(action: onTutor) {
                            if isLoadingTutor {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles").font(.title3).foregroundStyle(Theme.primary)
                            }
                        }
                        .disabled(isLoadingTutor)
                        .accessibilityLabel("Ask the tutor about this word")
                    }
                }
                if language == .turkish, !card.translationTR.isEmpty {
                    Text(card.translationTR).font(.headline).foregroundStyle(Theme.primary)
                }
                Text(card.definition).font(.body).foregroundStyle(Theme.ink)
                if let example = card.exampleSentence {
                    sectionLabel(String(localized: "EXAMPLE"))
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.callout.italic())
                        .foregroundStyle(Theme.ink)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 2) }
                }
                if !card.collocations.isEmpty {
                    sectionLabel(String(localized: "COLLOCATIONS"))
                    FlowChips(items: card.collocations)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(cardBackground)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk).padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.surface)
            .cardShadow()
    }
}

/// Wrapping row of small chips (collocations).
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.caption)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview("Card back · light") {
    StudyCardView(
        card: .init(id: "i", headword: "hypothesis", definition: "A proposed explanation made on the basis of limited evidence.",
                    exampleSentence: "The researchers tested the hypothesis that sleep improves memory.",
                    translationTR: "hipotez, varsayım", collocations: ["test a hypothesis", "support a hypothesis"], skill: .vocabulary),
        isRevealed: true, showsTutorButton: true, isLoadingTutor: false, onTutor: {}
    )
    .padding().background(Theme.paper).preferredColorScheme(.light)
}

#Preview("Card front · dark") {
    StudyCardView(
        card: .init(id: "i", headword: "hypothesis", definition: "d", exampleSentence: nil, translationTR: "hipotez", collocations: [], skill: .vocabulary),
        isRevealed: false, showsTutorButton: false, isLoadingTutor: false, onTutor: {}
    )
    .padding().background(Theme.paper).preferredColorScheme(.dark)
}
