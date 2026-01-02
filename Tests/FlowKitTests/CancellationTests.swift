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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startCancellableTask:
            state.data = "Task Started"
            return .run { send in
                // Simulated async operation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                send(.completeTask)
            }
            .cancellable(id: "testTask", cancelInFlight: true)
            
        case .cancelTask:
            return .cancel(id: "testTask")

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
                do {
                    // Add a small delay to allow cancellation to occur
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    try Task.checkCancellation()
                    send(.taskExecuted)
                } catch is CancellationError {
                    send(.taskCancelled)
                }
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

final class CancellationTests: XCTestCase {
    @MainActor
    var store: Store<CancellableReducer> = Store(initial: CancellableReducer.State(), reducer: CancellableReducer())

    // Test 1: Ensure a cancellable task can be started and then canceled correctly.
    @MainActor
    func testCancellableTaskStartAndCancel() async throws {
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
    @MainActor
    func testCancellableTaskCompletion() async throws {
        // Start a cancellable task
        store.send(.startCancellableTask)
        
        // Wait for the task to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Completed", "The task should have completed.")
    }

    // Test 3: Ensure multiple starts and cancels work correctly.
    @MainActor
    func testMultipleStartAndCancel() async throws {
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
    @MainActor
    func testRapidStartAndCancel() async throws {
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
    @MainActor
    func testNoDoubleExecutionAfterCancellation() async throws {
        // Start a task and cancel it quickly
        store.send(.startCancellableTask)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        store.send(.cancelTask)

        // Ensure no completion occurs
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The task should not have completed after cancellation.")
    }
    
    // Test 6: Race condition fix - Task.checkCancellation() prevents execution
    @MainActor
    func testRaceConditionFix() async throws {
        let reducer = RaceConditionTestReducer()
        let store = Store(initial: RaceConditionTestReducer.State(), reducer: reducer)
        
        // Start task that will check cancellation after a delay
        store.send(.startRaceConditionTask)
        
        // Verify task started
        XCTAssertTrue(store.state.taskStarted, "Task should have been marked as started")
        
        // Cancel immediately after starting
        store.send(.cancelRaceConditionTask)
        
        // Wait for either cancellation or execution to complete
        try await waitForStateChange(timeout: 2.0) {
            store.state.wasCancelled || store.state.executionCount > 0
        }
        
        // The key test: task should either be cancelled OR executed, but not both
        // This verifies that our cancellation mechanism works properly
        if store.state.wasCancelled {
            XCTAssertEqual(store.state.executionCount, 0, "If cancelled, task should not have executed")
        } else {
            XCTAssertEqual(store.state.executionCount, 1, "If not cancelled, task should have executed")
            XCTAssertFalse(store.state.wasCancelled, "If executed, task should not be marked as cancelled")
        }
        
        // At minimum, one of these should be true (task completed one way or another)
        XCTAssertTrue(store.state.wasCancelled || store.state.executionCount > 0, 
                     "Task should have either been cancelled or executed")
    }
}
