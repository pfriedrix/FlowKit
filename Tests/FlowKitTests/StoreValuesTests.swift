import Testing
import SwiftUI
@testable import FlowKit

/// Dummy reducer for testing.
struct DummyReducer: Reducer {
    struct State: Equatable {
        var value: Int = 0
    }
    
    enum Action: Equatable {
        case increment
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.value += 1
            return .none
        }
    }
}

/// StoreKey for DummyStore.
struct DummyStoreKey: StoreKey {
    @MainActor static let defaultValue: Store<DummyReducer> = .init(initial: .init(), reducer: .init())
}

/// Extending StoreValues to provide a computed property like in EnvironmentValues
@MainActor
extension StoreValues {
    var dummyStore: Store<DummyReducer> {
        get { self[DummyStoreKey.self] }
        set { self[DummyStoreKey.self] = newValue }
    }
}

// Serialized: all tests share the process-wide `DummyStoreKey.defaultValue` store (`\StoreValues.dummyStore`).
// Expectations are relative to the store's current value, so they hold in any order.
@Suite(.serialized)
@MainActor
struct SharedTests {
    var storeValues = StoreValues()

    /// Ensures that the Shared property wrapper initializes correctly.
    @Test func `Shared initialization`() {
        let shared = Shared(\StoreValues.dummyStore) // Using the computed property
        #expect(shared.wrappedValue === DummyStoreKey.defaultValue, "Expected Shared to resolve the registry's default store")
    }

    /// Ensures that multiple accesses to Shared retrieve the same store instance.
    @Test func `Shared multiple access`() {
        let shared1 = Shared(\StoreValues.dummyStore)
        let shared2 = Shared(\StoreValues.dummyStore)
        let before = shared2.wrappedValue.state.value

        shared1.wrappedValue.send(.increment)

        #expect(shared2.wrappedValue.state.value == before + 1, "Shared instances should reference the same store and have updated state")
    }

    /// Ensures that state updates propagate correctly when an action is dispatched.
    @Test func `Shared state update`() {
        let shared = Shared(\StoreValues.dummyStore)
        let before = shared.wrappedValue.state.value
        shared.wrappedValue.send(.increment)
        #expect(shared.wrappedValue.state.value == before + 1, "Expected state value to increment by 1")
    }
}
