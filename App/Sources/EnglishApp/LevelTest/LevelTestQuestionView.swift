import SwiftUI
import LearningEngine

struct LevelTestQuestionView: View {
    let question: LevelTestQuestion
    let questionNumber: Int
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Question \(questionNumber)/\(LevelTestEngine.questionCount)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryInk)
            Text(question.headword).font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("Which is the Turkish meaning?").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    onAnswer(index)
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}
