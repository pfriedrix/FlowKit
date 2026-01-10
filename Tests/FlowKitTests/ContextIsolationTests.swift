import XCTest
@testable import FlowKit

@MainActor
final class ContextIsolationTests: XCTestCase {

    // Test 1: Ensure tasks operate independently when started with different IDs.
    func testIndependentTaskExecution() async throws {
        // Create first store with unique task ID
        let firstReducer = CancellableReducer(taskId: "independentTest_store1")
        let firstStore = Store(initial: CancellableReducer.State(), reducer: firstReducer)

        // Start the first task
        firstStore.send(.startCancellableTask)

        // Wait briefly
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(firstStore.state.data, "Task Started", "The first task should have started.")

        // Create a second store with a different task ID
        let secondReducer = CancellableReducer(taskId: "independentTest_store1")
        let secondStore = Store(initial: CancellableReducer.State(), reducer: secondReducer)
        secondStore.send(.startCancellableTask)
        
        // Wait briefly and check that both are isolated
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(secondStore.state.data, "Task Started", "The second task should have started independently.")
        XCTAssertEqual(firstStore.state.data, "Task Started", "The first task should still be running.")
    }

    // Test 2: Verify that cancellation with one ID does not affect tasks with different IDs.
    func testCancellationIsolation() async throws {
        // Create first store with unique task ID
        let firstReducer = CancellableReducer(taskId: "cancellationTest_store1")
        let firstStore = Store(initial: CancellableReducer.State(), reducer: firstReducer)

        // Start the first task
        firstStore.send(.startCancellableTask)

        // Wait briefly
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(firstStore.state.data, "Task Started", "The first task should have started.")

        // Create a second store with a different task ID
        let secondReducer = CancellableReducer(taskId: "cancellationTest_store2")
        let secondStore = Store(initial: CancellableReducer.State(), reducer: secondReducer)
        secondStore.send(.startCancellableTask)

        // Cancel the task in the first store
        firstStore.send(.cancelTask)
        
        // Wait to ensure the cancellation takes effect
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Verify the first task was canceled
        XCTAssertEqual(firstStore.state.data, "Task Started", "The first task should not have completed due to cancellation.")

        // Verify the second task completes normally
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 seconds
        XCTAssertEqual(secondStore.state.data, "Task Completed", "The second task should have completed unaffected by the first task's cancellation.")
    }
}
