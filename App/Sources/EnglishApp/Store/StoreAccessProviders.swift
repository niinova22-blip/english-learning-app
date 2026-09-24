import Foundation
import LearningEngine

/// Whether the AI features are unlocked. Independent of package ownership.
protocol PremiumAccessProvider {
    var isPremium: Bool { get }
}

/// `.owned` when the package's store product is active, `.preview` otherwise.
/// A package with no registered store product is always a preview.
struct StoreKitPackageAccessProvider: PackageAccessProvider {
    let snapshot: EntitlementSnapshot

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        guard let product = snapshot.packageProduct(forPackageID: id) else { return .preview }
        return snapshot.activeProductIDs.contains(product.productID) ? .owned : .preview
    }
}

struct SnapshotPremiumAccessProvider: PremiumAccessProvider {
    let snapshot: EntitlementSnapshot

    var isPremium: Bool {
        !snapshot.activeProductIDs.isDisjoint(with: PremiumProducts.all)
    }
}

#if DEBUG
/// Developer shortcut: never compiled into Release, so it cannot ship.
enum DeveloperOverride {
    static let unlockAllKey = "dev.unlockAllPackages"
}

struct DeveloperOverridePackageAccessProvider: PackageAccessProvider {
    let base: any PackageAccessProvider
    let defaults: UserDefaults

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        defaults.bool(forKey: DeveloperOverride.unlockAllKey) ? .owned : base.accessLevel(forPackageID: id)
    }
}

struct DeveloperOverridePremiumAccessProvider: PremiumAccessProvider {
    let base: any PremiumAccessProvider
    let defaults: UserDefaults

    var isPremium: Bool {
        defaults.bool(forKey: DeveloperOverride.unlockAllKey) || base.isPremium
    }
}
#endif
