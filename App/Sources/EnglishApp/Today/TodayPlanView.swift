import SwiftUI
import SwiftData
import LearningEngine

struct TodayPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    private struct ActiveSession: Identifiable {
        enum Kind {
            case study(StudySessionViewModel.Mode)
            case practice(PracticeSessionViewModel.Mode)
        }
        let id = UUID()
        let kind: Kind
    }

    private enum LoadState { case loading, noContent, failed(String), ready(DailyPlan) }

    @State private var loadState: LoadState = .loading
    @State private var stats: LearnerStats?
    @State private var activeSession: ActiveSession?
    @State private var infoMessage: (title: String, body: String)?
    @State private var lockedLesson: LockedLesson?
    @State private var coachBriefing: CoachBriefing?
    @State private var coachViewModel: CoachViewModel?
    @State private var showStudySettings = false
    @State private var paywall: PaywallMode?

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
            switch session.kind {
            case .study(let mode):
                StudySessionView(mode: mode) {
                    activeSession = nil
                    refresh()
                }
            case .practice(let mode):
                PracticeSessionView(mode: mode) {
                    activeSession = nil
                    refresh()
                }
            }
        }
        .lockedLessonPrompts($lockedLesson)
        .alert(infoMessage?.title ?? "", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("OK", role: .cancel) { infoMessage = nil }
        } message: {
            Text(infoMessage?.body ?? "")
        }
        .sheet(isPresented: $showStudySettings) { StudySettingsSheet() }
        .sheet(item: $paywall) { mode in PaywallView(mode: mode, store: appState.entitlements) }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        case .noContent:
            ContentUnavailableView("Content couldn't load", systemImage: "books.vertical", description: Text("Check the storage warning on the Profile tab."))
        case .failed(let message):
            ContentUnavailableView("Plan couldn't be prepared", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready(let plan):
            planContent(plan)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: DailyPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text((stats?.packageName ?? "").uppercased(with: AppLanguage.current.locale))
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.primary)
                Spacer()
                StreakBadge(days: stats?.streak ?? 0)
            }
            Text("Today's plan").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            coachSection

            let actionable = plan.tasks.filter { if case .locked = $0 { return false } else { return true } }
            if plan.tasks.isEmpty || plan.isComplete {
                PaperCard {
                    Label("That's everything for today", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.primary)
                }
            } else {
                Text("\(tasksText(actionable.count)) · \(aboutMinutesText(PlanTaskText.minutes(plan.totalMinutes)))")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            let highlightIndex = plan.tasks.firstIndex { PlanTaskAction.action(for: $0) != .none && !isLocked($0) }
            ForEach(Array(plan.tasks.enumerated()), id: \.offset) { index, task in
                PlanTaskRow(task: task, isHighlighted: index == highlightIndex, isCoachAdded: isCoachAdded(task, plan)) { handle(task) }
            }

            if !plan.weeklyBalance.isEmpty {
                Text("Weekly skill balance").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryInk).padding(.top, 8)
                ForEach(plan.weeklyBalance, id: \.skill) { balance in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(balance.skill.displayName).font(.footnote).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("target \(PercentText.format(share: balance.targetShare)) · \(PercentText.format(share: balance.actualShare))")
                                .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                        }
                        ProgressBar(progress: balance.targetShare > 0 ? balance.actualShare / balance.targetShare : 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coachSection: some View {
        if let coachBriefing {
            if appState.premiumProvider.isPremium, let coachViewModel {
                CoachCardView(
                    briefing: coachBriefing,
                    viewModel: coachViewModel,
                    canAskModel: appState.tutorAccess == .allowed,
                    onOpenSettings: { showStudySettings = true }
                )
            } else if !appState.premiumProvider.isPremium {
                CoachTeaserCard { paywall = .premium }
            }
        }
    }

    private func isLocked(_ task: PlanTask) -> Bool {
        if case .locked = task { return true } else { return false }
    }

    private func isCoachAdded(_ task: PlanTask, _ plan: DailyPlan) -> Bool {
        if case .lesson(let id, _, _, _, _) = task { return plan.coachAddedLessonIDs.contains(id) }
        return false
    }

    private func tasksText(_ count: Int) -> String { String(localized: "\(count) tasks") }

    private func aboutMinutesText(_ minutes: Int) -> String { String(localized: "about \(minutes) min") }

    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startReview(let count):
            activeSession = ActiveSession(kind: .study(.review(cardCount: count)))
        case .startLesson(let id):
            activeSession = ActiveSession(kind: .study(.lesson(id: id)))
        case .startPractice(let lessonID):
            activeSession = ActiveSession(kind: .practice(.lesson(id: lessonID)))
        case .startPracticeReview(let itemID, let lessonID):
            activeSession = ActiveSession(kind: .practice(.review(lessonID: lessonID, itemID: itemID)))
        case .comingSoon(let title): infoMessage = (String(localized: "This lesson type is coming soon"), title)
        case .locked(let title): lockedLesson = LockedLesson(title: title)
        case .none: break
        }
    }

    private func refresh() {
        let coordinator = TodayPlanCoordinator(
            context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider,
            isPremium: appState.premiumProvider.isPremium
        )
        do {
            guard let plan = try coordinator.buildPlan() else {
                loadState = .noContent
                return
            }
            stats = try coordinator.stats()
            coachBriefing = try? coordinator.buildCoachBriefing()
            if let coachBriefing, appState.premiumProvider.isPremium {
                let viewModel = coachViewModel ?? CoachViewModel(cache: appState.coachNoteCache) { [appState] in
                    await appState.loadTutorEngineIfNeeded()
                    return appState.tutorEngine
                }
                viewModel.show(coachBriefing, day: Calendar.current.startOfDay(for: Date()), coachAddedLessons: !plan.coachAddedLessonIDs.isEmpty)
                coachViewModel = viewModel
            }
            loadState = .ready(plan)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
