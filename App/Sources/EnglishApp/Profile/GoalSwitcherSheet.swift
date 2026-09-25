import SwiftUI
import SwiftData
import Observation
import LearningEngine

/// Lists the installed packages and makes the chosen one the active goal.
/// Progress is keyed by lesson and item IDs, so every package keeps its own.
@MainActor
@Observable
final class GoalSwitcherViewModel {
    private(set) var options: [PackageOption] = []
    private(set) var ownedPackageIDs: Set<String> = []
    private(set) var activePackageID: String?

    private let context: ModelContext
    private let userID: String

    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider, language: AppLanguage = .current) {
        self.context = context
        self.userID = userID
        let all = (try? context.fetch(FetchDescriptor<ContentPackage>())) ?? []
        let owned = Set(all.filter { accessProvider.accessLevel(forPackageID: $0.id) == .owned }.map(\.id))
        let active = try? profile()?.activePackageID
        let userIDValue = userID
        let startedLessons = Set(((try? context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.userID == userIDValue }))) ?? []).map(\.lessonID))
        let started = Set(all.filter { package in
            package.units.contains { unit in unit.lessons.contains { startedLessons.contains($0.id) } }
        }.map(\.id))
        // A package with progress counts like an owned one: switching away must not strand it.
        let packages = PackageOrdering.visible(all, language: language, activeID: active, ownedIDs: owned.union(started))
        options = PackageOrdering.sorted(packages, for: language).map { PackageOption($0, language: language) }
        ownedPackageIDs = owned
        activePackageID = active
    }

    /// Makes `packageID` the active goal. Returns true when the goal changed.
    @discardableResult
    func select(_ packageID: String) throws -> Bool {
        guard packageID != activePackageID, options.contains(where: { $0.id == packageID }),
              let profile = try profile() else { return false }
        profile.activePackageID = packageID
        try context.save()
        activePackageID = packageID
        return true
    }

    private func profile() throws -> LearnerProfile? {
        let userIDValue = userID
        return try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first
    }
}

struct GoalSwitcherSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: GoalSwitcherViewModel?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your study plan, course and coach follow the goal you choose. Progress in each package is kept.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    if let viewModel {
                        ForEach(viewModel.options) { option in
                            PackageOptionRow(
                                option: option,
                                isSelected: viewModel.activePackageID == option.id,
                                accessBadge: viewModel.ownedPackageIDs.contains(option.id) ? String(localized: "Full version") : String(localized: "Preview")
                            ) {
                                choose(option.id, in: viewModel)
                            }
                        }
                    }
                    if let saveError {
                        Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
                    }
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Change goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.accessibilityIdentifier("goal-switcher-close")
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = GoalSwitcherViewModel(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
            }
        }
    }

    private func choose(_ packageID: String, in viewModel: GoalSwitcherViewModel) {
        do {
            if try viewModel.select(packageID) { appState.bumpDataGeneration() }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
