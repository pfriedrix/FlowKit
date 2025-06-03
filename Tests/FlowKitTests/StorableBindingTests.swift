import XCTest
import SwiftUI
@testable import FlowKit

final class StorableBindingTests: XCTestCase {

    struct AppReducer: Reducer {
        struct State: Equatable, Storable, Codable {
            var someStateProperty: String = "Initial State"
            var anotherStateProperty: Int = 0
            var booleanFlag: Bool = false
            var nestedState: NestedState = NestedState()

            struct NestedState: Equatable, Codable {
                var someDeepProperty: String = "Initial Deep State"
            }

            // MARK: - Storable Conformance
            func save() {
                if let data = try? JSONEncoder().encode(self) {
                    UserDefaults.standard.set(data, forKey: "AppState")
                }
            }

            static func load() -> State? {
                guard let data = UserDefaults.standard.data(forKey: "AppState"),
                      let state = try? JSONDecoder().decode(State.self, from: data) else {
                    return nil
                }
                return state
            }
        }

        enum Action {
            case updateSomeState(String)
            case updateAnotherState(Int)
            case updateBooleanFlag(Bool)
            case updateDeepNestedProperty(String)
            case resetState
            case complexMutation(someString: String, someInt: Int)
            case ignoreUpdate
        }

        @MainActor
        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .updateSomeState(let newValue):
                state.someStateProperty = newValue
                return .none

            case .updateAnotherState(let newValue):
                state.anotherStateProperty = newValue
                return .none

            case .updateBooleanFlag(let newValue):
                state.booleanFlag = newValue
                return .none

            case .updateDeepNestedProperty(let newValue):
                state.nestedState.someDeepProperty = newValue
                return .none

            case .resetState:
                state = State() // Reset to initial state
                return .none

            case .complexMutation(let someString, let someInt):
                state.someStateProperty = someString
                state.anotherStateProperty = someInt
                return .none

