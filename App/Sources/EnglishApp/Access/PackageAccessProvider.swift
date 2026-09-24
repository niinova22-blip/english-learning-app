import Foundation
import LearningEngine

/// Entitlement boundary. Screens and planners only ever talk to this
/// protocol; the StoreKit-backed implementation lives in
/// `Store/StoreAccessProviders.swift`.
protocol PackageAccessProvider {
    func accessLevel(forPackageID id: String) -> PackageAccessLevel
}
