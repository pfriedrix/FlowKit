@_spi(Internals) @testable import FlowKit
import XCTest

final class CancellableReducer: Reducer {
    struct State {
        var count: Int = 0
        var data: String = ""
    }

    enum Action {
        case startCancellableTask
        case cancelTask
        case completeTask
    }

    let taskId: String

    init(taskId: String = "testTask") {
        self.taskId = taskId
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startCancellableTask:
            state.data = "Task Started"
            return .run { send in
                // Simulated async operation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await send(.completeTask)
            } catch: { error, send in
                // Handle errors (like CancellationError) silently
                // Task was cancelled or failed, don't send completion
            }
            .cancellable(id: taskId, cancelInFlight: true)

        case .cancelTask:
            return .cancel(id: taskId)

        case .completeTask:
            state.data = "Task Completed"
            return .none
        }
    }
}

final class RaceConditionTestReducer: Reducer {
    struct State {
        var executionCount: Int = 0
        var wasCancelled: Bool = false
        var taskStarted: Bool = false
    }

    enum Action {
        case startRaceConditionTask
        case cancelRaceConditionTask
        case taskExecuted
        case taskCancelled
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startRaceConditionTask:
            state.taskStarted = true
            return .run { send in
                // Simulate some work that could be interrupted
                // Add a delay to allow cancellation to occur
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Send action based on cancellation status
                // Note: If cancelled, the send may not go through due to Task.isCancelled check in Store
                if !Task.isCancelled {
                    await send(.taskExecuted)
                }
            } catch: { error, send in
                // Task was cancelled before completion
                // This catch block may not be reached due to how cancellation is handled
            }
            .cancellable(id: "raceConditionTask", cancelInFlight: true)
            
        case .cancelRaceConditionTask:
            return .cancel(id: "raceConditionTask")
            
        case .taskExecuted:
            state.executionCount += 1
            return .none
            
        case .taskCancelled:
            state.wasCancelled = true
            return .none
        }
    }
}

@MainActor
final class CancellationTests: XCTestCase {

    // Test 1: Ensure a cancellable task can be started and then canceled correctly.
    func testCancellableTaskStartAndCancel() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test1_task"))

        // Start a cancellable task
        store.send(.startCancellableTask)
        
        // Wait briefly to ensure the task starts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The task should have started.")
        
        // Cancel the task
        store.send(.cancelTask)
        
