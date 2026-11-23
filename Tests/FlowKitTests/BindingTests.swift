import Foundation
import Testing
import SwiftUI
@testable import FlowKit

@MainActor
struct BindingTests {
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
                state = State()
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
        return Store(initial: AppReducer.State(), reducer: AppReducer())
    }
    
    // Test the `binding(for:set:)` method to ensure it correctly reads the initial state.
    @MainActor
    @Test func `Binding gets initial state`() {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Assert that the initial state value is read correctly
        #expect(binding.wrappedValue == "Initial State", "The binding should correctly return the initial state value.")
    }
    
    // Test the `binding(for:set:)` method to ensure it correctly sendes an action and updates the state.
    @MainActor
    @Test func `Binding updates state`() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        binding.wrappedValue = "Updated State"
        
        
        // Assert that the state is updated as expected
        #expect(store.state.someStateProperty == "Updated State", "The state should update when the binding is modified.")
    }
    
    // Test predefined action send using the binding.
    @MainActor
    @Test func `Predefined action dispatch`() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: AppReducer.Action.updateSomeState("Direct Dispatch"))
        
        // Modify the binding's value (this value will be ignored, and the action will be triggered)
        binding.wrappedValue = "Ignored Value"
        
        
        // Assert that the state was updated by the predefined action
        #expect(store.state.someStateProperty == "Direct Dispatch", "The state should be updated by the predefined action.")
    }
    
    // Test that multiple bindings update independently.
    @MainActor
    @Test func `Multiple bindings update independently`() async throws {
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
        
        
        // Assert that both state properties were updated independently
        #expect(store.state.someStateProperty == "Updated String", "The string state should be updated independently.")
        #expect(store.state.anotherStateProperty == 42, "The integer state should be updated independently.")
    }
    
    // Test that bindings are isolated: changes in one binding do not affect another binding.
    @MainActor
    @Test func `Bindings are isolated`() async throws {
        let store = createStore()
        
        // Create two bindings for separate properties
        let stringBinding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        let intBinding = store.binding(for: \.anotherStateProperty, set: { newValue in
            AppReducer.Action.updateAnotherState(newValue)
        })
        
        // Modify the string binding first
        stringBinding.wrappedValue = "Updated String"
        
        
        // Assert only the string state was updated
        #expect(store.state.someStateProperty == "Updated String", "Only the string state should be updated.")
        #expect(store.state.anotherStateProperty == 0, "The integer state should remain unaffected.")
        
        // Now modify the int binding
        intBinding.wrappedValue = 99
        
        
        // Assert the integer state was updated, string remains the same
        #expect(store.state.someStateProperty == "Updated String", "The string state should remain the same.")
        #expect(store.state.anotherStateProperty == 99, "The integer state should be updated.")
    }
    
    // MARK: - Test Complex Cases with Async Waits
    
    // Test binding with nested state and async send
    @MainActor
    @Test func `Binding with nested state async`() async throws {
        let store = createStore()
        
        // Create a binding for a deeply nested state property
        let nestedBinding = store.binding(for: \.nestedState.someDeepProperty, set: { newValue in
            AppReducer.Action.updateDeepNestedProperty(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        nestedBinding.wrappedValue = "Updated Deep Value"
        
        
        // Assert that the nested state was updated
        #expect(store.state.nestedState.someDeepProperty == "Updated Deep Value", "The deeply nested state should be updated.")
    }
    
    // Test binding updates with async send
    @MainActor
    @Test func `Binding updates state async`() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        binding.wrappedValue = "Updated State"
        
        
        // Assert that the state is updated as expected
        #expect(store.state.someStateProperty == "Updated State", "The state should update after the binding is modified.")
    }
    
    // Test predefined action send with async state update
    @MainActor
    @Test func `Predefined action dispatch async`() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: AppReducer.Action.updateSomeState("Direct Dispatch"))
        
        // Modify the binding's value (this value will be ignored, and the action will be triggered)
        binding.wrappedValue = "Ignored Value"
        
        
        // Assert that the state was updated by the predefined action
        #expect(store.state.someStateProperty == "Direct Dispatch", "The state should be updated by the predefined action.")
    }
    
    // Test multiple bindings with async updates
    @MainActor
    @Test func `Multiple bindings update independently async`() async throws {
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
        
        
        // Assert that both state properties were updated independently
        #expect(store.state.someStateProperty == "Updated String", "The string state should be updated independently.")
        #expect(store.state.anotherStateProperty == 42, "The integer state should be updated independently.")
    }
    
    // Test that bindings are isolated with async state updates
    @MainActor
    @Test func `Bindings are isolated async`() async throws {
        let store = createStore()
        
        // Create two bindings for separate properties
        let stringBinding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        let intBinding = store.binding(for: \.anotherStateProperty, set: { newValue in
            AppReducer.Action.updateAnotherState(newValue)
        })
        
        // Modify the string binding first
        stringBinding.wrappedValue = "Updated String"
        
        
        // Assert only the string state was updated
        #expect(store.state.someStateProperty == "Updated String", "Only the string state should be updated.")
        #expect(store.state.anotherStateProperty == 0, "The integer state should remain unaffected.")
        
        // Now modify the int binding
        intBinding.wrappedValue = 99
        
        
        // Assert the integer state was updated, string remains the same
        #expect(store.state.someStateProperty == "Updated String", "The string state should remain the same.")
        #expect(store.state.anotherStateProperty == 99, "The integer state should be updated.")
    }
    
    // MARK: - Custom Getter Binding Tests
    
    // Test simple custom getter binding without state access
    @MainActor
    @Test func `Custom getter binding returns constant from getter`() {
        let store = createStore()

        let binding = store.binding(
            get: { "Custom Value" },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )

        #expect(binding.wrappedValue == "Custom Value")
    }

    @MainActor
    @Test func `Custom getter binding setting value dispatches action`() async throws {
        let store = createStore()

        let binding = store.binding(
            get: { "Custom Value" },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )

        binding.wrappedValue = "Updated Value"

        try await waitForStateChange(timeout: 5.0) {
            store.state.someStateProperty == "Updated Value"
        }
        #expect(store.state.someStateProperty == "Updated Value")
    }

    @MainActor
    @Test func `Custom getter binding getter ignores state changes`() async throws {
        let store = createStore()

        let binding = store.binding(
            get: { "Custom Value" },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )

        binding.wrappedValue = "Updated Value"
        try await waitForStateChange(timeout: 5.0) {
            store.state.someStateProperty == "Updated Value"
        }

        #expect(binding.wrappedValue == "Custom Value")
    }
    
    // Test custom getter binding with transformation
    @MainActor
    @Test func `Custom getter binding with transformation`() async throws {
        let store = createStore()
        
        // First set some initial state
        store.send(.updateAnotherState(42))
        // Create a binding that transforms a value using the state-aware version
        let binding = store.binding(
            get: { state in
                // Transform the value using the provided state parameter
                "Value: \(state.anotherStateProperty * 2)"
            },
            set: { newValue in
                // Extract number from string and update
                if let range = newValue.range(of: "Value: "),
                   let number = Int(newValue[range.upperBound...]) {
                    return AppReducer.Action.updateAnotherState(number / 2)
                }
                return AppReducer.Action.ignoreUpdate
            }
        )
        
        // Test initial transformed value
        #expect(binding.wrappedValue == "Value: 84", "The binding should return the transformed value (42 * 2).")
        
        // Update through binding
        binding.wrappedValue = "Value: 100"
        // Verify the state was updated with inverse transformation
        #expect(store.state.anotherStateProperty == 50, "The state should be updated (100 / 2 = 50).")
        #expect(binding.wrappedValue == "Value: 100", "The binding should reflect the new value.")
    }
    
    // Test state-aware custom getter binding
    @MainActor
    @Test func `State aware custom getter binding`() async throws {
        let store = createStore()
        
        // Create a binding that combines multiple state properties
        let binding = store.binding(
            get: { state in
                "\(state.someStateProperty) - \(state.anotherStateProperty)"
            },
            set: { newValue in
                AppReducer.Action.updateSomeState(newValue)
            }
        )
        
        // Test initial combined value
        #expect(binding.wrappedValue == "Initial State - 0", "The binding should combine state properties correctly.")
        
        // Update the integer state directly
        store.send(.updateAnotherState(42))
        // Test that the binding reflects the updated state
        #expect(binding.wrappedValue == "Initial State - 42", "The binding should reflect state changes.")
        
        // Modify through the binding
        binding.wrappedValue = "New Value"
        // Assert that the state was updated
        #expect(store.state.someStateProperty == "New Value", "The state should be updated through the binding.")
        #expect(binding.wrappedValue == "New Value - 42", "The binding should show the updated combined value.")
    }
    
    // Test custom getter binding with conditions
    @MainActor
    @Test func `Custom getter binding with conditions`() async throws {
        let store = createStore()
        
        // Create a binding that applies custom conditions
        let binding = store.binding(
            get: { state in
                state.booleanFlag && state.anotherStateProperty > 10
            },
            set: { newValue in
                AppReducer.Action.updateBooleanFlag(newValue)
            }
        )
        
        // Initially false (booleanFlag is false, anotherStateProperty is 0)
        #expect(binding.wrappedValue == false, "The binding should return false when conditions are not met.")
        
        // Update boolean flag to true
        store.send(.updateBooleanFlag(true))
        // Still false because anotherStateProperty is 0
        #expect(binding.wrappedValue == false, "The binding should still return false when only one condition is met.")
        
        // Update anotherStateProperty to be > 10
        store.send(.updateAnotherState(15))
        // Now true because both conditions are met
        #expect(binding.wrappedValue == true, "The binding should return true when all conditions are met.")
        
        // Set to false through binding
        binding.wrappedValue = false
        // Verify booleanFlag was updated
        #expect(store.state.booleanFlag == false, "The boolean flag should be updated through the binding.")
        #expect(binding.wrappedValue == false, "The binding should return false after update.")
    }
    
    // Test custom getter binding with computed values
    @MainActor
    @Test func `Custom getter binding with computed values`() async throws {
        let store = createStore()
        
        // Create a binding that computes a value based on state
        let binding = store.binding(
            get: { state in
                state.anotherStateProperty * 2
            },
            set: { newValue in
                AppReducer.Action.updateAnotherState(newValue / 2)
            }
        )
        
        // Test initial computed value
        #expect(binding.wrappedValue == 0, "The binding should return the computed value (0 * 2 = 0).")
        
        // Update the state directly
        store.send(.updateAnotherState(10))
        // Test computed value
        #expect(binding.wrappedValue == 20, "The binding should return the computed value (10 * 2 = 20).")
        
        // Update through the binding
        binding.wrappedValue = 50
        // Verify the state was updated with the inverse calculation
        #expect(store.state.anotherStateProperty == 25, "The state should be updated with the inverse calculation (50 / 2 = 25).")
        #expect(binding.wrappedValue == 50, "The binding should return the new computed value (25 * 2 = 50).")
    }
    
    // Test custom getter binding with nested state access
    @MainActor
    @Test func `Custom getter binding with nested state`() async throws {
        let store = createStore()
        
        // Create a binding that accesses nested state with custom logic
        let binding = store.binding(
            get: { state in
                state.nestedState.someDeepProperty.uppercased()
            },
            set: { newValue in
                AppReducer.Action.updateDeepNestedProperty(newValue.lowercased())
            }
        )
        
        // Test initial value transformation
        #expect(binding.wrappedValue == "INITIAL DEEP STATE", "The binding should return the uppercased value.")
        
        // Update through the binding
        binding.wrappedValue = "NEW DEEP VALUE"
        // Verify the state was updated with lowercase
        #expect(store.state.nestedState.someDeepProperty == "new deep value", "The state should be updated with lowercase.")
        #expect(binding.wrappedValue == "NEW DEEP VALUE", "The binding should return the uppercased value.")
    }
}
