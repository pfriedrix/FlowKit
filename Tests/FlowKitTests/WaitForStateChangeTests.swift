import Foundation
import Testing
@testable import FlowKit

@MainActor
struct WaitForStateChangeTests {
    struct BumpReducer: Reducer {
        struct State: Equatable, Sendable { var count: Int = 0 }
        enum Action: Equatable, Sendable { case bump }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            state.count += 1
            return .none
        }
    }

    @Test func `Returns immediately when condition already true`() async throws {
        let store = Store(initial: BumpReducer.State(count: 1), reducer: BumpReducer())
        let start = Date()
        try await waitForStateChange(timeout: 5.0) {
            store.state.count == 1
        }
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.05, "Should return synchronously without awaiting")
    }

    // No wall-clock bound: suites run in parallel and share MainActor, so the
    // time to return measures other suites' load, not this helper.
    @Test func `Returns after single send`() async throws {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            store.send(.bump)
        }

        try await waitForStateChange(timeout: 5.0) {
            store.state.count == 1
        }
        #expect(store.state.count == 1)
    }

    @Test func `Returns after multiple state changes`() async throws {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        Task { @MainActor in
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 5_000_000)
                store.send(.bump)
            }
        }

        try await waitForStateChange(timeout: 5.0) {
            store.state.count == 3
        }
        #expect(store.state.count == 3)
    }

    @Test func `Throws on timeout`() async {
        let store = Store(initial: BumpReducer.State(), reducer: BumpReducer())

        await #expect(throws: WaitForStateChangeTimeout.self, "Expected timeout error") {
            try await waitForStateChange(timeout: 0.1) {
                store.state.count == 99
            }
        }
    }
}
