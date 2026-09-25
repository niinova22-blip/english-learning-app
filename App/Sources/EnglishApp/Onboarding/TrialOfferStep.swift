import SwiftUI

/// Onboarding: "Want a daily reminder?" — asks for notification permission
/// only when the learner says yes.
struct ReminderStep: View {
    let viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState
    @State private var time = Calendar.current.date(bySettingHour: ReminderSettings.defaultHour, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40)).foregroundStyle(Theme.accent)
                .symbolEffect(.pulse)
            Text("Want a daily reminder?").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("People who study at the same time every day keep their streak far longer. We'll skip the reminder on days you've already finished your plan.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
            Spacer(minLength: 0)
            Button("Remind me") {
                Task {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    appState.reminders.settings.hour = parts.hour ?? ReminderSettings.defaultHour
                    appState.reminders.settings.minute = parts.minute ?? 0
                    _ = await appState.reminders.enableDailyReminder()
                    viewModel.advance()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            HStack {
                Button("Back") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Not now") { viewModel.advance() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}

/// Onboarding's last stop for learners who can still start a free trial.
struct TrialOfferStep: View {
    let viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false

    private var daysLeft: Int? {
        guard let date = viewModel.examDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        return days > 0 ? days : nil
    }

    private var headline: String {
        switch (daysLeft, viewModel.selectedGoalIsExam) {
        case (let days?, true): return String(localized: "\(days) days to your exam. Let your coach plan every one of them.")
        case (let days?, false): return String(localized: "\(days) days to your target. Let your coach plan every one of them.")
        default: return String(localized: "Let your coach plan every study day for you.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 40)).foregroundStyle(Theme.accent)
                .symbolEffect(.pulse, options: .repeating)
            Text(headline).font(.appTitle(.title)).foregroundStyle(Theme.ink)
            PaperCard {
                VStack(alignment: .leading, spacing: 12) {
                    highlight("calendar.badge.checkmark", String(localized: "A daily plan that adapts when you fall behind"))
                    highlight("text.book.closed.fill", String(localized: "Ask the tutor about any word or question"))
                    highlight("lock.shield.fill", String(localized: "Runs on your phone, works offline"))
                }
            }
            Text("Free for 7 days. We'll remind you the day before it ends; cancel anytime.")
                .font(.footnote).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button("Try free for 7 days") { showPaywall = true }
                .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { viewModel.finishTrialOffer() }
                .buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if appState.premiumProvider.isPremium { viewModel.finishTrialOffer() }
        }) {
            PaywallView(mode: .premium, store: appState.entitlements)
        }
    }

    private func highlight(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline).foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.primary)
        }
    }
}
