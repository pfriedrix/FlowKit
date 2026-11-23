import Testing
import SwiftUI
@testable import FlowKit

/// Bindings on a store that persists its state: writing through a binding
/// dispatches the action, and the resulting state reaches the persistence.
struct PersistedBindingTests {

    struct AppReducer: Reducer {
        struct State: Equatable {
            var someStateProperty: String = "Initial State"
            var anotherStateProperty: Int = 0
            var booleanFlag: Bool = false
            var nestedState: NestedState = NestedState()

            struct NestedState: Equatable {
                var someDeepProperty: String = "Initial Deep State"
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

    /// Where the store under test saves its state. Fresh for every test:
    /// Swift Testing creates one suite instance per test function.
    private let memory = InMemoryPersistence<AppReducer.State>()

    @MainActor
    func createStore() -> Store<AppReducer> {
        return Store(reducer: AppReducer(), default: AppReducer.State(), persistence: memory)
    }

    // MARK: - Test Cases

    /// `binding(for:set: Action)` dispatches a fixed action regardless of the
    /// new value the SwiftUI binding was written with, and persists the result.
    @MainActor
    @Test func `Direct action binding dispatches fixed action and persists`() async throws {
        let store = createStore()
        let binding = store.binding(
            for: \.someStateProperty,
            set: AppReducer.Action.updateSomeState("Fixed")
        )

        #expect(binding.wrappedValue == "Initial State")

        binding.wrappedValue = "ignored by setter"

        try await waitForStateChange(timeout: 5.0) {
            store.state.someStateProperty == "Fixed"
        }
        #expect(store.state.someStateProperty == "Fixed")

        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "Fixed"
        }
        #expect(memory.value?.someStateProperty == "Fixed")
    }

    /// Test that the state is saved after an action updates it.
    @MainActor
    @Test func `State is saved after update`() async throws {
        let store = createStore()

        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })

        // Modify the binding's value (this should trigger an action and save the state)
        binding.wrappedValue = "Updated State"

        // Wait for the state to be saved
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "Updated State"
        }

