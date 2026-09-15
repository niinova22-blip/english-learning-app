import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayPlanView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            if appState.isTutorAvailable {
                TutorTabView()
                    .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
            }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(Theme.primary)
    }
}
