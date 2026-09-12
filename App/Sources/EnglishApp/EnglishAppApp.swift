import SwiftUI
import SwiftData

@main
struct EnglishAppApp: App {
    let modelContainer = AppModelContainer.make()

    init() {
        AppModelContainer.seedSampleContentIfNeeded(in: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
