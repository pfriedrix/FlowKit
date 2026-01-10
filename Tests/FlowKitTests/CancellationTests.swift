@testable import FlowKit
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
                send(.completeTask)
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
                    send(.taskExecuted)
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

        // Start a cancellable task
        store.send(.startCancellableTask)
        
        // Wait for the task to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Completed", "The task should have completed.")
    }

    // Test 3: Ensure multiple starts and cancels work correctly.
    func testMultipleStartAndCancel() async throws {
        let store = Store(initial: CancellableReducer.State(), reducer: CancellableReducer(taskId: "test3_task"))

        // Start a cancellable task
        store.send(.startCancellableTask)
        
        // Wait briefly and cancel
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        store.send(.cancelTask)
        
        // Start the task again
        store.send(.startCancellableTask)
        
        // Ensure task starts again
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The task should have started again.")
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Completed", "The task should have completed after being restarted.")
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
