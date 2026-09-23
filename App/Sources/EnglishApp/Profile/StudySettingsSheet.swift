import SwiftUI
import SwiftData
import LearningEngine

enum StudySettings {
    static let dailyMinutesRange = 10...60
    static let dailyMinutesStep = 5

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

struct StudySettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var dailyMinutes = LearnerProfile.defaultDailyMinutes
    @State private var hasExamDate = false
    @State private var examDate = Date()
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Günlük süre") {
                    Stepper("Günlük \(dailyMinutes) dakika", value: $dailyMinutes, in: StudySettings.dailyMinutesRange, step: StudySettings.dailyMinutesStep)
                }
                Section("Sınav tarihi") {
                    Toggle("Bir sınav tarihim var", isOn: $hasExamDate).tint(Theme.primary)
                    if hasExamDate {
                        DatePicker("Sınav tarihi", selection: $examDate, in: Date()..., displayedComponents: .date)
                    }
                }
                if let saveError {
                    Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .navigationTitle("Çalışma ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: save) }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let userID = UserIdentity.current
        guard let profile = try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first else { return }
        dailyMinutes = profile.dailyMinutes
        hasExamDate = profile.examDate != nil
        examDate = profile.examDate ?? Date()
    }

    private func save() {
        do {
            try StudySettings.save(dailyMinutes: dailyMinutes, examDate: hasExamDate ? examDate : nil, userID: UserIdentity.current, context: context)
            appState.bumpDataGeneration()
            dismiss()
        } catch {
            saveError = "Ayarlar kaydedilemedi. Lütfen tekrar dene."
        }
    }
}
