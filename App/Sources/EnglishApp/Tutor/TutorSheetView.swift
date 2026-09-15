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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickActionButtons
                    freeTextField
                    responseArea
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Öğretmene sor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickAction("Daha basit anlat") { await viewModel.ask(.simplerExplanation) }
            quickAction("Başka bir örnek ver") { await viewModel.ask(.anotherExample) }
            quickAction("Benzer kelimelerden farkı ne?") { await viewModel.ask(.compareToSimilarWords) }
        }
    }

    private func quickAction(_ title: String, _ action: @escaping () async -> Void) -> some View {
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
        .buttonStyle(.plain)
    }

    private var freeTextField: some View {
        HStack(spacing: 8) {
            TextField("Bu kelime hakkında bir şey sor...", text: $freeTextQuestion)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Button("Sor") {
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
            Text("Yanıt alınamadı: \(message)")
                .font(.subheadline)
                .foregroundStyle(Theme.danger)
        }
    }
}
