// App/Sources/EnglishApp/Practice/PracticeSummaryView.swift
import SwiftUI

struct PracticeSummaryView: View {
    let title: String
    let summary: PracticeSessionViewModel.Summary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
            VStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(.largeTitle).weight(.bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primary.opacity(0.15), in: Circle())
            Text("Oturum tamamlandı").font(.serifTitle(.title)).foregroundStyle(Theme.ink)
            Text(title).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 8) {
                StatTile(value: "\(summary.correctCount)/\(summary.total)", label: "doğru")
                StatTile(value: "%\(summary.percent)", label: "başarı", tint: Theme.primary)
            }
            .padding(.top, 8)
            if !summary.missedPrompts.isEmpty {
                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YANLIŞ YAPTIKLARIN")
                            .font(.caption2.weight(.semibold)).tracking(1)
                            .foregroundStyle(Theme.secondaryInk)
                        ForEach(Array(summary.missedPrompts.enumerated()), id: \.offset) { _, prompt in
                            Text(prompt)
                                .font(.footnote)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            if let nextReviewText = summary.nextReviewText {
                Text("Bu konuyu \(nextReviewText) sonra tekrar edeceğiz")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            }
            .frame(maxWidth: .infinity)
            }
            Button("Plana dön", action: onDone).buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Theme.paper.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: summary.total)
    }
}

#Preview("Practice summary") {
    PracticeSummaryView(
        title: "Zamanlar (Tenses)",
        summary: .init(
            correctCount: 6, total: 8, percent: 75,
            missedPrompts: ["By the time the central bank announced the new interest rate, most investors ---- their portfolios."],
            nextReviewText: "3 gün"
        ),
        onDone: {}
    )
}
