import Foundation
import UserNotifications

/// The slice of UNUserNotificationCenter the scheduler needs, so it can be faked.
protocol NotificationCenterClient: Sendable {
    func isAuthorized() async -> Bool
    /// The learner has never been asked.
    func isUndetermined() async -> Bool
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String])
    func add(identifier: String, title: String, body: String, at date: Date) async throws
}

/// Keeps the app's own local notifications (daily study reminder, trial
/// ending) in line with the current settings and state. Only touches
/// identifiers starting with "lexpath.".
@MainActor
final class ReminderScheduler {
    static let prefix = "lexpath."
    static let trialIdentifier = "lexpath.trial-end"

    let settings: ReminderSettings
    private let client: any NotificationCenterClient
    private let calendar: Calendar
    private let now: () -> Date

    init(
        client: any NotificationCenterClient = SystemNotificationClient(),
        settings: ReminderSettings = ReminderSettings(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.settings = settings
        self.calendar = calendar
        self.now = now
    }

    /// Replaces every app reminder. Asks for permission only when a trial is
    /// running and the learner has never been asked.
    func reschedule(todayComplete: Bool, trialEndsAt: Date?) async {
        let mine = await client.pendingIdentifiers().filter { $0.hasPrefix(Self.prefix) }
        client.remove(identifiers: mine)

        var authorized = await client.isAuthorized()
        if !authorized, trialEndsAt != nil, await client.isUndetermined() {
            authorized = await client.requestAuthorization()
        }
        guard authorized else { return }

        if settings.isEnabled {
            let dates = ReminderRules.dailyFireDates(
                now: now(), hour: settings.hour, minute: settings.minute, todayComplete: todayComplete, calendar: calendar
            )
            for (index, date) in dates.enumerated() {
                try? await client.add(
                    identifier: "\(Self.prefix)daily.\(index)",
                    title: String(localized: "Time for today's English"),
                    body: String(localized: "Your plan is ready. A few minutes keep your streak going."),
                    at: date
                )
            }
        }
        if let date = ReminderRules.trialReminderDate(trialEndsAt: trialEndsAt, now: now()) {
            try? await client.add(
                identifier: Self.trialIdentifier,
                title: String(localized: "Your free trial ends tomorrow"),
                body: String(localized: "Keep your coach and tutor, or cancel anytime in Settings > Apple ID > Subscriptions."),
                at: date
            )
        }
    }

    /// Turns the daily reminder on if notifications are (or become) allowed.
    func enableDailyReminder() async -> Bool {
        var allowed = await client.isAuthorized()
        if !allowed { allowed = await client.requestAuthorization() }
        settings.isEnabled = allowed
        return allowed
    }
}

struct SystemNotificationClient: NotificationCenterClient {
    private var center: UNUserNotificationCenter { .current() }

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    func isUndetermined() async -> Bool {
        await center.notificationSettings().authorizationStatus == .notDetermined
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(identifier: String, title: String, body: String, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