            case .ignoreUpdate:
                return .none
            }
        }
    }

    // MARK: - Test Helper Function
    
    @MainActor
    func createStore() -> Store<AppReducer> {
        return Store(reducer: AppReducer(), default: AppReducer.State())
    }

    override func setUp() {
        super.setUp()
        // Remove any previously saved state
        UserDefaults.standard.removeObject(forKey: "AppState")
    }

    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "AppState")
        super.tearDown()
    }

    // MARK: - Test Cases

    /// Test that the state is saved after an action updates it.
    @MainActor
    func testStateIsSavedAfterUpdate() async throws {
        let store = createStore()

        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })

        // Modify the binding's value (this should trigger an action and save the state)
        binding.wrappedValue = "Updated State"

        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)

        // Ensure the state is saved in UserDefaults
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "Updated State", "The state should be saved after the binding is modified.")
    }

    /// Test that the state is reset and saved after a reset action.
    @MainActor
    func testStateResetAndSaved() async throws {
        let store = createStore()

        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })

        // Modify the binding's value
        binding.wrappedValue = "Temporary State"
        
        // Wait for the state to be reset
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Dispatch the reset action
        store.send(.resetState)

        // Ensure the state is reset and saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "Initial State", "The state should be reset to the initial state.")
    }

    /// Test that multiple updates are saved independently.
    @MainActor
    func testMultipleUpdatesAreSaved() async throws {
        let store = createStore()

        // Create bindings for two different properties
        let stringBinding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        let intBinding = store.binding(for: \.anotherStateProperty, set: { newValue in
            AppReducer.Action.updateAnotherState(newValue)
        })

        // Modify both bindings
        stringBinding.wrappedValue = "Updated String"
        intBinding.wrappedValue = 42

        // Wait for both updates to be saved
        try await Task.sleep(nanoseconds: 100_000_000)

        // Ensure the state is saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "Updated String", "The string state should be updated and saved.")
        XCTAssertEqual(savedState?.anotherStateProperty, 42, "The integer state should be updated and saved.")
    }

    /// Test that deeply nested state is saved after being updated.
    @MainActor
    func testNestedStateIsSaved() async throws {
        let store = createStore()

        // Create a binding for a deeply nested state property
        let nestedBinding = store.binding(for: \.nestedState.someDeepProperty, set: { newValue in
            AppReducer.Action.updateDeepNestedProperty(newValue)
        })

        // Modify the binding's value (this should trigger an action and save the state)
        nestedBinding.wrappedValue = "Updated Deep Value"

        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)

        // Ensure the deeply nested state is saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.nestedState.someDeepProperty, "Updated Deep Value", "The deeply nested state should be saved.")
    }
    
    // MARK: - Custom Getter Binding Tests for Storable State
    
    /// Test custom getter binding saves state correctly
    @MainActor
    func testCustomGetterBindingSavesState() async throws {
        let store = createStore()
        let multiplier = 2
        
        // Create a custom getter binding that transforms the value using state-aware version
        let binding = store.binding(
            get: { state in state.anotherStateProperty * multiplier },
            set: { newValue in
                AppReducer.Action.updateAnotherState(newValue / multiplier)
            }
        )
        
        // Update through the binding
        binding.wrappedValue = 100
        
        // Wait for the state to be updated and saved
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify the state was saved correctly
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.anotherStateProperty, 50, "The state should be saved with the correct value (100 / 2 = 50).")
        
        // Verify the binding still works correctly
        XCTAssertEqual(binding.wrappedValue, 100, "The binding should return the transformed value (50 * 2 = 100).")
    }
    
    /// Test state-aware custom getter binding with complex conditions
    @MainActor
    func testStateAwareCustomGetterBindingSavesState() async throws {
        let store = createStore()
        
        // Create a binding that combines state properties
        let binding = store.binding(
            get: { state in
                state.booleanFlag ? state.someStateProperty : "Default"
            },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )
        
        // Initially returns "Default" because booleanFlag is false
        XCTAssertEqual(binding.wrappedValue, "Default", "The binding should return default when flag is false.")
        
        // Update the boolean flag
        store.send(.updateBooleanFlag(true))
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Now returns the actual state property
        XCTAssertEqual(binding.wrappedValue, "Initial State", "The binding should return state property when flag is true.")
        
        // Update through the binding
        binding.wrappedValue = "New Value"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify the state was saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "New Value", "The state should be saved with the new value.")
        XCTAssertEqual(savedState?.booleanFlag, true, "The boolean flag should remain true.")
    }
    
    /// Test multiple custom getter bindings working together with persistence
    @MainActor
    func testMultipleCustomGetterBindingsPersistence() async throws {
        let store = createStore()
        
        // First binding: transforms string values
        let stringBinding = store.binding(
            get: { state in state.someStateProperty.lowercased() },
            set: { newValue in AppReducer.Action.updateSomeState(newValue.uppercased()) }
        )
        
        // Second binding: transforms numeric values
        let intBinding = store.binding(
            get: { state in state.anotherStateProperty + 1000 },
            set: { newValue in AppReducer.Action.updateAnotherState(newValue - 1000) }
        )
        
        // Update through both bindings
        stringBinding.wrappedValue = "hello world"
        intBinding.wrappedValue = 1042
        
        // Wait for updates to be saved
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify both values were saved correctly
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "HELLO WORLD", "String should be saved as uppercase.")
        XCTAssertEqual(savedState?.anotherStateProperty, 42, "Integer should be saved with offset removed.")
        
        // Verify bindings still work correctly with saved state
        XCTAssertEqual(stringBinding.wrappedValue, "hello world", "String binding should return lowercase.")
        XCTAssertEqual(intBinding.wrappedValue, 1042, "Integer binding should return with offset added.")
    }
    
    /// Test simple custom getter binding without state access
    @MainActor
    func testSimpleCustomGetterBinding() async throws {
        let store = createStore()
        
        struct SomeValue {
            var value = "Fixed Value"
        }
        
        let value = SomeValue()
        
        // Create a binding with a custom getter that returns a constant
        let binding = store.binding(
            get: { value.value },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )
        
        // Test that the binding returns the custom value
        XCTAssertEqual(binding.wrappedValue, "Fixed Value", "The binding should return the custom getter value.")
        
        // Update through the binding
        binding.wrappedValue = "New State Value"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify the state was saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.someStateProperty, "New State Value", "The state should be saved with the new value.")
        
        // The getter still returns the fixed value
        XCTAssertEqual(binding.wrappedValue, "Fixed Value", "The binding should still return the fixed value.")
    }
    
    /// Test custom getter with computed constants
    @MainActor
    func testCustomGetterWithComputedConstants() async throws {
        let store = createStore()
        let baseValue = 100
        let multiplier = 3
        
        // Create a binding that computes from constants
        let binding = store.binding(
            get: { baseValue * multiplier },
            set: { newValue in
                AppReducer.Action.updateAnotherState(newValue)
            }
        )
        
        // Test the computed value
        XCTAssertEqual(binding.wrappedValue, 300, "The binding should return the computed constant (100 * 3).")
        
        // Update through the binding
        binding.wrappedValue = 150
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify the state was saved
        let savedState = AppReducer.State.load()
        XCTAssertEqual(savedState?.anotherStateProperty, 150, "The state should be saved with the new value.")
        
        // The getter still returns the computed constant
        XCTAssertEqual(binding.wrappedValue, 300, "The binding should still return the computed constant.")
    }
    
    /// Test mixing simple and state-aware custom getter bindings
    @MainActor
    func testMixedCustomGetterBindings() async throws {
        let store = createStore()
        
        final class TestClass: Sendable {
            let value: String = "Constant"
        }
        
        let testClass = TestClass()
        
        // Simple custom getter (no state access)
        let simpleBinding = store.binding(
            get: { testClass.value },
            set: { _ in AppReducer.Action.updateBooleanFlag(true) }
        )
        
        // State-aware custom getter
        let stateBinding = store.binding(
            get: { state in state.booleanFlag ? "Enabled" : "Disabled" },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )
        
        // Initially, booleanFlag is false
        XCTAssertEqual(simpleBinding.wrappedValue, "Constant", "Simple binding returns constant.")
        XCTAssertEqual(stateBinding.wrappedValue, "Disabled", "State binding shows disabled.")
        
        // Update through simple binding (sets booleanFlag to true)
        simpleBinding.wrappedValue = "Ignored"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify state was updated and saved
        let savedState1 = AppReducer.State.load()
        XCTAssertEqual(savedState1?.booleanFlag, true, "Boolean flag should be true.")
        XCTAssertEqual(stateBinding.wrappedValue, "Enabled", "State binding should now show enabled.")
        
        // Update through state binding
        stateBinding.wrappedValue = "Updated Text"
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify both states were saved
        let savedState2 = AppReducer.State.load()
        XCTAssertEqual(savedState2?.someStateProperty, "Updated Text", "Text should be updated.")
        XCTAssertEqual(savedState2?.booleanFlag, true, "Boolean flag should remain true.")
    }
}
