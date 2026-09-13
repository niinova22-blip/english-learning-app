import SwiftUI
import SwiftData
import LearningEngine

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var showResetConfirmation = false
    @State private var resetError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Engine version", value: learningEngineVersion)
                    LabeledContent(
                        "App version",
                        value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"))"
                    )
                }
                if let containerCreationError = AppModelContainer.containerCreationError {
                    Section {
                        Text("Local storage couldn't be opened, so this session is running in a temporary, non-persistent mode. Your progress will not be saved after the app closes.")
                            .foregroundStyle(.red)
                        Text(containerCreationError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Storage warning")
                    }
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
            .alert(
                "Couldn't reset data",
                isPresented: Binding(
                    get: { resetError != nil },
                    set: { isPresented in if !isPresented { resetError = nil } }
                ),
                presenting: resetError
            ) { _ in
                Button("OK", role: .cancel) { resetError = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private func resetAllData() {
        do {
            try context.delete(model: ContentPackage.self)
            try context.delete(model: ReviewLog.self)
            try context.delete(model: UserItemState.self)
            try context.save()
            AppModelContainer.seedRealContentIfNeeded(in: context)
            appState.bumpDataGeneration()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
