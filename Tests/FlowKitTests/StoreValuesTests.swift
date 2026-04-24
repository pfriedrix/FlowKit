import XCTest
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

@MainActor
final class SharedTests: XCTestCase {
    var storeValues = StoreValues()

    override func setUp() {
        super.setUp()
    }

    /// Ensures that the Shared property wrapper initializes correctly.
    func testSharedInitialization() {
        let shared = Shared(\StoreValues.dummyStore) // Using the computed property
        XCTAssertEqual(shared.wrappedValue.state.value, 0, "Expected initial state value to be 0")
    }

    /// Ensures that state updates propagate correctly when an action is dispatched.
    func testSharedStateUpdate() {
        let shared = Shared(\StoreValues.dummyStore)
        let before = shared.wrappedValue.state.value
        shared.wrappedValue.send(.increment)
        XCTAssertEqual(shared.wrappedValue.state.value, before + 1, "Expected state value to increment by 1")
    }

    /// The `wrappedValue` setter swaps the wrapped store without affecting StoreValues.
    func testSharedWrappedValueSetter_replacesLocalReference() {
        var shared = Shared(\StoreValues.dummyStore)
        let original = shared.wrappedValue
        let replacement = Store(initial: DummyReducer.State(value: 999), reducer: DummyReducer())

        shared.wrappedValue = replacement

        XCTAssertTrue(shared.wrappedValue === replacement)
        XCTAssertFalse(shared.wrappedValue === original)
    }

    /// Ensures that multiple accesses to Shared retrieve the same store instance.
    func testSharedMultipleAccess() {
        let shared1 = Shared(\StoreValues.dummyStore)
        let shared2 = Shared(\StoreValues.dummyStore)

        shared1.wrappedValue.send(.increment)

        XCTAssertEqual(shared2.wrappedValue.state.value, 1, "Shared instances should reference the same store and have updated state")
    }
}
