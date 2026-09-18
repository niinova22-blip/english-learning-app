import SwiftUI
import SwiftData
import LearningEngine

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage(DevelopmentPackageAccessProvider.unlockAllKey) private var unlockAll = false
    @State private var stats: LearnerStats?
    @State private var showResetConfirmation = false
    @State private var resetError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profil").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

                section("HEDEFİM") {
                    row("Aktif paket", stats?.packageName ?? "—", tint: Theme.primary)
                    Divider()
                    row("Erişim", stats?.accessLevel == .owned ? "Tam sürüm" : "Önizleme", tint: Theme.accent)
                    Divider()
                    row("Günlük süre", "\(stats?.dailyMinutes ?? LearnerProfile.defaultDailyMinutes) dk")
                }

                section("İSTATİSTİK") {
                    HStack(spacing: 8) {
                        StatTile(value: "\(stats?.streak ?? 0)", label: "gün seri", tint: Theme.accent)
                        StatTile(value: "\(stats?.wordsSeen ?? 0)", label: "kelime")
                        StatTile(value: "\(stats?.completedLessons ?? 0)/\(stats?.totalLessons ?? 0)", label: "ders")
                    }
                }

                if let storageError = AppModelContainer.containerCreationError {
                    section("DEPOLAMA UYARISI") {
                        Text("Yerel depolama açılamadı ya da içerik yüklenemedi. İlerlemen bu oturumdan sonra kaydedilmeyebilir.")
                            .font(.subheadline).foregroundStyle(Theme.danger)
                        Text(storageError).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }

                section("GELİŞTİRİCİ") {
                    Toggle("Tüm paketleri aç", isOn: $unlockAll)
                        .tint(Theme.primary)
                        .onChange(of: unlockAll) { _, _ in appState.bumpDataGeneration() }
                    Divider()
                    Button("Yerel verileri sıfırla", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Theme.danger)
                }

                Text("Sürüm \(appVersion) · Motor \(learningEngineVersion)")
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear(perform: refresh)
        .onChange(of: appState.dataGeneration) { _, _ in refresh() }
        .alert("Tüm yerel veriler silinsin mi?", isPresented: $showResetConfirmation) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive, action: resetAllData)
        }
        .alert(
            "Veriler sıfırlanamadı",
            isPresented: Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } }),
            presenting: resetError
        ) { _ in
            Button("Tamam", role: .cancel) { resetError = nil }
        } message: { Text($0) }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk)
            PaperCard { VStack(alignment: .leading, spacing: 10) { content() } }
        }
    }

    private func row(_ label: String, _ value: String, tint: Color = Theme.secondaryInk) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).foregroundStyle(tint)
        }
        .font(.subheadline)
    }

    private func refresh() {
        stats = try? TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider).stats()
    }

    private func resetAllData() {
        do {
            try context.delete(model: ContentPackage.self)
            try context.delete(model: ReviewLog.self)
            try context.delete(model: UserItemState.self)
            try context.delete(model: LessonProgress.self)
            try context.delete(model: LearnerProfile.self)
            try context.delete(model: LevelTestResult.self)
            try context.save()
            AppModelContainer.seedRealContentIfNeeded(in: context)
            appState.bumpDataGeneration()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
