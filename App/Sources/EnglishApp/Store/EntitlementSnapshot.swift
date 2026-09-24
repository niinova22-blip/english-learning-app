import Foundation

/// One installed package that can be bought.
struct PackageProduct: Equatable, Sendable {
    let packageID: String
    let productID: String
    let name: String
}

/// Lock-protected mirror of the entitlement state. `PackageAccessProvider` is
/// synchronous and not main-actor, so providers read this instead of the
/// observable, main-actor `EntitlementStore`.
final class EntitlementSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var activeIDs: Set<String>
    private var packageProducts: [String: PackageProduct] = [:]

    init(activeProductIDs: Set<String> = []) {
        self.activeIDs = activeProductIDs
    }

    var activeProductIDs: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return activeIDs
    }

    func replaceActiveProductIDs(_ ids: Set<String>) {
        lock.lock()
        activeIDs = ids
        lock.unlock()
    }

    /// Replaces the package → product table (called once after seeding).
    func registerPackages(_ products: [PackageProduct]) {
        lock.lock()
        packageProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.packageID, $0) })
        lock.unlock()
    }

    func packageProduct(forPackageID id: String) -> PackageProduct? {
        lock.lock()
        defer { lock.unlock() }
        return packageProducts[id]
    }
}
