import SwiftUI

/// Bridges "the shared tutor engine hasn't been loaded yet" to
/// `TutorChatView`, which always requires a real, already-loaded
/// engine (mirroring `TutorSheetView`'s existing pattern in the
/// card-scoped feature). Shown only when `AppState.isTutorAvailable`
/// is true (see `RootTabView`) — this view's own states are about
/// "available but not yet loaded" / "available but failed to load",
/// never about total unavailability, which is handled by hiding the
/// tab entirely one level up. Without AI Premium the tab stays visible
/// but shows a locked state that opens the premium paywall.
struct TutorTabView: View {
    @Environment(AppState.self) private var appState
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var showPaywall = false

    var body: some View {
        Group {
            if appState.tutorAccess == .needsPremium {
                lockedState
            } else if let engine = appState.tutorEngine {
                TutorChatView(engine: engine)
            } else if isLoading {
                ProgressView("Loading the tutor...")
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                VStack(spacing: 12) {
                    if loadFailed {
                        Text("Could not load the tutor.")
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Button("Load the tutor") { Task { await load() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 240)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .task(id: appState.tutorAccess) { await load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(mode: .premium, store: appState.entitlements)
        }
    }

    private var lockedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("The tutor unlocks with AI Premium")
                .font(.serifTitle(.title3)).foregroundStyle(Theme.ink)
            Text("Get clear answers in your language and chat with the tutor.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            Button("Upgrade to AI Premium") { showPaywall = true }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
        }
        .padding(24)
    }

    private func load() async {
        guard appState.tutorAccess == .allowed else { return }
        guard appState.tutorEngine == nil, !isLoading else { return }
        isLoading = true
        await appState.loadTutorEngineIfNeeded()
        isLoading = false
        loadFailed = appState.tutorEngine == nil
    }
}
