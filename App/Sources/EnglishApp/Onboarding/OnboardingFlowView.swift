import SwiftUI
import SwiftData
import LearningEngine

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    VStack(spacing: 0) {
                        ProgressBar(progress: viewModel.progressFraction)
                            .padding(.horizontal).padding(.top, 12)
                        ScrollView { stepContent(viewModel).padding() }
                        if let loadError = viewModel.loadError {
                            Text("Kaydedilemedi: \(loadError)")
                                .font(.footnote).foregroundStyle(Theme.danger)
                                .padding(.horizontal).padding(.bottom, 8)
                        }
                    }
                    .background(Theme.paper.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(context: context, userID: UserIdentity.current)
            }
        }
        .onChange(of: viewModel?.isOnboardingComplete) { _, isComplete in
            if isComplete == true { appState.bumpDataGeneration() }
        }
    }

    @ViewBuilder
    private func stepContent(_ viewModel: OnboardingViewModel) -> some View {
        switch viewModel.step {
        case .goalSelection:
            GoalSelectionStep(viewModel: viewModel)
        case .examDate:
            ExamDateStep(viewModel: viewModel)
        case .dailyDuration:
            DailyDurationStep(viewModel: viewModel)
        case .levelTestIntro:
            LevelTestIntroStep(viewModel: viewModel)
        case .levelTest:
            if let question = viewModel.levelTestViewModel?.currentQuestion {
                LevelTestQuestionView(question: question, questionNumber: viewModel.levelTestViewModel?.questionNumber ?? 1) { index in
                    viewModel.answerLevelTestQuestion(selectedIndex: index)
                }
            }
        case .levelTestResult:
            if let outcome = viewModel.levelTestViewModel?.outcome {
                LevelTestResultView(outcome: outcome, buttonTitle: "Bugüne başla") {
                    viewModel.finishFromResult()
                }
            }
        case .done:
            EmptyView()
        }
    }
}

private struct GoalSelectionStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hedefini seç").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("Çalışma planın seçtiğin hedefe göre kurulur.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            if viewModel.hasNoPackages {
                Text("Henüz yüklü bir ders paketi yok. Uygulamayı yeniden başlatmayı dene; olmazsa Profil sekmesinden yerel verileri sıfırlayabilirsin.")
                    .font(.subheadline).foregroundStyle(Theme.danger)
            }
            ForEach(viewModel.goalOptions) { option in
                Button {
                    viewModel.selectedPackageID = option.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.name).font(.headline).foregroundStyle(Theme.ink)
                            Text("\(option.levelLower)–\(option.levelUpper)").font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                        Spacer()
                        if viewModel.selectedPackageID == option.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                        }
                    }
                    .padding()
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(viewModel.selectedPackageID == option.id ? Theme.primary : Theme.border, lineWidth: viewModel.selectedPackageID == option.id ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button("Devam et") { viewModel.advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.selectedPackageID == nil)
        }
    }
}

private struct ExamDateStep: View {
    let viewModel: OnboardingViewModel
    @State private var hasExamDate = true
    @State private var date = Date()

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sınav tarihin var mı?").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Toggle("Bir sınav tarihim var", isOn: $hasExamDate).tint(Theme.primary)
            if hasExamDate {
                DatePicker("Sınav tarihi", selection: $date, in: tomorrow..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Geri") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Devam et") {
                    viewModel.examDate = hasExamDate ? date : nil
                    viewModel.advance()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
            }
        }
        .onAppear {
            hasExamDate = viewModel.examDate != nil
            date = StudySettings.suggestedExamDate(stored: viewModel.examDate, now: Date())
        }
    }
}

private struct DailyDurationStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Günde ne kadar çalışacaksın?").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Stepper("Günlük \(viewModel.dailyMinutes) dakika", value: Binding(
                get: { viewModel.dailyMinutes },
                set: { viewModel.dailyMinutes = $0 }
            ), in: 10...60, step: 5)
            Spacer(minLength: 0)
            HStack {
                Button("Geri") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Devam et") { viewModel.advance() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 200)
            }
        }
    }
}

private struct LevelTestIntroStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kısa bir seviye kontrolü").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("5-8 dakikada, bildiğin kelimelere göre yaklaşık seviyeni tahmin ederiz. İstersen atlayabilirsin.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button("Başla") { viewModel.startLevelTest() }.buttonStyle(PrimaryButtonStyle())
            Button("Atla") { viewModel.skipLevelTest() }
                .buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
    }
}
