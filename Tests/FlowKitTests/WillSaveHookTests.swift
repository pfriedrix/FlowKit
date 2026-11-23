import Testing
import os
@testable import FlowKit

// Whitebox tests for the internal `Store.willSave` hook.
//
// `willSave` is an internal implementation detail of the `Persistence` integration
// (see `Storage.swift` for the production wiring). It is reached here via
// `@testable import FlowKit` to lock in the low-level invariants the integration
// relies on: called once per reduce, in order, with the post-reduce state, and
// skipped when nil. These tests are NOT a public-API contract — do not rely on
// `willSave` in application code.

struct WillSaveReducer: Reducer {
    struct State: Equatable, Sendable {
        var count: Int = 0
    }

    enum Action: Sendable {
        case increment
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        }
    }
}

final class SaveCollector: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [Int]())

    func append(_ value: Int) {
        lock.withLock { $0.append(value) }
    }

    var values: [Int] {
        lock.withLock { $0 }
    }
}

@MainActor
struct WillSaveHookTests {

    @Test func `willSave called after action`() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let collector = SaveCollector()

        try await confirmation("willSave called") { confirm in
            store.willSave = { state in
                collector.append(state.count)
                confirm()
            }

            store.send(.increment)

            try await waitForStateChange(timeout: 1.0) { collector.values.count == 1 }
        }
        #expect(collector.values == [1])
    }

    @Test func `willSave called for every action`() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let collector = SaveCollector()

        store.willSave = { state in
            collector.append(state.count)
        }

        store.send(.increment)
        store.send(.increment)
        store.send(.increment)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(collector.values == [1, 2, 3])
    }

    @Test func `willSave not called when nil`() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())
        store.willSave = nil

        store.send(.increment)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(store.state.count == 1)
    }

    @Test func `willSave receives updated state`() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let collector = SaveCollector()

        try await confirmation("willSave receives updated state", expectedCount: 2) { confirm in
            store.willSave = { state in
                collector.append(state.count)
                confirm()
            }

            store.send(.increment)
            store.send(.increment)

            try await waitForStateChange(timeout: 1.0) { collector.values.count == 2 }
        }

        #expect(collector.values == [1, 2])
        #expect(store.state.count == 2)
    }
}
