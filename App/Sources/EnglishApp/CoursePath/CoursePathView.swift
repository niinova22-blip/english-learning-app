import SwiftUI
import SwiftData
import LearningEngine

struct CoursePathView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    private struct ActiveSession: Identifiable {
        enum Kind {
            case study(lessonID: String)
            case practice(lessonID: String)
        }
        let id = UUID()
        let kind: Kind
    }

    @State private var viewModel: CoursePathViewModel?
    @State private var activeSession: ActiveSession?
    @State private var infoMessage: (title: String, body: String)?

    var body: some View {
        NavigationStack {
            ScrollView { content.padding() }
                .background(Theme.paper.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .fullScreenCover(item: $activeSession) { session in
            switch session.kind {
            case .study(let lessonID):
                StudySessionView(mode: .lesson(id: lessonID)) {
                    activeSession = nil
                    refresh()
                }
            case .practice(let lessonID):
                PracticeSessionView(mode: .lesson(id: lessonID)) {
                    activeSession = nil
                    refresh()
                }
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
        VStack(alignment: .leading, spacing: 18) {
            Text("Ders Yolu").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            if let viewModel, !viewModel.sections.isEmpty {
                ForEach(viewModel.sections, id: \.unitID) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.theme.uppercased(with: Locale(identifier: "tr_TR")))
                            .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.secondaryInk)
                        ForEach(Array(section.tasks.enumerated()), id: \.offset) { _, task in
                            PlanTaskRow(task: task, isHighlighted: false) { handle(task) }
                        }
                    }
                }
            } else if viewModel != nil {
                ContentUnavailableView("İçerik yüklenemedi", systemImage: "map")
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
        }
    }

    private func handle(_ task: PlanTask) {
        switch PlanTaskAction.action(for: task) {
        case .startLesson(let id):
            activeSession = ActiveSession(kind: .study(lessonID: id))
        case .startPractice(let lessonID):
            activeSession = ActiveSession(kind: .practice(lessonID: lessonID))
        case .comingSoon(let title): infoMessage = ("Bu ders türü yakında", title)
        case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)
        // Ders Yolu never shows review tasks, so these cannot occur here.
        case .startReview, .startPracticeReview, .none: break
        }
    }

    private func refresh() {
        let vm = viewModel ?? CoursePathViewModel(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
        vm.load()
        viewModel = vm
    }
}
