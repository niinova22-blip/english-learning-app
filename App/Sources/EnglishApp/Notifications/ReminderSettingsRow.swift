import SwiftUI
import UIKit

/// Profile > REMINDERS: daily reminder toggle and time. Permission is asked
/// only when the learner turns it on.
struct ReminderSettingsRow: View {
    @Environment(AppState.self) private var appState
    @AppStorage(ReminderSettings.enabledKey) private var isOn = false
    @AppStorage(ReminderSettings.hourKey) private var hour = ReminderSettings.defaultHour
    @AppStorage(ReminderSettings.minuteKey) private var minute = 0
    @State private var isDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Daily study reminder", isOn: Binding(get: { isOn }, set: setEnabled))
                .tint(Theme.primary)
            if isOn {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
            }
            if isDenied {
                Text("Notifications are turned off for Lexpath. You can allow them in Settings.")
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.caption).foregroundStyle(Theme.primary)
            }
        }
        .font(.subheadline)
    }

    private func setEnabled(_ newValue: Bool) {
        guard newValue else {
            isOn = false
            appState.bumpDataGeneration()
            return
        }
        Task {
            let allowed = await appState.reminders.enableDailyReminder()
            isOn = allowed
            isDenied = !allowed
            appState.bumpDataGeneration()
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour = parts.hour ?? ReminderSettings.defaultHour
                minute = parts.minute ?? 0
                appState.bumpDataGeneration()
            }
        )
    }
}
