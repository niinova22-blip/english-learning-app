import Foundation
import Observation

enum PaywallMode: Equatable, Identifiable {
    case package(productID: String, packageName: String)
    case premium

    var id: String {
        switch self {
        case .package(let productID, _): return "package-\(productID)"
        case .premium: return "premium"
        }
    }

    /// Product ids in display order.
    var productIDs: [String] {
        switch self {
        case .package(let productID, _): return [productID]
        case .premium: return PremiumProducts.all
        }
    }
}

@MainActor
@Observable
final class PaywallViewModel {
    enum State: Equatable {
        case loadingProducts
        case ready
        case loadFailed
        case purchasing
        /// Ask to Buy: waiting for a parent's approval.
        case pending
        case succeeded
        case failed(String)
    }

    let mode: PaywallMode
    private(set) var state: State = .loadingProducts
    private(set) var products: [StoreProduct] = []
    /// A non-error message shown under the buttons (e.g. nothing to restore).
    private(set) var notice: String?
    var selectedProductID: String?

    @ObservationIgnored private let store: EntitlementStore

    init(mode: PaywallMode, store: EntitlementStore) {
        self.mode = mode
        self.store = store
    }

    var title: String {
        switch mode {
        case .package(_, let packageName): return packageName
        case .premium: return "AI Premium"
        }
    }

    var selectedProduct: StoreProduct? {
        products.first { $0.id == selectedProductID }
    }

    var isAlreadyOwned: Bool {
        mode.productIDs.contains { store.owns($0) }
    }

    func load() async {
        state = .loadingProducts
        notice = nil
        do {
            let fetched = try await store.products(for: mode.productIDs)
            products = mode.productIDs.compactMap { id in fetched.first { $0.id == id } }
            guard !products.isEmpty else {
                state = .loadFailed
                return
            }
            if selectedProduct == nil {
                let preferred = mode == .premium ? PremiumProducts.yearly : mode.productIDs[0]
                selectedProductID = products.contains { $0.id == preferred } ? preferred : products[0].id
            }
            state = .ready
        } catch {
            state = .loadFailed
        }
    }

    func purchase() async {
        guard state == .ready || isFailed, let productID = selectedProductID else { return }
        state = .purchasing
        notice = nil
        do {
            switch try await store.purchase(productID: productID) {
            case .purchased: state = .succeeded
            case .pending: state = .pending
            case .cancelled: state = .ready
            }
        } catch {
            state = .failed(String(localized: "The purchase could not be completed. Try again in a bit."))
        }
    }

    func restore() async {
        guard state == .ready || isFailed else { return }
        state = .purchasing
        notice = nil
        do {
            try await store.restore()
            if isAlreadyOwned {
                state = .succeeded
            } else {
                notice = String(localized: "No purchase to restore was found on this account.")
                state = .ready
            }
        } catch {
            state = .failed(String(localized: "Purchases could not be restored. Try again in a bit."))
        }
    }

    func dismissError() {
        if isFailed { state = .ready }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}
