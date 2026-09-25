import SwiftUI
import SwiftData

struct LockedLesson: Identifiable, Equatable {
    let id = UUID()
    let title: String
}

@MainActor
enum PaywallTarget {
    /// The paywall for the learner's active package, or nil when that package
    /// has no store product (it then stays a preview with no buy button).
    static func activePackage(context: ModelContext, appState: AppState) -> PaywallMode? {
        let coordinator = TodayPlanCoordinator(
            context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider
        )
        guard let package = try? coordinator.activePackage(),
              let product = appState.entitlements.snapshot.packageProduct(forPackageID: package.id)
        else { return nil }
        return .package(productID: product.productID, packageName: product.name)
    }
}

struct LockedLessonSheet: View {
    let lessonTitle: String
    let canPurchase: Bool
    let onUnlock: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("This lesson is in the full version of the package")
                .font(.appTitle(.title3)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(lessonTitle).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            if canPurchase {
                Button("Unlock package", action: onUnlock).buttonStyle(PrimaryButtonStyle())
            }
            Button("Close", action: onClose).foregroundStyle(Theme.secondaryInk)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// Presents the locked-lesson sheet and, on "Unlock package", the package paywall.
/// The paywall opens from the first sheet's `onDismiss` so the two sheets never
/// change in the same frame.
struct LockedLessonPresenter: ViewModifier {
    @Binding var lockedLesson: LockedLesson?
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var paywall: PaywallMode?
    @State private var pendingPaywall: PaywallMode?

    func body(content: Content) -> some View {
        content
            .sheet(item: $lockedLesson, onDismiss: {
                paywall = pendingPaywall
                pendingPaywall = nil
            }) { locked in
                let target = PaywallTarget.activePackage(context: context, appState: appState)
                LockedLessonSheet(
                    lessonTitle: locked.title,
                    canPurchase: target != nil,
                    onUnlock: {
                        pendingPaywall = target
                        lockedLesson = nil
                    },
                    onClose: { lockedLesson = nil }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $paywall) { mode in
                PaywallView(mode: mode, store: appState.entitlements)
            }
    }
}

extension View {
    func lockedLessonPrompts(_ lockedLesson: Binding<LockedLesson?>) -> some View {
        modifier(LockedLessonPresenter(lockedLesson: lockedLesson))
    }
}
