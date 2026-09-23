import SwiftUI
import SwiftData
import StoreKit
import UIKit
import LearningEngine

/// Plain-value copy of the stored level-test result, so the view never holds a
/// live model object that a data reset could delete out from under it.
struct LevelTestSnapshot: Equatable {
    let level: CEFRLevel
    let score: Double
}

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    #if DEBUG
    @AppStorage(DeveloperOverride.unlockAllKey) private var unlockAll = false
    #endif
    @State private var stats: LearnerStats?
    @State private var levelTestSnapshot: LevelTestSnapshot?
    @State private var examDate: Date?
    @State private var coachBriefing: CoachBriefing?
    @State private var showStudySettings = false
    @State private var hasSkippedLevelTest = false
    @State private var showLevelTestSheet = false
    @State private var showResetConfirmation = false
    @State private var resetError: String?
    @State private var paywall: PaywallMode?
    @State private var restoreMessage: String?
    @State private var isRestoring = false

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
                    if let examDate {
                        Divider()
                        row("Sınav tarihi", examDate.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))
                    }
                    Button("Düzenle") { showStudySettings = true }
                        .buttonStyle(.plain).foregroundStyle(Theme.primary)
                }

                if appState.premiumProvider.isPremium, let coachBriefing {
                    section("KOÇ") {
                        row("Bu hafta", "\(coachBriefing.weekDaysStudied) gün · \(coachBriefing.weekMinutes) dk")
                        Divider()
                        row("Biten ders (7 gün)", "\(coachBriefing.weekLessonsCompleted)")
                        if let skill = coachBriefing.plan.weakestSkill {
                            Divider()
                            row("En çok ihtiyaç", skill.displayName, tint: Theme.accent)
                        }
                        if let finish = coachBriefing.plan.targetFinishDay, coachBriefing.plan.status != .scopeComplete {
                            Divider()
                            row("Hedef bitiş", finish.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))), tint: Theme.primary)
                        }
                    }
                }

                section("SEVİYEM") {
                    if let levelTestSnapshot {
                        row("Tahmini seviye", levelTestSnapshot.level.rawValue, tint: Theme.primary)
                        Divider()
                        row("Kelime bilgisi", "%\(Int((levelTestSnapshot.score * 100).rounded()))")
                        Text("Bu, sadece bu paketin kelime listesine göre kaba bir tahmindir.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    } else {
                        Text(hasSkippedLevelTest ? "Seviye testini atladın." : "Henüz bir seviye tahmini yok.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                    Button(levelTestSnapshot == nil ? "Seviye testini şimdi yap" : "Yeniden test et") {
                        showLevelTestSheet = true
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                }

                section("SATIN ALIMLAR") {
                    // Registers observation so the rows update after a purchase.
                    let _ = appState.dataGeneration
                    row("Paket", stats?.accessLevel == .owned ? "Tam sürüm" : "Önizleme", tint: Theme.accent)
                    if stats?.accessLevel != .owned,
                       let target = PaywallTarget.activePackage(context: context, appState: appState) {
                        Button("Paketi aç") { paywall = target }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    row("AI Premium", appState.premiumProvider.isPremium ? "Aktif" : "Kapalı", tint: Theme.accent)
                    if !appState.premiumProvider.isPremium {
                        Button("AI Premium'a geç") { paywall = .premium }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    } else {
                        Button("Aboneliği yönet") { Task { await showManageSubscriptions() } }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    Button(isRestoring ? "Geri yükleniyor..." : "Satın alımları geri yükle") {
                        Task { await restorePurchases() }
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
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
                    #if DEBUG
                    Toggle("Tüm paketleri aç", isOn: $unlockAll)
                        .tint(Theme.primary)
                        .onChange(of: unlockAll) { _, _ in appState.bumpDataGeneration() }
                    Divider()
                    #endif
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
        .sheet(item: $paywall) { mode in
            PaywallView(mode: mode, store: appState.entitlements)
        }
        .sheet(isPresented: $showStudySettings) { StudySettingsSheet() }
        .sheet(isPresented: $showLevelTestSheet) {
            if let packageID = try? TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider).activePackage()?.id {
                LevelTestRetakeSheet(packageID: packageID) { _ in
                    appState.bumpDataGeneration()
                }
            }
        }
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

    private func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil
        do {
            try await appState.entitlements.restore()
            restoreMessage = "Satın alımların güncellendi."
        } catch {
            restoreMessage = "Satın alımlar geri yüklenemedi. Bir süre sonra tekrar dene."
        }
        isRestoring = false
    }

    private func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    private func refresh() {
        let userID = UserIdentity.current
        stats = try? TodayPlanCoordinator(context: context, userID: userID, accessProvider: appState.accessProvider).stats()
        coachBriefing = try? TodayPlanCoordinator(context: context, userID: userID, accessProvider: appState.accessProvider).buildCoachBriefing()
        let result = try? context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userID })).first
        levelTestSnapshot = result.map { LevelTestSnapshot(level: $0.cefrLevel, score: $0.vocabularyScore) }
        let profile = try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first
        hasSkippedLevelTest = profile?.hasSkippedLevelTest ?? false
        examDate = profile?.examDate
    }

    private func resetAllData() {
        do {
            try context.delete(model: ContentPackage.self)
            try context.delete(model: ReviewLog.self)
            try context.delete(model: UserItemState.self)
            try context.delete(model: LessonProgress.self)
            try context.delete(model: QuestionAttempt.self)
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
