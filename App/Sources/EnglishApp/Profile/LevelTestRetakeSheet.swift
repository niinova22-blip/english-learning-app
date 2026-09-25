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
                    Button("Cancel") { dismiss() }
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
                    LevelTestResultView(outcome: outcome, buttonTitle: String(localized: "OK")) {
                        do {
                            try LevelTestResultStore.save(outcome, in: context, userID: UserIdentity.current)
                            onFinished(outcome)
                            dismiss()
                        } catch {
                            saveError = String(localized: "Could not save the result.")
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
                    Text("Retake your level test").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
                    Text("In 5-8 minutes, get a rough level estimate based on your vocabulary.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    Spacer(minLength: 0)
                    Button("Start") { viewModel.start() }.buttonStyle(PrimaryButtonStyle())
                }
            } else {
                ContentUnavailableView("Not enough words", systemImage: "exclamationmark.circle")
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        }
    }
}
