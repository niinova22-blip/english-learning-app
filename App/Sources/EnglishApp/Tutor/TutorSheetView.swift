import SwiftUI
import TutorEngine

struct TutorSheetView: View {
    @State private var viewModel: TutorViewModel
    @State private var freeTextQuestion = ""
    @Environment(\.dismiss) private var dismiss

    init(engine: any TutorEngine, context: TutorViewModel.TutorContext) {
        _viewModel = State(initialValue: TutorViewModel(engine: engine, context: context))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                quickActionButtons
                freeTextField
                responseArea
                Spacer()
            }
            .padding()
            .navigationTitle("Ask Tutor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Explain more simply") { Task { await viewModel.ask(.simplerExplanation) } }
            Button("Give another example") { Task { await viewModel.ask(.anotherExample) } }
            Button("How is this different from similar words?") { Task { await viewModel.ask(.compareToSimilarWords) } }
        }
        .buttonStyle(.bordered)
    }

    private var freeTextField: some View {
        HStack {
            TextField("Ask anything about this word...", text: $freeTextQuestion)
                .textFieldStyle(.roundedBorder)
            Button("Ask") {
                let question = freeTextQuestion
                freeTextQuestion = ""
                Task { await viewModel.ask(freeText: question) }
            }
            .disabled(freeTextQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var responseArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
        case .response(let text):
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .failure(let message):
            Text("Couldn't get a response: \(message)")
                .foregroundStyle(.red)
        }
    }
}
