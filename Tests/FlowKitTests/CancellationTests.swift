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
                await send(.completeTask)
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
}
