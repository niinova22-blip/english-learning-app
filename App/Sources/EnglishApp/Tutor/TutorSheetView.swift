import SwiftUI
import TutorEngine

struct TutorSheetView: View {
    @State private var viewModel: TutorViewModel
    @State private var freeTextQuestion = ""
    @State private var isQuestionContext: Bool
    @State private var learnerWasCorrect = false
    @Environment(\.dismiss) private var dismiss

    init(engine: any TutorEngine, context: TutorViewModel.TutorContext, goalDescription: String? = nil) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: context, goalDescription: goalDescription))
        _isQuestionContext = State(initialValue: false)
    }

    init(engine: any TutorEngine, questionContext: TutorViewModel.Context, goalDescription: String? = nil) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: questionContext, goalDescription: goalDescription))
        _isQuestionContext = State(initialValue: true)
        if case .question(_, _, let correctIndex, let selectedIndex, _, _) = questionContext {
            _learnerWasCorrect = State(initialValue: selectedIndex == correctIndex)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickActionButtons
                    freeTextField
                    responseArea
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Ask your tutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickAction(isQuestionContext ? "Why this answer?" : "Explain it more simply") { await viewModel.ask(.simplerExplanation) }
            quickAction(isQuestionContext ? "Give a similar example" : "Give another example") { await viewModel.ask(.anotherExample) }
            quickAction(isQuestionContext ? (learnerWasCorrect ? "Why are the other options wrong?" : "Why is my answer wrong?") : "How is it different from similar words?") { await viewModel.ask(.compareToSimilarWords) }
        }
    }

    private func quickAction(_ title: LocalizedStringKey, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var freeTextField: some View {
        HStack(spacing: 8) {
            TextField(isQuestionContext ? "Ask something about this question..." : "Ask something about this word...", text: $freeTextQuestion)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Button("Ask") {
                let question = freeTextQuestion
                freeTextQuestion = ""
                Task { await viewModel.ask(freeText: question) }
            }
            .font(.subheadline.weight(.semibold))
            .tint(Theme.primary)
            .disabled(freeTextQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var responseArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().tint(Theme.primary)
        case .response(let text):
            PaperCard {
                Text(text).font(.body).foregroundStyle(Theme.ink)
            }
        case .failure(let message):
            Text("Could not get a response: \(message)")
                .font(.subheadline)
                .foregroundStyle(Theme.danger)
        }
    }
}