        // Ensure the state is saved
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "Updated State", "The state should be saved after the binding is modified.")
    }

    /// Test that the state is reset and saved after a reset action.
    @MainActor
    @Test func `State reset and saved`() async throws {
        let store = createStore()

        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })

        // Modify the binding's value
        binding.wrappedValue = "Temporary State"

        // Wait for the temporary state to be saved
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "Temporary State"
        }

        // Dispatch the reset action
        store.send(.resetState)

        // Wait for the reset state to be saved
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "Initial State"
        }

        // Ensure the state is reset and saved
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "Initial State", "The state should be reset to the initial state.")
    }

    /// Test that multiple updates are saved independently.
    @MainActor
    @Test func `Multiple updates are saved`() async throws {
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

        // Wait for both updates to be saved (the integer one is saved last)
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.anotherStateProperty == 42
        }

        // Ensure the state is saved
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "Updated String", "The string state should be updated and saved.")
        #expect(savedState?.anotherStateProperty == 42, "The integer state should be updated and saved.")
    }

    /// Test that deeply nested state is saved after being updated.
    @MainActor
    @Test func `Nested state is saved`() async throws {
        let store = createStore()

        // Create a binding for a deeply nested state property
        let nestedBinding = store.binding(for: \.nestedState.someDeepProperty, set: { newValue in
            AppReducer.Action.updateDeepNestedProperty(newValue)
        })

        // Modify the binding's value (this should trigger an action and save the state)
        nestedBinding.wrappedValue = "Updated Deep Value"

        // Wait for the state to be saved
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.nestedState.someDeepProperty == "Updated Deep Value"
        }

        // Ensure the deeply nested state is saved
        let savedState = memory.value
        #expect(savedState?.nestedState.someDeepProperty == "Updated Deep Value", "The deeply nested state should be saved.")
    }
    
    // MARK: - Custom Getter Binding Tests for Persisted State

    /// Setting via a custom-getter binding dispatches the inverse-transformed action and persists it.
    @MainActor
    @Test func `Custom getter binding persists inverse transformed value`() async throws {
        let store = createStore()

        let binding = store.binding(
            get: { state in state.anotherStateProperty * 2 },
            set: { newValue in
                AppReducer.Action.updateAnotherState(newValue / 2)
            }
        )

        binding.wrappedValue = 100

        try await waitForStateChange(timeout: 5.0) {
            store.state.anotherStateProperty == 50
        }
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.anotherStateProperty == 50
        }

        #expect(memory.value?.anotherStateProperty == 50)
    }

    /// The getter re-derives from current state, returning the forward-transformed value.
    @MainActor
    @Test func `Custom getter binding getter reflects transformed state`() async throws {
        let store = createStore()

        let binding = store.binding(
            get: { state in state.anotherStateProperty * 2 },
            set: { newValue in
                AppReducer.Action.updateAnotherState(newValue / 2)
            }
        )

        binding.wrappedValue = 100

        try await waitForStateChange(timeout: 5.0) {
            store.state.anotherStateProperty == 50
        }

        #expect(binding.wrappedValue == 100)
    }
    
    /// Test state-aware custom getter binding with complex conditions
    @MainActor
    @Test func `State aware custom getter binding saves state`() async throws {
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
        #expect(binding.wrappedValue == "Default", "The binding should return default when flag is false.")
        
        // Update the boolean flag
        store.send(.updateBooleanFlag(true))
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.booleanFlag == true
        }

        // Now returns the actual state property
        #expect(binding.wrappedValue == "Initial State", "The binding should return state property when flag is true.")

        // Update through the binding
        binding.wrappedValue = "New Value"
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "New Value"
        }

        // Verify the state was saved
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "New Value", "The state should be saved with the new value.")
        #expect(savedState?.booleanFlag == true, "The boolean flag should remain true.")
    }
    
    /// Test multiple custom getter bindings working together with persistence
    @MainActor
    @Test func `Multiple custom getter bindings persistence`() async throws {
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

        // Wait for updates to be saved (the integer one is saved last)
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.anotherStateProperty == 42
        }

        // Verify both values were saved correctly
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "HELLO WORLD", "String should be saved as uppercase.")
        #expect(savedState?.anotherStateProperty == 42, "Integer should be saved with offset removed.")
        
        // Verify bindings still work correctly with saved state
        #expect(stringBinding.wrappedValue == "hello world", "String binding should return lowercase.")
        #expect(intBinding.wrappedValue == 1042, "Integer binding should return with offset added.")
    }
    
    /// Test simple custom getter binding without state access
    @MainActor
    @Test func `Simple custom getter binding`() async throws {
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
        #expect(binding.wrappedValue == "Fixed Value", "The binding should return the custom getter value.")
        
        // Update through the binding
        binding.wrappedValue = "New State Value"
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "New State Value"
        }

        // Verify the state was saved
        let savedState = memory.value
        #expect(savedState?.someStateProperty == "New State Value", "The state should be saved with the new value.")
        
        // The getter still returns the fixed value
        #expect(binding.wrappedValue == "Fixed Value", "The binding should still return the fixed value.")
    }
    
    /// Test custom getter with computed constants
    @MainActor
    @Test func `Custom getter with computed constants`() async throws {
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
        #expect(binding.wrappedValue == 300, "The binding should return the computed constant (100 * 3).")
        
        // Update through the binding
        binding.wrappedValue = 150
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.anotherStateProperty == 150
        }

        // Verify the state was saved
        let savedState = memory.value
        #expect(savedState?.anotherStateProperty == 150, "The state should be saved with the new value.")
        
        // The getter still returns the computed constant
        #expect(binding.wrappedValue == 300, "The binding should still return the computed constant.")
    }
    
    /// Test mixing simple and state-aware custom getter bindings
    @MainActor
    @Test func `Mixed custom getter bindings`() async throws {
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
        #expect(simpleBinding.wrappedValue == "Constant", "Simple binding returns constant.")
        #expect(stateBinding.wrappedValue == "Disabled", "State binding shows disabled.")
        
        // Update through simple binding (sets booleanFlag to true)
        simpleBinding.wrappedValue = "Ignored"
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.booleanFlag == true
        }

        // Verify state was updated and saved
        let savedState1 = memory.value
        #expect(savedState1?.booleanFlag == true, "Boolean flag should be true.")
        #expect(stateBinding.wrappedValue == "Enabled", "State binding should now show enabled.")
        
        // Update through state binding
        stateBinding.wrappedValue = "Updated Text"
        try await waitForStateChange(timeout: 5.0) { [memory] in
            memory.value?.someStateProperty == "Updated Text"
        }

        // Verify both states were saved
        let savedState2 = memory.value
        #expect(savedState2?.someStateProperty == "Updated Text", "Text should be updated.")
        #expect(savedState2?.booleanFlag == true, "Boolean flag should remain true.")
    }
}
