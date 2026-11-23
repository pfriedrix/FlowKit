import Testing
@testable import FlowKit

@MainActor
struct MergeEffectTests {
    var store: Store<MergeTestReducer> = Store(initial: MergeTestReducer.State(), reducer: MergeTestReducer())

    // Test 1: Merge with multiple actions executes all actions sequentially
    @Test func `Merge multiple actions`() async throws {
        store.send(.mergeThreeIncrements)

        // Wait for all actions to be processed
        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 3
        }

        #expect(store.state.count == 3, "All three increment actions should have been executed")
        #expect(store.state.actionLog.count == 3, "All three actions should be logged")
        #expect(store.state.actionLog == ["increment", "increment", "increment"])
    }

    // Test 2: Merge preserves action execution order
    @Test func `Merge preserves order`() async throws {
        store.send(.mergeMixedActions)

        // Wait for all actions to be processed
        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 2 && self.store.state.message == "Message 2"
        }

        #expect(store.state.count == 2)
        #expect(store.state.message == "Message 2")
        #expect(store.state.actionLog == [
            "increment",
            "setMessage(Message 1)",
            "increment",
            "setMessage(Message 2)"
        ])
    }

    // Test 3: Merge with single action behaves correctly
    @Test func `Merge single action`() async throws {
        store.send(.mergeSingleIncrement)

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 1
        }

        #expect(store.state.count == 1)
        #expect(store.state.actionLog == ["increment"])
    }

    // Test 4: Empty merge returns .none (no actions executed)
    @Test func `Empty merge`() async throws {
        let initialCount = store.state.count

        store.send(.mergeEmpty)

        // Wait a bit to ensure no actions are processed
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        #expect(store.state.count == initialCount, "No actions should have been executed")
        #expect(store.state.actionLog == [], "Action log should be empty")
    }

    // Test 5: Merge with many actions (stress test)
    @Test func `Merge many actions`() async throws {
        store.send(.mergeTenIncrements)

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 10
        }

        #expect(store.state.count == 10)
        #expect(store.state.actionLog.count == 10)
        #expect(store.state.actionLog.allSatisfy { $0 == "increment" })
    }

    // Test 6: Multiple merge effects in sequence
    @Test func `Multiple merge effects in sequence`() async throws {
        store.send(.mergeTwoIncrements)
        store.send(.mergeTwoIncrements)

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 4
        }

        #expect(store.state.count == 4)
        #expect(store.state.actionLog.count == 4)
    }

    // Test 7: Merge effect combined with regular effects
    @Test func `Merge combined with regular effects`() async throws {
        store.send(.increment)
        store.send(.mergeTwoIncrements)
        store.send(.increment)

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 4
        }

        #expect(store.state.count == 4)
        #expect(store.state.actionLog.count == 4)
    }

    // Test 8: Nested merge effects (merge returning more merges)
    @Test func `Nested merge effects`() async throws {
        store.send(.nestedMerge)

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 5
        }

        #expect(store.state.count == 5, "Nested merge should execute all actions")
    }

    // Test 9: Merge with state-dependent actions
    @Test mutating func `Merge with state-dependent actions`() async throws {
        store.send(.conditionalMerge(shouldIncrement: true))

        try await waitForStateChange(timeout: 5.0) { [store] in
            store.state.count == 2
        }

        #expect(store.state.count == 2)

        // Reset and test with false
        store = Store(initial: MergeTestReducer.State(), reducer: MergeTestReducer())
        store.send(.conditionalMerge(shouldIncrement: false))

        try await waitForStateChange(timeout: 5.0) { [store] in
            store.state.message == "Skipped"
        }

        #expect(store.state.count == 0)
        #expect(store.state.message == "Skipped")
    }

    // Test 10: High-frequency merge dispatches
    @Test func `High-frequency merge dispatches`() async throws {
        for _ in 0..<100 {
            store.send(.mergeTwoIncrements)
        }

        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == 200
        }

        #expect(store.state.count == 200)
    }
}

// Test reducer for merge effect testing
final class MergeTestReducer: Reducer {
    struct State {
        var count: Int = 0
        var message: String = ""
        var actionLog: [String] = []
    }

    enum Action {
        case increment
        case setMessage(String)
        case mergeEmpty
        case mergeSingleIncrement
        case mergeTwoIncrements
        case mergeThreeIncrements
        case mergeTenIncrements
        case mergeMixedActions
        case nestedMerge
        case conditionalMerge(shouldIncrement: Bool)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            state.actionLog.append("increment")
            return .none

        case .setMessage(let message):
            state.message = message
            state.actionLog.append("setMessage(\(message))")
            return .none

        case .mergeEmpty:
            return .merge()

        case .mergeSingleIncrement:
            return .merge(.increment)

        case .mergeTwoIncrements:
            return .merge(.increment, .increment)

        case .mergeThreeIncrements:
            return .merge(.increment, .increment, .increment)

        case .mergeTenIncrements:
            return .merge(
                .increment, .increment, .increment, .increment, .increment,
                .increment, .increment, .increment, .increment, .increment
            )

        case .mergeMixedActions:
            return .merge(
                .increment,
                .setMessage("Message 1"),
                .increment,
                .setMessage("Message 2")
            )

        case .nestedMerge:
            // First merge will trigger more merges
            return .merge(
                .increment,
                .mergeTwoIncrements,  // This will add 2 more
                .mergeTwoIncrements   // This will add 2 more
            )

        case .conditionalMerge(let shouldIncrement):
            if shouldIncrement {
                return .merge(.increment, .increment)
            } else {
                return .merge(.setMessage("Skipped"))
            }
        }
    }
}
