import Foundation

/// When reminders fire. Pure, so the rules are testable without the system.
enum ReminderRules {
    /// The next `days` reminder times at hour:minute wall-clock time. Today is
    /// skipped when its plan is done or the time has already passed.
    static func dailyFireDates(
        now: Date, hour: Int, minute: Int, todayComplete: Bool, calendar: Calendar, days: Int = 7
    ) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        var result: [Date] = []
        var offset = 0
        while result.count < days && offset <= days {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            if offset == 0 && (todayComplete || fire <= now) { continue }
            result.append(fire)
        }
        return result
    }

    /// One day before a free trial turns into a paid subscription.
    static func trialReminderDate(trialEndsAt: Date?, now: Date) -> Date? {
        guard let trialEndsAt else { return nil }
        let reminder = trialEndsAt.addingTimeInterval(-86_400)
        return reminder > now ? reminder : nil
    }
}
