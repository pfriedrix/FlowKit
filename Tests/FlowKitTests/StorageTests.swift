import XCTest
@testable import FlowKit

@MainActor
class StorageTests: XCTestCase {

    struct MockReducer: Reducer {
        struct State: Equatable {
            var value: Int
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

    // Test that state is saved after sending an action
    @MainActor
    func testStateSaving() async throws {
        // Given
        let memory = InMemoryStorage<MockReducer.State>()
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: initialState, storage: memory)
        store.send(.increment)

        // Then
        try await waitForStateChange(timeout: 2.0) { memory.value?.value == 1 }
        XCTAssertEqual(memory.value?.value, 1)
    }

    // Test that state is loaded from storage when initializing the store
    func testStateLoading() {
        // Given
        let memory = InMemoryStorage(MockReducer.State(value: 42))
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: MockReducer.State(value: 0), storage: memory)

        // Then
        XCTAssertEqual(store.state.value, 42)
    }

    // Test that state is correctly updated and saved after multiple actions
    @MainActor
    func testDispatchAndSave() async throws {
        // Given
        let recording = RecordingStorage<MockReducer.State>()
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: initialState, storage: recording)
        store.send(.increment)  // +1
        store.send(.increment)  // +1
        store.send(.decrement)  // -1

        // Then: one save for the default state, then one per action
        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 4 }
        XCTAssertEqual(recording.saves.last?.value, 1)
    }

    // Test that state defaults to the provided initial state if no saved state exists
    func testStateNotLoadedIfNoSavedStateExists() {
        // Given
        let memory = InMemoryStorage<MockReducer.State>()
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: MockReducer.State(value: 10), storage: memory)

        // Then
        XCTAssertEqual(store.state.value, 10)  // Default state should be used
    }

    @MainActor
    func testStateSavingAfterMultipleActions() async throws {
        // Given
        let recording = RecordingStorage<MockReducer.State>()
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: initialState, storage: recording)
        store.send(.increment)  // +1
        store.send(.increment)  // +1
        store.send(.decrement)  // -1

        // Then: one save for the default state, then one per action
        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 4 }
        XCTAssertEqual(recording.saves.last?.value, 1)  // 1 = 0 + 1 + 1 - 1
    }

    @MainActor
    func testStateLoadingAndFurtherDispatch() async throws {
        // Given
        let memory = InMemoryStorage(MockReducer.State(value: 10))  // Simulate a saved state
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, default: MockReducer.State(value: 0), storage: memory)
        store.send(.decrement)  // 10 -> 9

        // Then
        try await waitForStateChange(timeout: 2.0) { memory.value?.value == 9 }
        XCTAssertEqual(memory.value?.value, 9)
    }

    @MainActor
    func testEffectHandlingInReducer() async throws {
        struct EffectReducer: Reducer {
            struct State: Equatable {
                var value: Int
            }

            enum Action {
                case increment
                case triggerDecrement
                case decrement
            }

            func reduce(into state: inout State, action: Action) -> Effect<Action> {
                switch action {
                case .increment:
                    state.value += 1
                    return .send(.triggerDecrement)
                case .triggerDecrement:
                    return .send(.decrement)
                case .decrement:
                    state.value -= 1
                    return .none
                }
            }
        }

        // Given
        let recording = RecordingStorage<EffectReducer.State>()
        let initialState = EffectReducer.State(value: 0)
        let reducer = EffectReducer()

        // When
        let store = Store(reducer: reducer, default: initialState, storage: recording)
        store.send(.increment)  // +1, then trigger decrement -> -1

        // Then: one save for the default state, then one per action in the chain
        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 4 }
        XCTAssertEqual(recording.saves.last?.value, 0)  // Final value should be 0 after both increment and decrement
    }

    @MainActor
    func testNoNegativeStateValues() async throws {
        struct NonNegativeReducer: Reducer {
            struct State: Equatable {
                var value: Int
            }

            enum Action {
                case decrement
            }

            func reduce(into state: inout State, action: Action) -> Effect<Action> {
                switch action {
                case .decrement:
                    if state.value > 0 {
                        state.value -= 1
                    }
                    return .none
                }
            }
        }

        // Given
        let recording = RecordingStorage<NonNegativeReducer.State>()
        let initialState = NonNegativeReducer.State(value: 0)
        let reducer = NonNegativeReducer()

        // When
        let store = Store(reducer: reducer, default: initialState, storage: recording)
        store.send(.decrement)  // Try to decrement below zero

        // Then: one save for the default state, one for the action
        try await waitForStateChange(timeout: 2.0) { recording.saves.count == 2 }
        XCTAssertEqual(recording.saves.last?.value, 0)  // Value should remain 0
    }

    @MainActor
    func testAsyncEffectHandling_updatesInMemoryState() async throws {
        let memory = InMemoryStorage<AsyncEffectReducer.State>()
        let store = Store(reducer: AsyncEffectReducer(), default: .init(value: 0), storage: memory)
        store.send(.increment)

        try await waitForStateChange(timeout: 2.0) {
            store.state.value == 2
        }

        XCTAssertEqual(store.state.value, 2)
    }

    @MainActor
    func testAsyncEffectHandling_persistsFinalState() async throws {
        let memory = InMemoryStorage<AsyncEffectReducer.State>()
        let store = Store(reducer: AsyncEffectReducer(), default: .init(value: 0), storage: memory)
        store.send(.increment)

        try await waitForStateChange(timeout: 2.0) {
            memory.value?.value == 2
        }

        XCTAssertEqual(memory.value?.value, 2)
    }
}

private struct AsyncEffectReducer: Reducer {
    struct State: Equatable {
        var value: Int
    }

    enum Action {
        case increment
        case delayedIncrement
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.value += 1
            return .run(priority: .medium) { send in
                try await Task.sleep(nanoseconds: 500_000_000)
                await send(.delayedIncrement)
            }
        case .delayedIncrement:
            state.value += 1
            return .none
        }
    }
}
