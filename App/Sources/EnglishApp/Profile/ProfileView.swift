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
    @State private var isExamGoal = true
    @State private var coachBriefing: CoachBriefing?
    @State private var showStudySettings = false
    @State private var showGoalSwitcher = false
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
                Text("Profile").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)

                section("MY GOAL") {
                    row("Active package", stats?.packageName ?? "—", tint: Theme.primary)
                    Divider()
                    row("Access", stats?.accessLevel == .owned ? String(localized: "Full version") : String(localized: "Preview"), tint: Theme.accent)
                    Divider()
                    row("Daily time", String(localized: "\(stats?.dailyMinutes ?? LearnerProfile.defaultDailyMinutes) min"))
                    if let examDate {
                        Divider()
                        row(LocalizedStringKey(DateWording(isExam: isExamGoal).title), examDate.formatted(.dateTime.day().month(.wide).year().locale(AppLanguage.current.locale)))
                    }
                    HStack(spacing: 20) {
                        Button("Edit") { showStudySettings = true }
                        Button("Change goal") { showGoalSwitcher = true }.accessibilityIdentifier("profile-change-goal")
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                }

                section("REMINDERS") {
                    ReminderSettingsRow()
                }

                if appState.premiumProvider.isPremium, let coachBriefing {
                    section("COACH") {
                        row("Last 7 days", "\(String(localized: "\(coachBriefing.weekDaysStudied) days")) · \(String(localized: "\(coachBriefing.weekMinutes) min"))")
                        Divider()
                        row("Completed lessons (7 days)", "\(coachBriefing.weekLessonsCompleted)")
                        if let skill = coachBriefing.plan.weakestSkill {
                            Divider()
                            row("Needs the most work", skill.displayName, tint: Theme.accent)
                        }
                        if let finish = coachBriefing.plan.targetFinishDay, coachBriefing.plan.status != .scopeComplete, coachBriefing.plan.status != .finalWeek {
                            Divider()
                            row("Target finish", finish.formatted(.dateTime.day().month(.wide).year().locale(AppLanguage.current.locale)), tint: Theme.primary)
                        }
                    }
                }

                section("MY LEVEL") {
                    if let levelTestSnapshot {
                        row("Estimated level", levelTestSnapshot.level.rawValue, tint: Theme.primary)
                        Divider()
                        row("Vocabulary knowledge", PercentText.format(share: levelTestSnapshot.score))
                        Text("This is only a rough estimate based on this package's word list.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    } else {
                        Text(hasSkippedLevelTest ? "You skipped the level test." : "No level estimate yet.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                    Button(levelTestSnapshot == nil ? "Take the level test now" : "Retake the test") {
                        showLevelTestSheet = true
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                }

                section("PURCHASES") {
                    // Registers observation so the rows update after a purchase.
                    let _ = appState.dataGeneration
                    row("Package", stats?.accessLevel == .owned ? String(localized: "Full version") : String(localized: "Preview"), tint: Theme.accent)
                    if stats?.accessLevel != .owned,
                       let target = PaywallTarget.activePackage(context: context, appState: appState) {
                        Button("Unlock package") { paywall = target }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    row("AI Premium", appState.premiumProvider.isPremium ? String(localized: "Active") : String(localized: "Off"), tint: Theme.accent)
                    if !appState.premiumProvider.isPremium {
                        Button("Upgrade to AI Premium") { paywall = .premium }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    } else {
                        Button("Manage subscription") { Task { await showManageSubscriptions() } }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    Button(isRestoring ? "Restoring..." : "Restore purchases") {
                        Task { await restorePurchases() }
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }

                section("STATS") {
                    HStack(spacing: 8) {
                        StatTile(value: "\(stats?.streak ?? 0)", label: String(localized: "day streak"), tint: Theme.accent)
                        StatTile(value: "\(stats?.wordsSeen ?? 0)", label: String(localized: "words"))
                        StatTile(value: "\(stats?.completedLessons ?? 0)/\(stats?.totalLessons ?? 0)", label: String(localized: "lessons"))
                    }
                }

                if let storageError = AppModelContainer.containerCreationError {
                    section("STORAGE WARNING") {
                        Text("Local storage could not be opened, or content could not be loaded. Your progress may not be saved after this session.")
                            .font(.subheadline).foregroundStyle(Theme.danger)
                        Text(storageError).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }

                section("DEVELOPER") {
                    #if DEBUG
                    Toggle("Unlock all packages", isOn: $unlockAll)
                        .tint(Theme.primary)
                        .onChange(of: unlockAll) { _, _ in appState.bumpDataGeneration() }
                    Divider()
                    #endif
                    Button("Reset local data", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Theme.danger)
                }

                Text("Version \(appVersion) · Engine \(learningEngineVersion)")
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
        .sheet(isPresented: $showGoalSwitcher) { GoalSwitcherSheet() }
        .sheet(isPresented: $showLevelTestSheet) {
            if let packageID = try? TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider).activePackage()?.id {
                LevelTestRetakeSheet(packageID: packageID) { _ in
                    appState.bumpDataGeneration()
                }
            }
        }
        .alert("Delete all local data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive, action: resetAllData)
        }
        .alert(
            "Could not reset data",
            isPresented: Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } }),
            presenting: resetError
        ) { _ in
            Button("OK", role: .cancel) { resetError = nil }
        } message: { Text($0) }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.secondaryInk)
            PaperCard { VStack(alignment: .leading, spacing: 10) { content() } }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String, tint: Color = Theme.secondaryInk) -> some View {
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
            restoreMessage = String(localized: "Your purchases were updated.")
        } catch {
            restoreMessage = String(localized: "Purchases could not be restored. Try again in a bit.")
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
        isExamGoal = (try? TodayPlanCoordinator(context: context, userID: userID, accessProvider: appState.accessProvider).activePackage())?.goal.isExam ?? true
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
