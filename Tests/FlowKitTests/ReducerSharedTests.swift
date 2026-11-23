import Testing
@testable import FlowKit

/// Test reducer that accesses shared store state
struct CounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
    }

    enum Action: Equatable {
        case increment
        case reset
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .reset:
            state = .init()
            return .none
        }
    }
}

/// Test reducer that uses shared state
struct DependentReducer: Reducer {
    struct State: Equatable {
        var total: Int = 0
    }

    enum Action: Equatable {
        case updateFromShared
        case reset
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .updateFromShared:
            // Access shared counter state
            let counterState = shared(\StoreValues.counterStore)
            state.total = counterState.count * 2
            return .none
        case .reset:
            state = .init()
            return .none
        }
    }
}

/// StoreKey for CounterStore
struct CounterStoreKey: StoreKey {
    @MainActor static let defaultValue: Store<CounterReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}

/// StoreKey for DependentStore
struct DependentStoreKey: StoreKey {
    @MainActor static let defaultValue: Store<DependentReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}

/// Extending StoreValues to provide computed properties
extension StoreValues {
    @MainActor
    var counterStore: Store<CounterReducer> {
        get { self[CounterStoreKey.self] }
        set { self[CounterStoreKey.self] = newValue }
    }

    @MainActor
    var dependentStore: Store<DependentReducer> {
        get { self[DependentStoreKey.self] }
        set { self[DependentStoreKey.self] = newValue }
    }
}

// Serialized: tests reset and mutate the process-wide `CounterStoreKey` / `DependentStoreKey` default stores.
@Suite(.serialized)
@MainActor
struct ReducerSharedTests {

    /// Test that a reducer can access shared store state
    @Test func `Reducer can access shared state`() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)
        
        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Update counter
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        #expect(counterStore.wrappedValue.state.count == 3)

        // Update dependent store which reads from counter
        dependentStore.wrappedValue.send(.updateFromShared)

        #expect(dependentStore.wrappedValue.state.total == 6, "Expected total to be 6 (count * 2)")
    }

    /// Test that shared state is read-only and updates dynamically
    @Test func `Shared state updates dynamically`() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)
        
        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Initial update
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)

        #expect(dependentStore.wrappedValue.state.total == 2)

        // Counter changes
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        // Dependent reads again
        dependentStore.wrappedValue.send(.updateFromShared)

        #expect(dependentStore.wrappedValue.state.total == 6)
    }

    /// Test that multiple reducers can read from the same shared store
    @Test func `Multiple reducers read same shared store`() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore1 = Shared(\StoreValues.dependentStore)
        let dependentStore2 = Shared(\StoreValues.dependentStore)

        counterStore.wrappedValue.send(.reset)
        dependentStore1.wrappedValue.send(.reset)

        // Set counter to 5
        for _ in 0..<5 {
            counterStore.wrappedValue.send(.increment)
        }

        // Both dependent stores read the same shared state
        dependentStore1.wrappedValue.send(.updateFromShared)
        dependentStore2.wrappedValue.send(.updateFromShared)

        #expect(dependentStore1.wrappedValue.state.total == 10)
        #expect(dependentStore2.wrappedValue.state.total == 10)
        #expect(dependentStore1.wrappedValue.state.total == dependentStore2.wrappedValue.state.total)
    }

    /// Test that shared state reflects immediate changes
    @Test func `Shared state reflects immediate changes`() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)

        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Before any increment
        dependentStore.wrappedValue.send(.updateFromShared)
        #expect(dependentStore.wrappedValue.state.total == 0)

        // After one increment
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)
        #expect(dependentStore.wrappedValue.state.total == 2)

        // After another increment
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)
        #expect(dependentStore.wrappedValue.state.total == 4)
    }

    /// Test that reset action properly resets state to initial values
    @Test func `Reset action resets to initial state`() {
        let counterStore = Shared(\StoreValues.counterStore)

        counterStore.wrappedValue.send(.reset)

        // Increment counter
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        #expect(counterStore.wrappedValue.state.count == 3)

        // Reset should bring it back to 0
        counterStore.wrappedValue.send(.reset)

        #expect(counterStore.wrappedValue.state.count == 0)
    }

    /// Test that dependent store correctly calculates based on shared state at different values
    @Test func `Dependent calculation at different values`() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)

        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        let testValues = [0, 1, 5, 10, 100]

        for expectedCount in testValues {
            // Reset and set counter to expected value
            counterStore.wrappedValue.send(.reset)
            for _ in 0..<expectedCount {
                counterStore.wrappedValue.send(.increment)
            }

            // Dependent should calculate as count * 2
            dependentStore.wrappedValue.send(.updateFromShared)

            #expect(counterStore.wrappedValue.state.count == expectedCount)
            #expect(dependentStore.wrappedValue.state.total == expectedCount * 2)
        }
    }

    /// Test that shared stores are independent from local store instances
    @Test func `Shared stores are globally accessible`() {
        let counterStore1 = Shared(\StoreValues.counterStore)

        // Modify through first reference
        counterStore1.wrappedValue.send(.reset)
        counterStore1.wrappedValue.send(.increment)
        counterStore1.wrappedValue.send(.increment)

        // Create new reference and verify it has the same state
        let counterStore2 = Shared(\StoreValues.counterStore)

        #expect(counterStore2.wrappedValue.state.count == 2)

        // Modify through second reference
        counterStore2.wrappedValue.send(.increment)

        // First reference should see the change
        #expect(counterStore1.wrappedValue.state.count == 3)
    }
}
