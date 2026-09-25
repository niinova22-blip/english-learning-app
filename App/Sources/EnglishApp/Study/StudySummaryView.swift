import SwiftUI

struct StudySummaryView: View {
    let summary: StudySessionViewModel.Summary
    let streak: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(.largeTitle).weight(.bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primary.opacity(0.15), in: Circle())
            Text(summary.title).font(.serifTitle(.title)).foregroundStyle(Theme.ink)
            if let subtitle = summary.subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }
            HStack(spacing: 8) {
                StatTile(value: "\(summary.cardCount)", label: String(localized: "Cards"))
                StatTile(value: "%\(Int((summary.knownShare * 100).rounded()))", label: String(localized: "Accuracy"), tint: Theme.primary)
                StatTile(value: "\(streak)", label: String(localized: "Day streak"), tint: Theme.accent)
            }
            .padding(.top, 8)
            if !summary.needsReview.isEmpty {
                PaperCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORDS TO REVIEW").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk)
                        Text(summary.needsReview.joined(separator: " · ")).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                }
            }
            Spacer()
            Button("Back to plan", action: onDone).buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Theme.paper.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: summary.cardCount)
    }
}

#Preview("Summary") {
    StudySummaryView(
        summary: .init(title: "Ders tamamlandı", subtitle: "Science & Research Methods · 2", cardCount: 10, knownShare: 0.8, needsReview: ["empirical", "variable"]),
        streak: 12, onDone: {}
    )
}
