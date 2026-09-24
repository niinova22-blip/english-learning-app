import SwiftUI
import SwiftData
import LearningEngine

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [LearnerProfile]
    @Query private var packages: [ContentPackage]

    init() {
        let userID = UserIdentity.current
        _profiles = Query(filter: #Predicate<LearnerProfile> { $0.userID == userID })
    }

    private var hasCompletedOnboarding: Bool {
        profiles.first?.onboardingCompletedAt != nil
    }

    /// Onboarding needs a package to pick; with none installed, fall through to
    /// the tabs so Profile (storage warning, reset) stays reachable.
    static func shouldShowOnboarding(hasCompletedOnboarding: Bool, hasInstalledPackage: Bool) -> Bool {
        !hasCompletedOnboarding && hasInstalledPackage
    }

    var body: some View {
        if !Self.shouldShowOnboarding(hasCompletedOnboarding: hasCompletedOnboarding, hasInstalledPackage: !packages.isEmpty) {
            TabView {
                TodayPlanView()
                    .tabItem { Label("Today", systemImage: "sun.max") }
                CoursePathView()
                    .tabItem { Label("Course", systemImage: "map") }
                if appState.isTutorAvailable {
                    TutorTabView()
                        .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
                }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            .tint(Theme.primary)
        } else {
            OnboardingFlowView()
        }
    }
}