        // Wait briefly to ensure the cancellation takes effect
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Verify that the task was canceled and did not complete
        XCTAssertEqual(store.state.data, "Task Started", "The task should not have completed due to cancellation.")
    }

    // Test 2: Ensure a task runs to completion if not canceled.
    func testCancellableTaskCompletion() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test2_task"))

        store.send(.startCancellableTask)

        try await waitForStateChange(timeout: 2.0) {
            store.state.data == "Task Completed"
        }
        XCTAssertEqual(store.state.data, "Task Completed")
    }

    // Test 3: Ensure multiple starts and cancels work correctly.
    func testMultipleStartAndCancel() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test3_task"))

        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 200_000_000) // let first task actually enter its sleep
        store.send(.cancelTask)

        store.send(.startCancellableTask)
        // First: task is marked started synchronously on send.
        XCTAssertEqual(store.state.data, "Task Started")

        // Then wait for the natural completion of the restarted task.
        try await waitForStateChange(timeout: 2.0) {
            store.state.data == "Task Completed"
        }
        XCTAssertEqual(store.state.data, "Task Completed")
    }

    // Test 4: Rapid start and cancel scenario.
    func testRapidStartAndCancel() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test4_task"))

        // Rapidly start and cancel the task multiple times
        for _ in 0..<5 {
            store.send(.startCancellableTask)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            store.send(.cancelTask)
        }

        // Ensure the state reflects that the task was not completed
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The task should not have completed due to rapid cancellations.")
    }

    // Test 5: No double execution after cancellation
    func testNoDoubleExecutionAfterCancellation() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test5_task"))

        // Start a task and cancel it quickly
        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        store.send(.cancelTask)

        // Ensure no completion occurs
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The task should not have completed after cancellation.")
    }
    
    // Test: auto-cleanup on completion — the collection entry must not leak after a
    // `.cancellable` task finishes naturally.
    func testCancellableEntryRemovedAfterCompletion() async throws {
        let taskId = "leak_\(UUID().uuidString)"
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: taskId))

        let baseline = store.tasks.values.filter({ $0.id != nil }).count

        store.send(.startCancellableTask)

        // Registration is synchronous on MainActor — entry must already exist.
        XCTAssertEqual(store.tasks.values.filter({ $0.id != nil }).count, baseline + 1)

        try await waitForStateChange(timeout: 2.0) {
            store.state.data == "Task Completed"
        }
        try await waitForStateChange(timeout: 1.0) {
            store.tasks.values.filter({ $0.id != nil }).count == baseline
        }
        XCTAssertEqual(store.tasks.values.filter({ $0.id != nil }).count, baseline)
    }

    // Test: race fix — a cancel dispatched immediately after start must never be missed.
    // Pre-fix: `Task { }` started before registration, so the cancel found nothing and the task
    // ran to completion. Post-fix: `register` is a single non-suspending actor step, so the
    // cancel always observes the new entry.
    func testStartThenImmediateCancelNeverRuns() async throws {
        let iterations = 50
        var stores: [Store<CancellableReducer>] = []
        for i in 0..<iterations {
            let taskId = "race_\(i)_\(UUID().uuidString)"
            let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: taskId))
            store.send(.startCancellableTask)
            store.send(.cancelTask)
            stores.append(store)
        }

        // Wait longer than the reducer's 1s sleep — any task that escaped cancellation would
        // have completed within this window and set `data` to "Task Completed".
        try await Task.sleep(nanoseconds: 1_500_000_000)

        for (i, store) in stores.enumerated() {
            XCTAssertEqual(store.state.data, "Task Started", "Iteration \(i): cancel was missed, task ran to completion")
        }
    }

    // Test: replacement safety — when a second `withTaskCancellation` with the same id and
    // `cancelInFlight: true` supersedes an earlier one, the earlier task's late `removeIfCurrent`
    // must not evict the replacement.
    /// Cancelled first task's late cleanup hop must not evict the live replacement.
    func testReplacement_survivesLateCleanupOfCancelledPredecessor() async throws {
        let taskId = "replace_\(UUID().uuidString)"
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: taskId))

        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 100_000_000)

        store.send(.startCancellableTask) // cancelInFlight: true — replaces first

        // Wait out the cancelled first task's completion hop.
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.tasks.values.filter({ $0.id != nil }).count, 1)
    }

    /// Explicit `.cancel(id:)` removes the live replacement from the registry.
    func testReplacement_removedAfterExplicitCancel() async throws {
        let taskId = "replace_\(UUID().uuidString)"
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: taskId))

        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 100_000_000)
        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 200_000_000)

        store.send(.cancelTask)

        try await waitForStateChange(timeout: 1.0) {
            store.tasks.values.filter({ $0.id != nil }).isEmpty
        }
        XCTAssertEqual(store.tasks.values.filter({ $0.id != nil }).count, 0)
    }

    // Test 6: Verify cancellation prevents task execution
    func testRaceConditionFix() async throws {
        let reducer = RaceConditionTestReducer()
        let store = Store(initial: RaceConditionTestReducer.State(), reducer: reducer)

        // Start task that will check cancellation after a delay
        store.send(.startRaceConditionTask)

        // Verify task started
        XCTAssertTrue(store.state.taskStarted, "Task should have been marked as started")

        // Cancel immediately after starting
        store.send(.cancelRaceConditionTask)

        // Wait for task to complete or be cancelled
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // When cancelled, the task should NOT have executed (executionCount should be 0)
        // Note: wasCancelled won't be set because cancelled tasks can't send actions
        XCTAssertEqual(store.state.executionCount, 0, "Cancelled task should not have executed")
        XCTAssertTrue(store.state.taskStarted, "Task should still be marked as started")
    }
}
