import SwiftUI
import SwiftData
import LearningEngine

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Engine version", value: learningEngineVersion)
                }
                Section {
                    Button("Reset local data", role: .destructive) {
                        showResetConfirmation = true
                    }
                } footer: {
                    Text("Deletes all locally stored progress. For development testing only.")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset all local data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive, action: resetAllData)
            }
        }
    }

    private func resetAllData() {
        try? context.delete(model: ContentPackage.self)
        try? context.delete(model: ReviewLog.self)
        try? context.delete(model: UserItemState.self)
        try? context.save()
    }
}
