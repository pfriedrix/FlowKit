import XCTest
@testable import FlowKit

// Tests for `Store(reducer:default:storage:)` against in-memory storages:
// nothing here reads or writes `UserDefaults`.

private struct StoredCounterReducer: Reducer {
    struct State: Equatable, Sendable {
        var value: Int = 0
    }

    enum Action {
        case increment
        case decrement
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        }
        return .none
    }
}

@MainActor
final class StateStorageTests: XCTestCase {

    // MARK: - Restoring

    func testStoreStartsFromStateHeldByStorage() {
        let memory = InMemoryStorage(StoredCounterReducer.State(value: 42))

        let store = Store(reducer: StoredCounterReducer(), default: .init(), storage: memory)

        XCTAssertEqual(store.state.value, 42)
    }

    func testStoreStartsFromDefaultWhenStorageIsEmpty() {
        let memory = InMemoryStorage<StoredCounterReducer.State>()

        let store = Store(reducer: StoredCounterReducer(), default: .init(value: 10), storage: memory)

        XCTAssertEqual(store.state.value, 10)
    }

    func testDefaultStateIsSavedDuringInitWhenStorageIsEmpty() {
        let memory = InMemoryStorage<StoredCounterReducer.State>()

        _ = Store(reducer: StoredCounterReducer(), default: .init(value: 10), storage: memory)

        XCTAssertEqual(memory.value, .init(value: 10))
    }

    func testRestoredStateIsNotSavedBackDuringInit() {
        let recording = RecordingStorage(restoring: StoredCounterReducer.State(value: 42))

        _ = Store(reducer: StoredCounterReducer(), default: .init(), storage: recording)

        XCTAssertEqual(recording.saves, [])
    }

    // MARK: - Saving

    func testStateIsSavedAfterEveryActionInOrder() async throws {
        let recording = RecordingStorage<StoredCounterReducer.State>()
        let store = Store(reducer: StoredCounterReducer(), default: .init(), storage: recording)

        store.send(.increment)
        store.send(.increment)
        store.send(.decrement)

        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 4 }
        // The default state saved during init, then one save per action.
        XCTAssertEqual(recording.saves.map(\.value), [0, 1, 2, 1])
    }

    func testSavesAfterActionsRunOffTheMainThread() async throws {
        let recording = RecordingStorage(restoring: StoredCounterReducer.State())
        let store = Store(reducer: StoredCounterReducer(), default: .init(), storage: recording)

        store.send(.increment)
        store.send(.increment)

        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 2 }
        XCTAssertEqual(recording.savesOnMainThread, [false, false])
    }

    func testNextStoreOnSameStorageContinuesFromSavedState() async throws {
        let memory = InMemoryStorage<StoredCounterReducer.State>()
        let first = Store(reducer: StoredCounterReducer(), default: .init(), storage: memory)
        first.send(.increment)
        first.send(.increment)
        try await waitForStateChange(timeout: 2.0) { memory.value?.value == 2 }

        let second = Store(reducer: StoredCounterReducer(), default: .init(), storage: memory)

        XCTAssertEqual(second.state.value, 2)
    }

    // MARK: - Independence

    func testStoresWithSameStateTypePersistIndependently() async throws {
        let firstMemory = InMemoryStorage<StoredCounterReducer.State>()
        let secondMemory = InMemoryStorage<StoredCounterReducer.State>()
        let first = Store(reducer: StoredCounterReducer(), default: .init(), storage: firstMemory)
        let second = Store(reducer: StoredCounterReducer(), default: .init(), storage: secondMemory)

        first.send(.increment)
        first.send(.increment)
        second.send(.decrement)

        try await waitForStateChange(timeout: 2.0) {
            firstMemory.value?.value == 2 && secondMemory.value?.value == -1
        }
        XCTAssertEqual(firstMemory.value?.value, 2)
        XCTAssertEqual(secondMemory.value?.value, -1)
    }

    // MARK: - InMemoryStorage

    func testInMemoryStorageHoldsInitialValueUntilSaved() {
        let memory = InMemoryStorage(StoredCounterReducer.State(value: 1))
        XCTAssertEqual(memory.load(), .init(value: 1))

        memory.save(.init(value: 2))

        XCTAssertEqual(memory.value, .init(value: 2))
        XCTAssertEqual(memory.load(), .init(value: 2))
    }

    func testInMemoryStorageIsEmptyByDefault() {
        let memory = InMemoryStorage<StoredCounterReducer.State>()

        XCTAssertNil(memory.value)
        XCTAssertNil(memory.load())
    }
}
