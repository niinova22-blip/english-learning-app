// App/Sources/EnglishApp/Practice/PracticeExplanationView.swift
import SwiftUI
import LearningEngine

/// Step 1 of a grammar lesson: the rule card, then "Go to questions".
struct PracticeExplanationView: View {
    let title: String
    let skill: Skill
    let explanation: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SkillBadge(skill: skill)
                    Text(title)
                        .font(.serifTitle(.title))
                        .foregroundStyle(Theme.ink)
                    PaperCard {
                        Text(explanation)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Go to questions", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

#Preview("Explanation") {
    PracticeExplanationView(
        title: "Zamanlar (Tenses)",
        skill: .grammar,
        explanation: "YDS'de zaman soruları neredeyse her zaman cümledeki bir ZAMAN İŞARETİNE dayanır.\n\n• Past perfect (had + V3): geçmişteki iki olaydan önce olanı için.",
        onContinue: {}
    )
    .padding()
    .background(Theme.paper)
}
