import XCTest
@testable import FlowKit

class StorageTests: XCTestCase {
    
    struct MockReducer: Reducer {
        struct State: Storable, Codable, Equatable {
            var value: Int
            
            // Save the state to persistent storage
            func save() {
                if let data = try? JSONEncoder().encode(self) {
                    UserDefaults.standard.set(data, forKey: "MockState")
                }
            }
            
            // Load the state from persistent storage
            static func load() -> State? {
                guard let data = UserDefaults.standard.data(forKey: "MockState"),
                      let state = try? JSONDecoder().decode(State.self, from: data) else {
                    return nil
                }
                return state
            }
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
    
    // This runs before each test to ensure a clean slate.
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "MockState") // Clear saved state
        UserDefaults.standard.removeObject(forKey: "AsyncEffectState")
        UserDefaults.standard.removeObject(forKey: "EffectState")
        UserDefaults.standard.removeObject(forKey: "NonNegativeState")
    }
    
    // This runs after each test to clean up the state.
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "MockState") // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "AsyncEffectState")
        UserDefaults.standard.removeObject(forKey: "EffectState")
        UserDefaults.standard.removeObject(forKey: "NonNegativeState")
        super.tearDown()
    }
    
    // Test that state is saved after dispatching an action
    @MainActor
    func testStateSaving() {
        // Given
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()
        
        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.increment)
        
        // Then
        let savedState = MockReducer.State.load()
        XCTAssertEqual(savedState?.value, 1)
    }
    
    // Test that state is loaded from persistent storage when initializing the store
    @MainActor
    func testStateLoading() {
        // Given
        let savedState = MockReducer.State(value: 42)
        savedState.save() // Save the state in UserDefaults
        
        let reducer = MockReducer()
        
        // When
        let store = Store(reducer: reducer, defaultState: MockReducer.State(value: 0))
        
        // Then
        XCTAssertEqual(store.state.value, 42)
    }
    
    // Test that state is correctly updated and saved after multiple actions
    @MainActor
    func testDispatchAndSave() {
        // Given
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()
        
        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.increment)  // +1
        store.dispatch(.increment)  // +1
        store.dispatch(.decrement)  // -1
        
        // Then
        let savedState = MockReducer.State.load()
        XCTAssertEqual(savedState?.value, 1)
    }
    
    // Test that state defaults to the provided initial state if no saved state exists
    @MainActor
    func testStateNotLoadedIfNoSavedStateExists() {
        // Given
        let reducer = MockReducer()
        
        // Ensure no state is saved in UserDefaults
        UserDefaults.standard.removeObject(forKey: "MockState")
        
        // When
        let store = Store(reducer: reducer, defaultState: MockReducer.State(value: 10))
        
        // Then
        XCTAssertEqual(store.state.value, 10)  // Default state should be used
    }
    
    @MainActor
    func testStateSavingAfterMultipleActions() {
        // Given
        let initialState = MockReducer.State(value: 0)
        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.increment)  // +1
        store.dispatch(.increment)  // +1
        store.dispatch(.decrement)  // -1

        // Then
        let savedState = MockReducer.State.load()
        XCTAssertEqual(savedState?.value, 1)  // 1 = 0 + 1 + 1 - 1
    }

    @MainActor
    func testStateLoadingAndFurtherDispatch() {
        // Given
        let savedState = MockReducer.State(value: 10)
        savedState.save()  // Simulate a saved state

        let reducer = MockReducer()

        // When
        let store = Store(reducer: reducer, defaultState: MockReducer.State(value: 0))
        store.dispatch(.decrement)  // 10 -> 9

        // Then
        let updatedState = MockReducer.State.load()
        XCTAssertEqual(updatedState?.value, 9)
    }

    @MainActor
    func testEffectHandlingInReducer() {
        struct EffectReducer: Reducer {
            struct State: Storable, Codable, Equatable {
                var value: Int
                func save() {
                    if let data = try? JSONEncoder().encode(self) {
                        UserDefaults.standard.set(data, forKey: "EffectState")
                    }
                }
                static func load() -> State? {
                    guard let data = UserDefaults.standard.data(forKey: "EffectState"),
                          let state = try? JSONDecoder().decode(State.self, from: data) else {
                        return nil
                    }
                    return state
                }
            }

            enum Action {
                case increment
                case triggerDecrement
                case decrement
            }

            @MainActor
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
        let initialState = EffectReducer.State(value: 0)
        let reducer = EffectReducer()

        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.increment)  // +1, then trigger decrement -> -1

        // Then
        let savedState = EffectReducer.State.load()
        XCTAssertEqual(savedState?.value, 0)  // Final value should be 0 after both increment and decrement
    }

    @MainActor
    func testNoNegativeStateValues() {
        struct NonNegativeReducer: Reducer {
            struct State: Storable, Codable, Equatable {
                var value: Int
                func save() {
                    if let data = try? JSONEncoder().encode(self) {
                        UserDefaults.standard.set(data, forKey: "NonNegativeState")
                    }
                }
                static func load() -> State? {
                    guard let data = UserDefaults.standard.data(forKey: "NonNegativeState"),
                          let state = try? JSONDecoder().decode(State.self, from: data) else {
                        return nil
                    }
                    return state
                }
            }

            enum Action {
                case decrement
            }

            @MainActor
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
        let initialState = NonNegativeReducer.State(value: 0)
        let reducer = NonNegativeReducer()

        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.decrement)  // Try to decrement below zero

        // Then
        let savedState = NonNegativeReducer.State.load()
        XCTAssertEqual(savedState?.value, 0)  // Value should remain 0
    }

    @MainActor
    func testAsyncEffectHandling() async throws {
        struct AsyncEffectReducer: Reducer {
            struct State: Storable, Codable, Equatable {
                var value: Int
                func save() {
                    if let data = try? JSONEncoder().encode(self) {
                        UserDefaults.standard.set(data, forKey: "AsyncEffectState")
                    }
                }
                static func load() -> State? {
                    guard let data = UserDefaults.standard.data(forKey: "AsyncEffectState"),
                          let state = try? JSONDecoder().decode(State.self, from: data) else {
                        return nil
                    }
                    return state
                }
            }

            enum Action {
                case increment
                case delayedIncrement
            }

            @MainActor
            func reduce(into state: inout State, action: Action) -> Effect<Action> {
                switch action {
                case .increment:
                    state.value += 1
                    return .run(priority: .medium) { send in
                        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate 1-second delay
                        await send(.delayedIncrement)
                    }
                case .delayedIncrement:
                    state.value += 1
                    return .none
                }
            }
        }
        
        // Given
        let initialState = AsyncEffectReducer.State(value: 0)
        let reducer = AsyncEffectReducer()

        // When
        let store = Store(reducer: reducer, defaultState: initialState)
        store.dispatch(.increment)

        // Wait for 2 seconds to allow the async effect to complete
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Then
        let savedState = AsyncEffectReducer.State.load()
        XCTAssertEqual(savedState?.value, 2)  // 1 from increment + 1 from delayedIncrement
    }
}
