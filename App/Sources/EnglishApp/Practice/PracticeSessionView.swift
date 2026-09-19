// App/Sources/EnglishApp/Practice/PracticeSessionView.swift
import SwiftUI
import SwiftData
import LearningEngine

struct PracticeSessionView: View {
    let mode: PracticeSessionViewModel.Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context

    @State private var viewModel: PracticeSessionViewModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Oturum açılamadı", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let viewModel {
                content(viewModel)
            } else {
                ProgressView().accessibilityLabel("Yükleniyor")
            }
        }
        .background(Theme.paper.ignoresSafeArea())
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
                "Bu ders henüz hazır değil",
                systemImage: "questionmark.folder",
                description: Text("İçerik güncellendiğinde burada görünecek.")
            )
            .overlay(alignment: .bottom) {
                Button("Plana dön", action: onClose).buttonStyle(PrimaryButtonStyle()).padding()
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
        case .question:
            session(vm) {
                if let question = vm.current {
                    PracticeQuestionView(
                        question: question, passage: vm.passage, selectedIndex: vm.selectedIndex,
                        skill: vm.skill, showsTutorButton: false, isLoadingTutor: false,
                        onSelect: { vm.select($0) }, onNext: { vm.next() }, onTutor: {}
                    )
                }
            }
        }
    }

    /// Shared chrome: close button, progress bar, context line, error alert.
    @ViewBuilder
    private func session<Inner: View>(_ vm: PracticeSessionViewModel, @ViewBuilder body: () -> Inner) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.secondaryInk)
                }
                .accessibilityLabel("Kapat")
                ProgressBar(progress: vm.progress)
                Text(vm.progressText).font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
            }
            Text(vm.contextLine)
                .font(.caption2.weight(.semibold)).tracking(1.2)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            body()
        }
        .padding()
        .sensoryFeedback(.selection, trigger: vm.currentIndex)
        .alert(
            "Kaydedilemedi",
            isPresented: Binding(get: { vm.saveError != nil }, set: { if !$0 { vm.clearSaveError() } }),
            presenting: vm.saveError
        ) { _ in
            Button("Tekrar dene") { vm.retrySave() }
            Button("Kapat", role: .cancel) { vm.clearSaveError() }
        } message: { message in
            Text(message)
        }
    }
}
