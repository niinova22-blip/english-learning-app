import SwiftUI
import SwiftData
import LearningEngine

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [LearnerProfile]

    init() {
        let userID = UserIdentity.current
        _profiles = Query(filter: #Predicate<LearnerProfile> { $0.userID == userID })
    }

    private var hasCompletedOnboarding: Bool {
        profiles.first?.onboardingCompletedAt != nil
    }

    var body: some View {
        if hasCompletedOnboarding {
            TabView {
                TodayPlanView()
                    .tabItem { Label("Bugün", systemImage: "sun.max") }
                CoursePathView()
                    .tabItem { Label("Ders Yolu", systemImage: "map") }
                if appState.isTutorAvailable {
                    TutorTabView()
                        .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
                }
                ProfileView()
                    .tabItem { Label("Profil", systemImage: "person.crop.circle") }
            }
            .tint(Theme.primary)
        } else {
            OnboardingFlowView()
        }
    }
}
