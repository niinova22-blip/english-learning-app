import Foundation
import LearningEngine

/// Entitlement boundary. Slice 8 replaces the implementation with StoreKit;
/// screens only ever talk to this protocol.
protocol PackageAccessProvider {
    func accessLevel(forPackageID id: String) -> PackageAccessLevel
}

/// Development stand-in: every package is a preview unless the developer
/// toggle in Profile unlocks all of them.
struct DevelopmentPackageAccessProvider: PackageAccessProvider {
    static let unlockAllKey = "dev.unlockAllPackages"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        defaults.bool(forKey: Self.unlockAllKey) ? .owned : .preview
    }
}
