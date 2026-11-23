import Testing
@testable import FlowKit

// Tests for `Store(reducer:default:persistence:)` against `InMemoryPersistence` and `RecordingPersistence`:
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
struct PersistenceTests {

    // MARK: - Restoring

    @Test func `Store starts from state held by persistence`() {
        let memory = InMemoryPersistence(StoredCounterReducer.State(value: 42))

        let store = Store(reducer: StoredCounterReducer(), default: .init(), persistence: memory)

        #expect(store.state.value == 42)
    }

    @Test func `Store starts from default when persistence is empty`() {
        let memory = InMemoryPersistence<StoredCounterReducer.State>()

        let store = Store(reducer: StoredCounterReducer(), default: .init(value: 10), persistence: memory)

        #expect(store.state.value == 10)
    }

    @Test func `Default state is saved during init when persistence is empty`() {
        let memory = InMemoryPersistence<StoredCounterReducer.State>()

        _ = Store(reducer: StoredCounterReducer(), default: .init(value: 10), persistence: memory)

        #expect(memory.value == .init(value: 10))
    }

    @Test func `Restored state is not saved back during init`() {
        let recording = RecordingPersistence(restoring: StoredCounterReducer.State(value: 42))

        _ = Store(reducer: StoredCounterReducer(), default: .init(), persistence: recording)

        #expect(recording.saves == [])
    }

    // MARK: - Saving

    @Test func `State is saved after every action in order`() async throws {
        let recording = RecordingPersistence<StoredCounterReducer.State>()
        let store = Store(reducer: StoredCounterReducer(), default: .init(), persistence: recording)

        store.send(.increment)
        store.send(.increment)
        store.send(.decrement)

        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 4 }
        // The default state saved during init, then one save per action.
        #expect(recording.saves.map(\.value) == [0, 1, 2, 1])
    }

    @Test func `Saves after actions run off the main thread`() async throws {
        let recording = RecordingPersistence(restoring: StoredCounterReducer.State())
        let store = Store(reducer: StoredCounterReducer(), default: .init(), persistence: recording)

        store.send(.increment)
        store.send(.increment)

        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 2 }
        #expect(recording.savesOnMainThread == [false, false])
    }

    @Test func `Next store on same persistence continues from saved state`() async throws {
        let memory = InMemoryPersistence<StoredCounterReducer.State>()
        let first = Store(reducer: StoredCounterReducer(), default: .init(), persistence: memory)
        first.send(.increment)
        first.send(.increment)
        try await waitForStateChange(timeout: 2.0) { memory.value?.value == 2 }

        let second = Store(reducer: StoredCounterReducer(), default: .init(), persistence: memory)

        #expect(second.state.value == 2)
    }

    // MARK: - Independence

    @Test func `Stores with same state type persist independently`() async throws {
        let firstMemory = InMemoryPersistence<StoredCounterReducer.State>()
        let secondMemory = InMemoryPersistence<StoredCounterReducer.State>()
        let first = Store(reducer: StoredCounterReducer(), default: .init(), persistence: firstMemory)
        let second = Store(reducer: StoredCounterReducer(), default: .init(), persistence: secondMemory)

        first.send(.increment)
        first.send(.increment)
        second.send(.decrement)

        try await waitForStateChange(timeout: 2.0) {
            firstMemory.value?.value == 2 && secondMemory.value?.value == -1
        }
        #expect(firstMemory.value?.value == 2)
        #expect(secondMemory.value?.value == -1)
    }

    // MARK: - InMemoryPersistence

    @Test func `InMemoryPersistence holds initial value until saved`() {
        let memory = InMemoryPersistence(StoredCounterReducer.State(value: 1))
        #expect(memory.load() == .init(value: 1))

        memory.save(.init(value: 2))

        #expect(memory.value == .init(value: 2))
        #expect(memory.load() == .init(value: 2))
    }

    @Test func `InMemoryPersistence is empty by default`() {
        let memory = InMemoryPersistence<StoredCounterReducer.State>()

        #expect(memory.value == nil)
        #expect(memory.load() == nil)
    }
}
