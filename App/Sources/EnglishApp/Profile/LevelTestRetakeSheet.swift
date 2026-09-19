import SwiftUI
import SwiftData
import LearningEngine

/// Standalone re-run of the level test from Profil, for someone who skipped
/// it during onboarding (or wants a fresh estimate). Reuses the same
/// question/result views as onboarding; owns its own tiny intro screen
/// since the copy differs from the first-run context.
struct LevelTestRetakeSheet: View {
    let packageID: String
    let onFinished: (LevelTestOutcome) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LevelTestViewModel?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                content.padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LevelTestViewModel(candidates: LevelTestCandidateFetcher.fetch(packageID: packageID, in: context))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if let outcome = viewModel.outcome {
                VStack(spacing: 12) {
                    LevelTestResultView(outcome: outcome, buttonTitle: "Tamam") {
                        do {
                            try persist(outcome)
                            onFinished(outcome)
                            dismiss()
                        } catch {
                            saveError = "Sonuç kaydedilemedi."
                        }
                    }
                    if let saveError {
                        Text(saveError).font(.footnote).foregroundStyle(.red)
                    }
                }
            } else if let question = viewModel.currentQuestion {
                LevelTestQuestionView(question: question, questionNumber: viewModel.questionNumber) { index in
                    viewModel.answer(selectedIndex: index)
                }
            } else if viewModel.isReady {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Seviyeni yeniden test et").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
                    Text("5-8 dakikada kelime bilgine göre yaklaşık bir seviye tahmini üretir.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    Spacer(minLength: 0)
                    Button("Başla") { viewModel.start() }.buttonStyle(PrimaryButtonStyle())
                }
            } else {
                ContentUnavailableView("Yeterli kelime yok", systemImage: "exclamationmark.circle")
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func persist(_ outcome: LevelTestOutcome) throws {
        let userIDValue = UserIdentity.current
        if let existing = try context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userIDValue })).first {
            existing.cefrLevel = outcome.cefrLevel
            existing.vocabularyScore = outcome.vocabularyScore
            existing.completedAt = Date()
        } else {
            context.insert(LevelTestResult(userID: userIDValue, cefrLevel: outcome.cefrLevel, vocabularyScore: outcome.vocabularyScore, completedAt: Date()))
        }
        if let profile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first {
            profile.hasSkippedLevelTest = false
        }
        try context.save()
    }
}
