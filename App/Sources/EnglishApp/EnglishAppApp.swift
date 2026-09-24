import SwiftUI
import SwiftData

@main
struct EnglishAppApp: App {
    let modelContainer = AppModelContainer.make()
    @State private var appState: AppState

    init() {
        let context = ModelContext(modelContainer)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let state = AppState()
        state.registerPackageProducts(from: context)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task { await appState.entitlements.start() }
        }
        .modelContainer(modelContainer)
        .environment(appState)
    }
}
