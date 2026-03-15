import XCTest
@testable import Cursor_Metro

final class TasksListStoreTests: XCTestCase {
    @MainActor
    func testConfigureBuildsSnapshotSectionsFromTasksAndStatuses() throws {
        let workspacePath = try makeWorkspacePath()
        let now = Date()

        let backlog = ProjectTask(
            content: "Backlog",
            createdAt: now.addingTimeInterval(-10),
            taskState: .backlog
        )
        let review = ProjectTask(
            content: "Review",
            createdAt: now.addingTimeInterval(-20),
            taskState: .inProgress
        )
        let stopped = ProjectTask(
            content: "Stopped",
            createdAt: now.addingTimeInterval(-30),
            taskState: .inProgress
        )
        let processing = ProjectTask(
            content: "Processing",
            createdAt: now.addingTimeInterval(-40),
            taskState: .inProgress
        )
        let todo = ProjectTask(
            content: "Todo",
            createdAt: now.addingTimeInterval(-50),
            taskState: .inProgress
        )
        let recentCompleted = ProjectTask(
            content: "Recent Completed",
            createdAt: now.addingTimeInterval(-60),
            taskState: .completed,
            completedAt: now.addingTimeInterval(-3600)
        )
        let oldCompleted = ProjectTask(
            content: "Old Completed",
            createdAt: now.addingTimeInterval(-70),
            taskState: .completed,
            completedAt: now.addingTimeInterval(-(3 * 24 * 60 * 60))
        )
        let deleted = ProjectTask(
            content: "Deleted",
            createdAt: now.addingTimeInterval(-80),
            taskState: .deleted,
            deletedAt: now.addingTimeInterval(-600),
            preDeletionTaskState: .inProgress
        )

        try writeTasks(
            [backlog, review, stopped, processing, todo, recentCompleted, oldCompleted, deleted],
            workspacePath: workspacePath
        )

        let store = TasksListStore()
        store.configure(
            workspacePath: workspacePath,
            linkedStatuses: [
                review.id: .review,
                stopped.id: .stopped,
                processing.id: .processing
            ]
        )

        XCTAssertEqual(store.snapshot.counts.backlog, 1)
        XCTAssertEqual(store.snapshot.counts.inProgress, 4)
        XCTAssertEqual(store.snapshot.counts.completed, 2)
        XCTAssertEqual(store.snapshot.counts.deleted, 1)

        XCTAssertEqual(store.snapshot.reviewRows.map(\.task.id), [review.id])
        XCTAssertEqual(store.snapshot.stoppedRows.map(\.task.id), [stopped.id])
        XCTAssertEqual(store.snapshot.processingRows.map(\.task.id), [processing.id])
        XCTAssertEqual(store.snapshot.todoRows.map(\.task.id), [todo.id])

        XCTAssertEqual(store.snapshot.visibleCompletedTasks.map(\.id), [recentCompleted.id])
        XCTAssertEqual(store.snapshot.completedGrouped.map(\.title), ["Today"])
        XCTAssertEqual(store.snapshot.deletedGrouped.map(\.title), ["Today"])

        store.setShowOnlyRecentCompleted(false)

        XCTAssertEqual(store.snapshot.visibleCompletedTasks.map(\.id), [recentCompleted.id, oldCompleted.id])
        XCTAssertEqual(store.snapshot.completedGrouped.map(\.title), ["Today", "Last 7 Days"])
    }

    @MainActor
    func testConfigureResetsTransientStateWhenWorkspaceChanges() throws {
        let firstWorkspace = try makeWorkspacePath()
        let secondWorkspace = try makeWorkspacePath()

        let store = TasksListStore()
        store.configure(workspacePath: firstWorkspace, linkedStatuses: [:])
        store.showNewTaskComposer(selecting: .backlog)
        store.newTaskDraft = "Draft"
        store.newTaskModelId = "custom-model"
        store.previewRunningInExternalTerminal = true
        store.setShowOnlyRecentCompleted(false)
        store.expandedCompletedSections = ["Older"]
        store.expandedDeletedSections = ["Older"]

        store.configure(workspacePath: secondWorkspace, linkedStatuses: [:])

        XCTAssertFalse(store.isAddingNewTask)
        XCTAssertEqual(store.newTaskDraft, "")
        XCTAssertEqual(store.newTaskModelId, AvailableModels.autoID)
        XCTAssertFalse(store.previewRunningInExternalTerminal)
        XCTAssertTrue(store.showOnlyRecentCompleted)
        XCTAssertEqual(store.expandedCompletedSections, ["Today"])
        XCTAssertEqual(store.expandedDeletedSections, ["Today"])
        XCTAssertEqual(store.selectedTasksTab, .inProgress)
    }
}
