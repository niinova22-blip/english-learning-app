import Foundation

/// The single decision every tutor entry point makes.
enum TutorAccess: Equatable {
    /// No tutor on this device/build: entry points stay hidden.
    case unavailable
    /// The tutor exists but the learner is not premium: entry points stay
    /// visible and open the premium paywall.
    case needsPremium
    case allowed

    static func resolve(isTutorAvailable: Bool, isPremium: Bool) -> TutorAccess {
        guard isTutorAvailable else { return .unavailable }
        return isPremium ? .allowed : .needsPremium
    }
}

extension AppState {
    var tutorAccess: TutorAccess {
        // Reading `dataGeneration` registers observation, so views that read
        // this re-render when an entitlement change bumps it.
        _ = dataGeneration
        return TutorAccess.resolve(isTutorAvailable: isTutorAvailable, isPremium: premiumProvider.isPremium)
    }
}
