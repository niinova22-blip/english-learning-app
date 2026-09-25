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
                            Text("Couldn't save: \(loadError)")
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
                let packages = (try? context.fetch(FetchDescriptor<ContentPackage>())) ?? []
                let owned = Set(packages.filter { appState.accessProvider.accessLevel(forPackageID: $0.id) == .owned }.map(\.id))
                viewModel = OnboardingViewModel(context: context, userID: UserIdentity.current, ownedPackageIDs: owned)
            }
        }
        .task(id: viewModel == nil) { await checkTrialEligibility() }
        .onChange(of: viewModel?.isOnboardingComplete) { _, isComplete in
            if isComplete == true { appState.bumpDataGeneration() }
        }
    }

    /// The offer step appears only for learners who can still start a trial.
    private func checkTrialEligibility() async {
        guard let viewModel, !appState.premiumProvider.isPremium else { return }
        await appState.loadTrialOffer()
        viewModel.trialDays = appState.trialOfferDays
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
        case .reminder:
            ReminderStep(viewModel: viewModel)
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
                LevelTestResultView(outcome: outcome, buttonTitle: String(localized: "Start today")) {
                    viewModel.finishFromResult()
                }
            }
        case .trialOffer:
            TrialOfferStep(viewModel: viewModel)
        case .done:
            EmptyView()
        }
    }
}

private struct GoalSelectionStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your goal").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("Your study plan is built around the goal you choose.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
            if viewModel.hasNoPackages {
                Text("No lesson package is loaded yet. Try restarting the app; if that doesn't help, you can reset local data from the Profile tab.")
                    .font(.subheadline).foregroundStyle(Theme.danger)
            }
            ForEach(viewModel.goalOptions) { option in
                PackageOptionRow(option: option, isSelected: viewModel.selectedPackageID == option.id) {
                    viewModel.selectedPackageID = option.id
                }
            }
            Spacer(minLength: 0)
            Button("Continue") { viewModel.advance() }
                .accessibilityIdentifier("onboarding-continue")
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
            let wording = DateWording(isExam: viewModel.selectedGoalIsExam)
            Text(wording.question).font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Toggle(wording.toggle, isOn: $hasExamDate).tint(Theme.primary)
            if hasExamDate {
                DatePicker(wording.title, selection: $date, in: tomorrow..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Back") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Continue") {
                    viewModel.examDate = hasExamDate ? date : nil
                    viewModel.advance()
                }
                .accessibilityIdentifier("onboarding-continue")
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
            Text("How much will you study each day?").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Stepper("Daily \(viewModel.dailyMinutes) min", value: Binding(
                get: { viewModel.dailyMinutes },
                set: { viewModel.dailyMinutes = $0 }
            ), in: 10...60, step: 5)
            Spacer(minLength: 0)
            HStack {
                Button("Back") { viewModel.goBack() }.buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Continue") { viewModel.advance() }.accessibilityIdentifier("onboarding-continue").buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 200)
            }
        }
    }
}

private struct LevelTestIntroStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A quick level check").font(.appTitle(.largeTitle)).foregroundStyle(Theme.ink)
            Text("In 5-8 minutes, we'll estimate your level based on the words you know. You can skip it if you'd like.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 0)
            Button("Start") { viewModel.startLevelTest() }.buttonStyle(PrimaryButtonStyle())
            Button("Skip") { viewModel.skipLevelTest() }
                .accessibilityIdentifier("onboarding-skip-test")
                .buttonStyle(.plain).foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity)
        }
    }
}
