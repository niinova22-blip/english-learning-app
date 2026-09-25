import SwiftUI
import SwiftData
import LearningEngine

enum StudySettings {
    static let dailyMinutesRange = 10...60
    static let dailyMinutesStep = 5

    /// The exam date to show in a picker: the stored date if it is still in
    /// the future (on or after the start of tomorrow), else 30 days from now.
    /// Keeps a picker whose range starts at tomorrow from showing a stored
    /// date the planner would already treat as "exam passed" (today or the past).
    static func suggestedExamDate(stored: Date?, now: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        if let stored, stored >= tomorrow {
            return stored
        }
        return calendar.date(byAdding: .day, value: 30, to: startOfToday)!
    }

    /// Writes the learner's daily minutes (clamped to the onboarding range) and
    /// exam date (start of day, or nil) to their profile.
    static func save(dailyMinutes: Int, examDate: Date?, userID: String, context: ModelContext, calendar: Calendar = .current) throws {
        let userIDValue = userID
        guard let profile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first else { return }
        profile.dailyMinutes = min(max(dailyMinutes, dailyMinutesRange.lowerBound), dailyMinutesRange.upperBound)
        profile.examDate = examDate.map { calendar.startOfDay(for: $0) }
        try context.save()
    }
}

/// "Exam date" for exam goals (YDS, TOEFL), "target date" for the rest.
struct DateWording {
    let isExam: Bool

    var title: String { isExam ? String(localized: "Exam date") : String(localized: "Target date") }
    var toggle: String { isExam ? String(localized: "I have an exam date") : String(localized: "I have a target date") }
    var question: String { isExam ? String(localized: "Do you have an exam date?") : String(localized: "Do you have a target date?") }
}

struct StudySettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var dailyMinutes = LearnerProfile.defaultDailyMinutes
    @State private var hasExamDate = false
    @State private var examDate = Date()
    @State private var saveError: String?
    @State private var isExamGoal = true

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily time") {
                    Stepper("Daily \(dailyMinutes) minutes", value: $dailyMinutes, in: StudySettings.dailyMinutesRange, step: StudySettings.dailyMinutesStep)
                }
                let wording = DateWording(isExam: isExamGoal)
                Section(wording.title) {
                    Toggle(wording.toggle, isOn: $hasExamDate).tint(Theme.primary)
                    if hasExamDate {
                        DatePicker(wording.title, selection: $examDate, in: tomorrow..., displayedComponents: .date)
                    }
                }
                if let saveError {
                    Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .navigationTitle("Study settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let userID = UserIdentity.current
        guard let profile = try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first else { return }
        dailyMinutes = profile.dailyMinutes
        hasExamDate = profile.examDate != nil
        examDate = StudySettings.suggestedExamDate(stored: profile.examDate, now: Date())
        let packageID = profile.activePackageID
        isExamGoal = (try? context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first)?.goal.isExam ?? true
    }

    private func save() {
        do {
            try StudySettings.save(dailyMinutes: dailyMinutes, examDate: hasExamDate ? examDate : nil, userID: UserIdentity.current, context: context)
            appState.bumpDataGeneration()
            dismiss()
        } catch {
            saveError = String(localized: "Could not save settings. Please try again.")
        }
    }
}
