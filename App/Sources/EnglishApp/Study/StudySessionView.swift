import SwiftUI
import SwiftData
import LearningEngine
import TutorEngine

struct StudySessionView: View {
    let mode: StudySessionViewModel.Mode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage("hint.ratingExplained") private var ratingHintShown = false

    @State private var viewModel: StudySessionViewModel?
    @State private var loadError: String?
    @State private var streak = 0
    @State private var isLoadingTutor = false
    @State private var showTutorSheet = false
    @State private var showPremiumPaywall = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Oturum açılamadı", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let viewModel {
                if viewModel.isFinished {
                    StudySummaryView(summary: viewModel.summary(), streak: streak, onDone: onClose)
                        .task { streak = (try? planCoordinator.streak()) ?? 0 }
                } else {
                    session(viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .task { start() }
    }

    private var planCoordinator: TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
    }

    private func start() {
        guard viewModel == nil else { return }
        let vm = StudySessionViewModel(mode: mode, context: context, userID: UserIdentity.current)
        do {
            try vm.start()
            viewModel = vm
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func session(_ vm: StudySessionViewModel) -> some View {
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

            if let card = vm.current {
                StudyCardView(
                    card: card, isRevealed: vm.isRevealed,
                    showsTutorButton: appState.isTutorAvailable, isLoadingTutor: isLoadingTutor,
                    onTutor: { Task { await openTutor() } }
                )
                .onTapGesture { if !vm.isRevealed { vm.reveal() } }
                .sheet(isPresented: $showPremiumPaywall) {
                    PaywallView(mode: .premium, store: appState.entitlements)
                }
                .sheet(isPresented: $showTutorSheet) {
                    if let engine = appState.tutorEngine {
                        TutorSheetView(engine: engine, context: .init(
                            headword: card.headword, definition: card.definition,
                            exampleSentences: card.exampleSentence.map { [$0] } ?? [],
                            translationTR: card.translationTR
                        ))
                    }
                }
            }

            Spacer(minLength: 0)

            if vm.isRevealed {
                if !ratingHintShown {
                    Text("Kelimeyi ne kadar iyi bildiğini seç. Uygulama bir sonraki tekrar zamanını buna göre ayarlar.")
                        .font(.footnote)
                        .foregroundStyle(Color.white)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { ratingHintShown = true }
                }
                let intervals = vm.intervalTexts()
                HStack(spacing: 6) {
                    ForEach(FSRSRating.allCases, id: \.self) { rating in
                        RatingButton(rating: rating, intervalText: intervals[rating] ?? "") {
                            ratingHintShown = true
                            vm.rate(rating)
                        }
                    }
                }
            } else {
                Button("Cevabı göster") { vm.reveal() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .sensoryFeedback(.selection, trigger: vm.currentIndex)
        .alert(
            "Puan kaydedilemedi",
            isPresented: Binding(get: { vm.saveError != nil }, set: { if !$0 { vm.clearSaveError() } }),
            presenting: vm.saveError
        ) { _ in
            Button("Tamam", role: .cancel) { vm.clearSaveError() }
        } message: { message in
            Text(message)
        }
    }

    /// Same single-flight rule as before: AppState dedupes concurrent loads.
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
}
