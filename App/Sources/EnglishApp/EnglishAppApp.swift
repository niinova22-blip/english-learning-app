import SwiftUI
import SwiftData

@main
struct EnglishAppApp: App {
    let modelContainer = AppModelContainer.make()
    @State private var appState = AppState()

    init() {
        let context = ModelContext(modelContainer)
        AppModelContainer.seedSampleContentIfNeeded(in: context)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
        .environment(appState)
    }
}
