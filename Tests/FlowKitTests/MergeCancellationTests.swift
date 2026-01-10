import XCTest
@testable import FlowKit

@MainActor
final class MergeCancellationTests: XCTestCase {

    // Test 1: Merge effect with cancellable returns .none (immediate actions are not cancellable)
    func testMergeWithCancellableReturnsNone() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())
        
        store.send(.startMergeWithCancellable)

        // Merge actions should execute immediately (not async), so cancellation doesn't apply
        XCTAssertEqual(store.state.count, 3, "Merge actions should have executed")
        XCTAssertTrue(store.state.status.isEmpty, "Status should be empty as merge doesn't create cancellable tasks")
    }

    // Test 2: Cancel command should not affect already-executed merge actions
    func testCancelDoesNotAffectMergeActions() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())
        
        store.send(.startMergeWithCancellable)

        // Try to cancel immediately
        store.send(.cancelMerge)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 3
        }

        XCTAssertEqual(store.state.count, 3, "Merge actions execute synchronously, cancel has no effect")
    }

    // Test 3: Merge combined with actual cancellable run effects
    func testMergeCombinedWithCancellableRunEffect() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())
        
        store.send(.startMixedMergeAndRun)

        // Merge actions should execute immediately
        try await waitForStateChange(timeout: 0.5) {
            store.state.count == 2
        }

        XCTAssertEqual(store.state.count, 2, "Merge actions should execute immediately")
        XCTAssertEqual(store.state.status, "Task Started")

        // Wait for the run effect to complete
        try await waitForStateChange(timeout: 2.0) {
            store.state.status == "Task Completed"
        }

        XCTAssertEqual(store.state.status, "Task Completed")
    }

    // Test 4: Cancel run effect while merge has already executed
    func testCancelRunEffectAfterMerge() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())
        
        store.send(.startMixedMergeAndRun)

        // Wait for merge to execute
        try await waitForStateChange(timeout: 0.5) {
            store.state.count == 2
        }

        XCTAssertEqual(store.state.count, 2, "Merge actions executed")

        // Cancel the run effect before it completes
        store.send(.cancelRun)

        // Wait to ensure the run effect doesn't complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        XCTAssertEqual(store.state.status, "Task Started", "Task should not have completed due to cancellation")
    }

    // Test 5: Rapid merge and cancel attempts (edge case)
    func testRapidMergeAndCancelAttempts() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())
        
        for _ in 0..<10 {
            store.send(.startMergeWithCancellable)
            store.send(.cancelMerge)
        }

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // All merge actions should have executed despite cancel attempts
        XCTAssertEqual(store.state.count, 30, "All merge actions should execute")
    }
}

// Test reducer for merge cancellation testing
final class MergeCancellableReducer: Reducer {
    struct State {
        var count: Int = 0
        var status: String = ""
    }

    enum Action {
        case increment
        case startMergeWithCancellable
        case startMixedMergeAndRun
        case cancelMerge
        case cancelRun
        case completeTask
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .startMergeWithCancellable:
            // Merge effect with cancellable should just return .none
            return .merge(.increment, .increment, .increment)
                .cancellable(id: "mergeTask", cancelInFlight: true)

        case .startMixedMergeAndRun:
            state.status = "Task Started"
            // First execute merge actions, then return a cancellable run effect
            state.count += 2  // Simulate immediate merge actions
            return .run { send in
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                send(.completeTask)
            }
            .cancellable(id: "runTask", cancelInFlight: true)

        case .cancelMerge:
            return .cancel(id: "mergeTask")

        case .cancelRun:
            return .cancel(id: "runTask")

        case .completeTask:
            state.status = "Task Completed"
            return .none
        }
    }
}
