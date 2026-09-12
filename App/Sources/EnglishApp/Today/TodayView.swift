import SwiftUI
import SwiftData
import LearningEngine

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var items: [LearningItem] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    @State private var reviewedCount = 0
    @State private var showSummary = false
    @State private var loadError: String?
    @State private var reviewSaveError: String?
    @State private var itemShownAt = Date()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .onAppear(perform: loadSessionIfNeeded)
                .onChange(of: appState.dataGeneration) { _, _ in resetSession() }
                .alert(
                    "Couldn't save review",
                    isPresented: Binding(
                        get: { reviewSaveError != nil },
                        set: { isPresented in if !isPresented { reviewSaveError = nil } }
                    ),
                    presenting: reviewSaveError
                ) { _ in
                    Button("OK", role: .cancel) { reviewSaveError = nil }
                } message: { message in
                    Text(message)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text("Couldn't load today's session: \(loadError)")
                .foregroundStyle(.red)
                .padding()
        } else if showSummary {
            SessionSummaryView(reviewedCount: reviewedCount, onDone: resetSession)
        } else if items.isEmpty {
            ContentUnavailableView("Nothing due right now", systemImage: "checkmark.circle")
        } else if currentIndex < items.count, !items[currentIndex].isDeleted {
            itemCard(items[currentIndex])
        } else if currentIndex < items.count {
            // The current item's underlying model was deleted out from under us
            // (e.g. a data reset happened while this session was in progress).
            // Don't touch it — treat it like the end of the queue and let the
            // pending reload (triggered by AppState.dataGeneration) take over.
            ProgressView()
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
        item.content?.headword ?? item.id
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
            // Items without content can't be shown or rated by this UI (no
            // definition/examples/translation to reveal). Skip them here so the
            // user never lands on a "Show Answer" that has nothing to reveal and
            // no way to proceed. Not reachable with the current seed data, but
            // content is a genuinely optional relationship in the schema.
            items = try coordinator.buildTodaySession().filter { $0.content != nil }
            itemShownAt = Date()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func rate(_ rating: FSRSRating) {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        let store = FSRSStateStore()
        do {
            try store.recordReview(
                userID: UserIdentity.current,
                itemID: item.id,
                rating: rating,
                now: Date(),
                in: context,
                scheduler: FSRSScheduler(),
                reactionTimeMs: Int(Date().timeIntervalSince(itemShownAt) * 1000)
            )
        } catch {
            // Surface the failure instead of silently pretending the review was
            // saved: don't advance currentIndex/reviewedCount for a review that
            // wasn't actually persisted. The user stays on the same item and can
            // retry the rating.
            reviewSaveError = error.localizedDescription
            return
        }
        reviewedCount += 1
        isAnswerRevealed = false
        currentIndex += 1
        itemShownAt = Date()
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
