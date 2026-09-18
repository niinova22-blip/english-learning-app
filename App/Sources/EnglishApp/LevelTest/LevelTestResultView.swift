import SwiftUI
import LearningEngine

struct LevelTestResultView: View {
    let outcome: LevelTestOutcome
    let buttonTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tahmini seviyen").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text(outcome.cefrLevel.rawValue)
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(Theme.primary)
            Text("Kelime bilgisi: %\(Int((outcome.vocabularyScore * 100).rounded()))")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Text("Bu, sadece bu paketin kelime listesine göre kaba bir tahmindir.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button(buttonTitle, action: onContinue).buttonStyle(PrimaryButtonStyle())
        }
    }
}
