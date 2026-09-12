import SwiftUI
import SwiftData
import LearningEngine

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var items: [LearningItem] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    @State private var reviewedCount = 0
    @State private var showSummary = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .onAppear(perform: loadSessionIfNeeded)
                .navigationDestination(isPresented: $showSummary) {
                    SessionSummaryView(reviewedCount: reviewedCount, onDone: resetSession)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text("Couldn't load today's session: \(loadError)")
                .foregroundStyle(.red)
                .padding()
        } else if items.isEmpty {
            ContentUnavailableView("Nothing due right now", systemImage: "checkmark.circle")
        } else if currentIndex < items.count {
            itemCard(items[currentIndex])
        } else {
            ProgressView()
        }
    }

    private func itemCard(_ item: LearningItem) -> some View {
        VStack(spacing: 20) {
            Text(headword(for: item))
                .font(.largeTitle.bold())

            if isAnswerRevealed, let content = item.content {
                VStack(alignment: .leading, spacing: 12) {
                    Text(content.definition)
                    ForEach(content.exampleSentences, id: \.self) { sentence in
                        Text("“\(sentence)”").italic()
                    }
                    Text(content.translationTR)
                        .foregroundStyle(.secondary)
                }
                .padding()

                HStack {
                    ratingButton("Again", .again, color: .red)
                    ratingButton("Hard", .hard, color: .orange)
                    ratingButton("Good", .good, color: .green)
                    ratingButton("Easy", .easy, color: .blue)
                }
            } else {
                Button("Show Answer") { isAnswerRevealed = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func headword(for item: LearningItem) -> String {
        item.id
            .replacingOccurrences(of: "sample-item-", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func ratingButton(_ title: String, _ rating: FSRSRating, color: Color) -> some View {
        Button(title) { rate(rating) }
            .buttonStyle(.bordered)
            .tint(color)
    }

    private func loadSessionIfNeeded() {
        guard items.isEmpty, !showSummary else { return }
        do {
            let coordinator = TodaySessionCoordinator(context: context, userID: UserIdentity.current)
            items = try coordinator.buildTodaySession()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func rate(_ rating: FSRSRating) {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        let store = FSRSStateStore()
        try? store.recordReview(
            userID: UserIdentity.current,
            itemID: item.id,
            rating: rating,
            now: Date(),
            in: context,
            scheduler: FSRSScheduler()
        )
        reviewedCount += 1
        isAnswerRevealed = false
        currentIndex += 1
        if currentIndex >= items.count {
            showSummary = true
        }
    }

    private func resetSession() {
        items = []
        currentIndex = 0
        reviewedCount = 0
        showSummary = false
        loadSessionIfNeeded()
    }
}
