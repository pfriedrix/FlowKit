import XCTest
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
    static let defaultValue: Store<CounterReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}

/// StoreKey for DependentStore
struct DependentStoreKey: StoreKey {
    static let defaultValue: Store<DependentReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}

/// Extending StoreValues to provide computed properties
extension StoreValues {
    var counterStore: Store<CounterReducer> {
        get { self[CounterStoreKey.self] }
        set { self[CounterStoreKey.self] = newValue }
    }

    var dependentStore: Store<DependentReducer> {
        get { self[DependentStoreKey.self] }
        set { self[DependentStoreKey.self] = newValue }
    }
}

@MainActor
final class ReducerSharedTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    /// Test that a reducer can access shared store state
    func testReducerCanAccessSharedState() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)
        
        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Update counter
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        XCTAssertEqual(counterStore.wrappedValue.state.count, 3)

        // Update dependent store which reads from counter
        dependentStore.wrappedValue.send(.updateFromShared)

        XCTAssertEqual(dependentStore.wrappedValue.state.total, 6, "Expected total to be 6 (count * 2)")
    }

    /// Test that shared state is read-only and updates dynamically
    func testSharedStateUpdatesDynamically() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)
        
        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Initial update
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)

        XCTAssertEqual(dependentStore.wrappedValue.state.total, 2)

        // Counter changes
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        // Dependent reads again
        dependentStore.wrappedValue.send(.updateFromShared)

        XCTAssertEqual(dependentStore.wrappedValue.state.total, 6)
    }

    /// Test that multiple reducers can read from the same shared store
    func testMultipleReducersReadSameSharedStore() {
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

        XCTAssertEqual(dependentStore1.wrappedValue.state.total, 10)
        XCTAssertEqual(dependentStore2.wrappedValue.state.total, 10)
        XCTAssertEqual(dependentStore1.wrappedValue.state.total, dependentStore2.wrappedValue.state.total)
    }

    /// Test that shared state reflects immediate changes
    func testSharedStateReflectsImmediateChanges() {
        let counterStore = Shared(\StoreValues.counterStore)
        let dependentStore = Shared(\StoreValues.dependentStore)

        counterStore.wrappedValue.send(.reset)
        dependentStore.wrappedValue.send(.reset)

        // Before any increment
        dependentStore.wrappedValue.send(.updateFromShared)
        XCTAssertEqual(dependentStore.wrappedValue.state.total, 0)

        // After one increment
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)
        XCTAssertEqual(dependentStore.wrappedValue.state.total, 2)

        // After another increment
        counterStore.wrappedValue.send(.increment)
        dependentStore.wrappedValue.send(.updateFromShared)
        XCTAssertEqual(dependentStore.wrappedValue.state.total, 4)
    }

    /// Test that reset action properly resets state to initial values
    func testResetActionResetsToInitialState() {
        let counterStore = Shared(\StoreValues.counterStore)

        counterStore.wrappedValue.send(.reset)

        // Increment counter
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)
        counterStore.wrappedValue.send(.increment)

        XCTAssertEqual(counterStore.wrappedValue.state.count, 3)

        // Reset should bring it back to 0
        counterStore.wrappedValue.send(.reset)

        XCTAssertEqual(counterStore.wrappedValue.state.count, 0)
    }

    /// Test that dependent store correctly calculates based on shared state at different values
    func testDependentCalculationAtDifferentValues() {
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

            XCTAssertEqual(counterStore.wrappedValue.state.count, expectedCount)
            XCTAssertEqual(dependentStore.wrappedValue.state.total, expectedCount * 2)
        }
    }

    /// Test that shared stores are independent from local store instances
    func testSharedStoresAreGloballyAccessible() {
        let counterStore1 = Shared(\StoreValues.counterStore)

        // Modify through first reference
        counterStore1.wrappedValue.send(.reset)
        counterStore1.wrappedValue.send(.increment)
        counterStore1.wrappedValue.send(.increment)

        // Create new reference and verify it has the same state
        let counterStore2 = Shared(\StoreValues.counterStore)

        XCTAssertEqual(counterStore2.wrappedValue.state.count, 2)

        // Modify through second reference
        counterStore2.wrappedValue.send(.increment)

        // First reference should see the change
        XCTAssertEqual(counterStore1.wrappedValue.state.count, 3)
    }
}
