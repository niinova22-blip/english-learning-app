import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            await appState.loadTutorEngineIfNeeded()
        }
    }
}
