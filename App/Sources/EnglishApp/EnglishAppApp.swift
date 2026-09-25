import SwiftUI
import SwiftData

@main
struct EnglishAppApp: App {
    let modelContainer = AppModelContainer.make()
    @State private var appState: AppState

    init() {
        ScreenshotMode.resetSettings()
        let context = ModelContext(modelContainer)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        #if DEBUG
        let state = ScreenshotMode.isOn ? AppState(service: DemoPurchaseService()) : AppState()
        #else
        let state = AppState()
        #endif
        state.registerPackageProducts(from: context)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task { await appState.entitlements.start() }
                .preferredColorScheme(ScreenshotMode.forcesDark ? .dark : nil)
        }
        .modelContainer(modelContainer)
        .environment(appState)
    }
}
