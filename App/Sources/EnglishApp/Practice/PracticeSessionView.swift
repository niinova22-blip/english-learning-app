// App/Sources/EnglishApp/Practice/PracticeSessionView.swift
import SwiftUI
import SwiftData
import LearningEngine
import TutorEngine

struct PracticeSessionView: View {
    let mode: PracticeSessionViewModel.Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var viewModel: PracticeSessionViewModel?
    @State private var loadError: String?
    @State private var isLoadingTutor = false
    @State private var showTutorSheet = false
    @State private var showPremiumPaywall = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Couldn't open session", systemImage: "exclamationmark.triangle", description: Text(loadError))
                    .overlay(alignment: .bottom) {
                        Button("Back to plan", action: onClose).buttonStyle(PrimaryButtonStyle()).padding()
                    }
            } else if let viewModel {
                content(viewModel)
            } else {
                ProgressView().accessibilityLabel("Loading")
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(isPresented: $showPremiumPaywall) {
            PaywallView(mode: .premium, store: appState.entitlements)
        }
        .sheet(isPresented: $showTutorSheet) {
            if let engine = appState.tutorEngine, let vm = viewModel, let question = vm.current {
                TutorSheetView(engine: engine, questionContext: .question(
                    prompt: question.prompt, options: question.options,
                    correctIndex: question.correctIndex, selectedIndex: vm.selectedIndex,
                    explanationTR: BilingualPick.text(
                        en: question.explanationEN, tr: question.explanationTRText, base: question.explanationTR,
                        language: .current, showEnglish: false
                    ), passage: vm.passage?.body
                ), goalDescription: TutorGoal.activeDescription(in: context))
            }
        }
        .task { start() }
    }

    private func start() {
        guard viewModel == nil else { return }
        let vm = PracticeSessionViewModel(mode: mode, context: context, userID: UserIdentity.current)
        do {
            try vm.start()
            viewModel = vm
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func content(_ vm: PracticeSessionViewModel) -> some View {
        switch vm.step {
        case .loading:
            ProgressView()
        case .unavailable:
            ContentUnavailableView(
                "This lesson isn't ready yet",
                systemImage: "questionmark.folder",
                description: Text("It'll show up here once the content is updated.")
            )
            .overlay(alignment: .bottom) {
                Button("Back to plan", action: onClose).buttonStyle(PrimaryButtonStyle()).padding()
            }
        case .summary:
            PracticeSummaryView(title: vm.lessonTitle, summary: vm.summary(), onDone: onClose)
        case .explanation(let text):
            session(vm) {
                PracticeExplanationView(
                    title: vm.lessonTitle, skill: vm.skill, explanation: text,
                    onContinue: { vm.beginQuestions() }
                )
            }
        case .cards(let cards):
            session(vm) {
                LessonCardsView(
                    title: vm.lessonTitle, skill: vm.skill, cards: cards,
                    onContinue: { vm.beginQuestions() }
                )
            }
        case .question:
            session(vm) {
                if let question = vm.current {
                    PracticeQuestionView(
                        question: question, passage: vm.passage, selectedIndex: vm.selectedIndex,
                        skill: vm.skill,
                        explanationShowsEnglish: Binding(
                            get: { vm.explanationShowsEnglish },
                            set: { vm.explanationShowsEnglish = $0 }
                        ),
                        showsTutorButton: appState.isTutorAvailable,
                        isLoadingTutor: isLoadingTutor,
                        onSelect: { vm.select($0) }, onNext: { vm.next() },
                        onTutor: { Task { await openTutor() } }
                    )
                }
            }
        }
    }

    /// Same single-flight rule as StudySessionView: AppState dedupes
    /// concurrent loads, and a nil engine means "not available", never an
    /// error shown to the learner.
    private func openTutor() async {
        switch appState.tutorAccess {
        case .unavailable: return
        case .needsPremium:
            showPremiumPaywall = true
            return
        case .allowed: break
        }
        guard !isLoadingTutor else { return }
        if appState.tutorEngine == nil {
            isLoadingTutor = true
            await appState.loadTutorEngineIfNeeded()
            isLoadingTutor = false
        }
        if appState.tutorEngine != nil { showTutorSheet = true }
    }

    /// Shared chrome: close button, progress bar, context line, error alert.
    @ViewBuilder
    private func session<Inner: View>(_ vm: PracticeSessionViewModel, @ViewBuilder body: () -> Inner) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.secondaryInk)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
                ProgressBar(progress: vm.progress)
                Text(vm.progressText).font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
            }
            Text(vm.contextLine)
                .font(.caption2.weight(.semibold)).tracking(1.2)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let message = vm.saveError {
                saveErrorRow(vm, message: message)
            }
            body()
        }
        .padding()
        .sensoryFeedback(.selection, trigger: vm.currentIndex)
        .sensoryFeedback(trigger: vm.selectedIndex) { _, picked in
            guard let picked, let correct = vm.current?.correctIndex else { return nil }
            return picked == correct ? .success : .error
        }
    }

    private func saveErrorRow(_ vm: PracticeSessionViewModel, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Couldn't save", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.danger)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 16) {
                Button("Try again") { vm.retrySave() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Button("Close") { vm.clearSaveError() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.danger, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
