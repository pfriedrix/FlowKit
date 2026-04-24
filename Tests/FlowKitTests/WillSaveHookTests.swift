import XCTest
import os
@testable import FlowKit

// Whitebox tests for the internal `Store.willSave` hook.
//
// `willSave` is an internal implementation detail of the `Storable` integration
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
final class WillSaveHookTests: XCTestCase {

    func testWillSaveCalledAfterAction() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let expectation = XCTestExpectation(description: "willSave called")
        let collector = SaveCollector()

        store.willSave = { state in
            collector.append(state.count)
            expectation.fulfill()
        }

        store.send(.increment)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(collector.values, [1])
    }

    func testWillSaveCalledForEveryAction() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let collector = SaveCollector()

        store.willSave = { state in
            collector.append(state.count)
        }

        store.send(.increment)
        store.send(.increment)
        store.send(.increment)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(collector.values, [1, 2, 3])
    }

    func testWillSaveNotCalledWhenNil() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())
        store.willSave = nil

        store.send(.increment)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(store.state.count, 1)
    }

    func testWillSaveReceivesUpdatedState() async throws {
        let store = Store(initial: WillSaveReducer.State(), reducer: WillSaveReducer())

        let expectation = XCTestExpectation(description: "willSave receives updated state")
        expectation.expectedFulfillmentCount = 2
        let collector = SaveCollector()

        store.willSave = { state in
            collector.append(state.count)
            expectation.fulfill()
        }

        store.send(.increment)
        store.send(.increment)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(collector.values, [1, 2])
        XCTAssertEqual(store.state.count, 2)
    }
}
