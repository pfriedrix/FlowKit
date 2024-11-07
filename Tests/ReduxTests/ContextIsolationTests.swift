import XCTest
@testable import FlowKit

final class ContextIsolationTests: XCTestCase {
    var store: Store<CancellableReducer>!

    override func setUp() {
        super.setUp()
        let reducer = CancellableReducer()
        store = Store(initial: CancellableReducer.State(), reducer: reducer)
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // Test 1: Ensure tasks operate independently when started with different IDs.
    @MainActor
    func testIndependentTaskExecution() async throws {
        // Start the first task
        store.send(.startCancellableTask)
        
        // Wait briefly
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The first task should have started.")
        
        // Simulate starting a second task with a different ID
        // You may need to modify the reducer to accept and distinguish between multiple IDs
        let secondReducer = CancellableReducer()
        let secondStore = Store(initial: CancellableReducer.State(), reducer: secondReducer)
        secondStore.send(.startCancellableTask)
        
        // Wait briefly and check that both are isolated
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The first task should still be running.")
        XCTAssertEqual(secondStore.state.data, "Task Started", "The second task should have started independently.")
    }

    // Test 2: Verify that cancellation with one ID does not affect tasks with different IDs.
    @MainActor
    func testCancellationIsolation() async throws {
        // Start the first task
        store.send(.startCancellableTask)
        
        // Wait briefly
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertEqual(store.state.data, "Task Started", "The first task should have started.")
        
        // Simulate starting a second task with a different ID
        let secondReducer = CancellableReducer()
        let secondStore = Store(initial: CancellableReducer.State(), reducer: secondReducer)
        secondStore.send(.startCancellableTask)
        
        // Cancel the task in the first store
        store.send(.cancelTask)
        
        // Wait to ensure the cancellation takes effect
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Verify the first task was canceled
        XCTAssertEqual(store.state.data, "Task Started", "The first task should not have completed due to cancellation.")

        // Verify the second task completes normally
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        XCTAssertEqual(secondStore.state.data, "Task Completed", "The second task should have completed unaffected by the first task's cancellation.")
    }
}
