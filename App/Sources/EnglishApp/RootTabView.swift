import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            if appState.isTutorAvailable {
                TutorTabView()
                    .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
            }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
