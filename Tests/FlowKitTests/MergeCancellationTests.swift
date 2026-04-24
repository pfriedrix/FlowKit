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

    // Test 3: Merge followed by a separate cancellable run effect
    func testMergeThenCancellableRunEffect() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())

        // Merge executes synchronously
        store.send(.startMixedMergeAndRun)
        XCTAssertEqual(store.state.count, 2, "Merge actions should execute immediately")

        // Now start a separate cancellable run
        store.send(.startCancellableRun)
        XCTAssertEqual(store.state.status, "Task Started")

        try await waitForStateChange(timeout: 2.0) {
            store.state.status == "Task Completed"
        }

        XCTAssertEqual(store.state.status, "Task Completed")
        XCTAssertEqual(store.state.count, 2, "Merge count should be unaffected")
    }

    // Test 4: Cancel run effect while merge has already executed
    func testCancelRunEffectAfterMerge() async throws {
        let store: Store<MergeCancellableReducer> = Store(initial: MergeCancellableReducer.State(), reducer: MergeCancellableReducer())

        store.send(.startMixedMergeAndRun)
        XCTAssertEqual(store.state.count, 2, "Merge actions executed")

        store.send(.startCancellableRun)
        XCTAssertEqual(store.state.status, "Task Started")

        try await Task.sleep(nanoseconds: 50_000_000)
        store.send(.cancelRun)

        try await Task.sleep(nanoseconds: 1_500_000_000)

        XCTAssertEqual(store.state.status, "Task Started", "Task should not have completed due to cancellation")
        XCTAssertEqual(store.state.count, 2, "Merge count should be unaffected")
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
        case startCancellableRun
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
            return .merge(.increment, .increment, .increment)
                .cancellable(id: "mergeTask", cancelInFlight: true)

        case .startMixedMergeAndRun:
            return .merge(.increment, .increment)

        case .startCancellableRun:
            state.status = "Task Started"
            return .run { send in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                await send(.completeTask)
            } catch: { _, _ in }
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
