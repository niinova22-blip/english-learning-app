import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class CoursePathViewModelTests: XCTestCase {
    let userID = "u"

    func makeContext(seed: Bool = true) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if seed { _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context) }
        return context
    }

    @MainActor
    func test_load_groupsLessonsByUnitInOrder() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        XCTAssertEqual(vm.sections.map(\.unitID), ["unit-0", "unit-1"])
        XCTAssertEqual(vm.sections[0].tasks.count, 2)
        guard case .lesson(let id, _, _, _, _) = vm.sections[0].tasks[0] else {
            return XCTFail("expected a lesson task")
        }
        XCTAssertEqual(id, "lesson-u0-l0")
    }

    @MainActor
    func test_load_previewAccess_locksSecondUnit() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .preview))
        vm.load()
        for task in vm.sections[0].tasks {
            if case .locked = task { return XCTFail("first unit should be accessible under preview") }
        }
        for task in vm.sections[1].tasks {
            guard case .locked = task else { return XCTFail("second unit should be locked under preview") }
        }
    }

    @MainActor
    func test_load_ownedAccess_nothingLocked() throws {
        let context = try makeContext()
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        for section in vm.sections {
            for task in section.tasks {
                if case .locked = task { XCTFail("nothing should be locked under owned access") }
            }
        }
    }

    @MainActor
    func test_load_completedLesson_marksTaskDone() throws {
        let context = try makeContext()
        _ = try TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned)).ensureProfile()
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: Date())
        progress.completedAt = Date()
        context.insert(progress)
        try context.save()

        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        guard case .lesson(_, _, _, _, let isDone) = vm.sections[0].tasks[0] else {
            return XCTFail("expected a lesson task")
        }
        XCTAssertTrue(isDone)
    }

    @MainActor
    func makeRealContentContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    @MainActor
    func test_dersYolu_showsThePracticeLessonsInTheFreePreviewUnit_andRoutesThemToPractice() throws {
        let context = try makeRealContentContext()
        let viewModel = CoursePathViewModel(
            context: context, userID: "u", accessProvider: FixedAccessProvider(level: .preview)
        )
        viewModel.load()

        let firstSection = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(firstSection.tasks.count, 10)
        let actions = firstSection.tasks.map(PlanTaskAction.action(for:))
        XCTAssertEqual(actions.prefix(3).filter { if case .startLesson = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(
            actions.dropFirst(3).filter { if case .startPractice = $0 { return true } else { return false } }.count, 7,
            "all seven practice lessons must be openable, not locked or 'coming soon'"
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: firstSection.tasks[3]),
            .startPractice(lessonID: "yds-practice-lesson-tenses")
        )
    }

    @MainActor
    func test_lockedUnits_stillShowPaketiAc() throws {
        let context = try makeRealContentContext()
        let viewModel = CoursePathViewModel(
            context: context, userID: "u", accessProvider: FixedAccessProvider(level: .preview)
        )
        viewModel.load()

        let secondSection = try XCTUnwrap(viewModel.sections.dropFirst().first)
        XCTAssertTrue(secondSection.tasks.allSatisfy { if case .locked = $0 { return true } else { return false } })
    }

    @MainActor
    func test_load_noPackages_emptySections() throws {
        let context = try makeContext(seed: false)
        let vm = CoursePathViewModel(context: context, userID: userID, accessProvider: FixedAccessProvider(level: .owned))
        vm.load()
        XCTAssertTrue(vm.sections.isEmpty)
    }
}
