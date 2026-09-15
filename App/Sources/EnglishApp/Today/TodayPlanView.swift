import SwiftUI
import SwiftData
import LearningEngine

struct TodayPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    private struct ActiveSession: Identifiable {
        let id = UUID()
        let mode: StudySessionViewModel.Mode
    }

    private enum LoadState { case loading, noContent, failed(String), ready(DailyPlan) }

    @State private var loadState: LoadState = .loading
    @State private var stats: LearnerStats?
    @State private var activeSession: ActiveSession?
    @State private var infoMessage: (title: String, body: String)?

    var body: some View {
        NavigationStack {
            ScrollView {
                content.padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .fullScreenCover(item: $activeSession) { session in
            StudySessionView(mode: session.mode) {
                activeSession = nil
                refresh()
            }
        }
        .alert(infoMessage?.title ?? "", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("Tamam", role: .cancel) { infoMessage = nil }
        } message: {
            Text(infoMessage?.body ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        case .noContent:
            ContentUnavailableView("İçerik yüklenemedi", systemImage: "books.vertical", description: Text("Profil sekmesindeki depolama uyarısına bak."))
        case .failed(let message):
            ContentUnavailableView("Plan hazırlanamadı", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready(let plan):
            planContent(plan)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: DailyPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text((stats?.packageName ?? "").uppercased(with: Locale(identifier: "tr_TR")))
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.primary)
                Spacer()
                StreakBadge(days: stats?.streak ?? 0)
            }
            Text("Bugünün planı").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

            let actionable = plan.tasks.filter { if case .locked = $0 { return false } else { return true } }
            if plan.tasks.isEmpty || plan.isComplete {
                PaperCard {
                    Label("Bugünlük hepsi bu", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.primary)
                }
            } else {
                Text("\(actionable.count) görev · yaklaşık \(PlanTaskText.minutes(plan.totalMinutes)) dk")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            let highlightIndex = plan.tasks.firstIndex { PlanTaskAction.action(for: $0) != .none && !isLocked($0) }
            ForEach(Array(plan.tasks.enumerated()), id: \.offset) { index, task in
                PlanTaskRow(task: task, isHighlighted: index == highlightIndex) { handle(task) }
            }

            if !plan.weeklyBalance.isEmpty {
                Text("Bu hafta beceri dengesi").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryInk).padding(.top, 8)
                ForEach(plan.weeklyBalance, id: \.skill) { balance in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(balance.skill.displayName).font(.footnote).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("hedef %\(percent(balance.targetShare)) · %\(percent(balance.actualShare))")
                                .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                        }
                        ProgressBar(progress: balance.targetShare > 0 ? balance.actualShare / balance.targetShare : 0)
                    }
                }
            }
        }
    }

    private func isLocked(_ task: PlanTask) -> Bool {
        if case .locked = task { return true } else { return false }
    }

    private func percent(_ share: Double) -> Int { Int((share * 100).rounded()) }

    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startReview(let count): activeSession = ActiveSession(mode: .review(cardCount: count))
        case .startLesson(let id): activeSession = ActiveSession(mode: .lesson(id: id))
        case .comingSoon(let title): infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)
        case .none: break
        }
    }

    private func refresh() {
        let coordinator = TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
        do {
            guard let plan = try coordinator.buildPlan() else {
                loadState = .noContent
                return
            }
            stats = try coordinator.stats()
            loadState = .ready(plan)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
