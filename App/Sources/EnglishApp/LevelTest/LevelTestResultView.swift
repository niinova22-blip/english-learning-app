import SwiftUI
import LearningEngine

struct LevelTestResultView: View {
    let outcome: LevelTestOutcome
    let buttonTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your estimated level").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text(outcome.cefrLevel.rawValue)
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(Theme.primary)
            Text("Vocabulary: \(PercentText.format(share: outcome.vocabularyScore))")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Text("This is just a rough estimate based on this package's word list.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button(buttonTitle, action: onContinue).buttonStyle(PrimaryButtonStyle())
        }
    }
}
