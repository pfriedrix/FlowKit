import XCTest
@testable import FlowKit

@MainActor
final class WaitForStateChangeTests: XCTestCase {
    struct BumpReducer: Reducer {
        struct State: Equatable, Sendable { var count: Int = 0 }
        enum Action: Equatable, Sendable { case bump }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            state.count += 1
            return .none
        }
    }

    func testReturnsImmediatelyWhenConditionAlreadyTrue() async throws {
        let store = Store(initial: BumpReducer.State(count: 1), reducer: BumpReducer())
        let start = Date()
        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.05, "Should return synchronously without awaiting")
    }

    func testReturnsPromptlyAfterSingleSend() async throws {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            store.send(.bump)
        }

        let start = Date()
        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(store.state.count, 1)
        XCTAssertLessThan(elapsed, 0.2, "Observation-driven wait should beat 50ms poll floor")
    }

    func testReturnsAfterMultipleStateChanges() async throws {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        Task { @MainActor in
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 5_000_000)
                store.send(.bump)
            }
        }

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 3
        }
        XCTAssertEqual(store.state.count, 3)
    }

    func testThrowsOnTimeout() async {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        do {
            try await waitForStateChange(timeout: 0.1) {
                store.state.count == 99
            }
            XCTFail("Expected timeout error")
        } catch is WaitForStateChangeTimeout {
            // expected
        } catch {
            XCTFail("Expected WaitForStateChangeTimeout, got \(error)")
        }
    }
}
