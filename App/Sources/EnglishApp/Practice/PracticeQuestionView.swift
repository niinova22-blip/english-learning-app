// App/Sources/EnglishApp/Practice/PracticeQuestionView.swift
import SwiftUI
import LearningEngine

/// Steps 2-5: optional pinned passage, prompt, A-E options, and — once an
/// option is tapped — the feedback card with the Turkish explanation, the
/// optional "Öğretmene Sor" button and "Sonraki".
struct PracticeQuestionView: View {
    let question: PracticeSessionViewModel.QuestionVM
    let passage: PracticeSessionViewModel.PassageVM?
    let selectedIndex: Int?
    let skill: Skill
    let showsTutorButton: Bool
    let isLoadingTutor: Bool
    let onSelect: (Int) -> Void
    let onNext: () -> Void
    let onTutor: () -> Void

    @State private var isPassageExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnswered: Bool { selectedIndex != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let passage {
                        passagePanel(passage)
                    }
                    Text(question.prompt)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        optionRow(index: index, option: option)
                    }
                    if isAnswered {
                        feedbackCard
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isAnswered {
                Button("Sonraki", action: onNext).buttonStyle(PrimaryButtonStyle())
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedIndex)
    }

    @ViewBuilder
    private func passagePanel(_ passage: PracticeSessionViewModel.PassageVM) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isPassageExpanded.toggle()
                } label: {
                    HStack {
                        Text(passage.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: isPassageExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPassageExpanded ? "Metni gizle: \(passage.title)" : "Metni göster: \(passage.title)")
                if isPassageExpanded {
                    Text(passage.body)
                        .font(.callout)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func optionRow(index: Int, option: String) -> some View {
        let state = PracticeOptionText.state(index: index, selectedIndex: selectedIndex, correctIndex: question.correctIndex)
        Button {
            onSelect(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(PracticeOptionText.letter(index))
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(tint(for: state))
                Text(option)
                    .font(.subheadline)
                    .foregroundStyle(state == .dimmed ? Theme.secondaryInk : Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon = PracticeOptionText.iconName(for: state) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint(for: state))
                }
            }
            .padding(12)
            .background(background(for: state), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(state == .idle ? Theme.border : tint(for: state), lineWidth: state == .idle ? 1 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
        .accessibilityLabel(PracticeOptionText.accessibilityLabel(index: index, text: option, state: state))
    }

    private func tint(for state: PracticeOptionState) -> Color {
        switch state {
        case .idle: return skill.color
        case .correct: return Theme.primary
        case .wrongPick: return Theme.danger
        case .dimmed: return Theme.secondaryInk
        }
    }

    private func background(for state: PracticeOptionState) -> Color {
        switch state {
        case .idle: return Theme.surface
        case .correct: return Theme.primary.opacity(0.12)
        case .wrongPick: return Theme.danger.opacity(0.12)
        case .dimmed: return Theme.paper
        }
    }

    @ViewBuilder
    private var feedbackCard: some View {
        let wasCorrect = selectedIndex == question.correctIndex
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    wasCorrect ? "Doğru" : "Yanlış",
                    systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(wasCorrect ? Theme.primary : Theme.danger)
                Text(question.explanationTR)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                if showsTutorButton {
                    Button(action: onTutor) {
                        HStack(spacing: 6) {
                            if isLoadingTutor {
                                ProgressView().controlSize(.small).tint(Theme.primary)
                            } else {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                            }
                            Text("Öğretmene Sor")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingTutor)
                }
            }
        }
    }
}
