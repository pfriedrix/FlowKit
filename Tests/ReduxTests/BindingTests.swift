import XCTest
import SwiftUI
@testable import FlowKit

final class BindingTests: XCTestCase {
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
                state = State() // Скидання до початкового стану
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
    
    func createStore() -> Store<AppReducer> {
        return Store(initial: AppReducer.State(), reducer: AppReducer())
    }
    
    // Test the `binding(for:set:)` method to ensure it correctly reads the initial state.
    func testBindingGetsInitialState() {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Assert that the initial state value is read correctly
        XCTAssertEqual(binding.wrappedValue, "Initial State", "The binding should correctly return the initial state value.")
    }
    
    // Test the `binding(for:set:)` method to ensure it correctly sendes an action and updates the state.
    func testBindingUpdatesState() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        binding.wrappedValue = "Updated State"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the state is updated as expected
        XCTAssertEqual(store.state.someStateProperty, "Updated State", "The state should update when the binding is modified.")
    }
    
    // Test predefined action send using the binding.
    func testPredefinedActionDispatch() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: AppReducer.Action.updateSomeState("Direct Dispatch"))
        
        // Modify the binding's value (this value will be ignored, and the action will be triggered)
        binding.wrappedValue = "Ignored Value"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the state was updated by the predefined action
        XCTAssertEqual(store.state.someStateProperty, "Direct Dispatch", "The state should be updated by the predefined action.")
    }
    
    // Test that multiple bindings update independently.
    func testMultipleBindingsUpdateIndependently() async throws {
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
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that both state properties were updated independently
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "The string state should be updated independently.")
        XCTAssertEqual(store.state.anotherStateProperty, 42, "The integer state should be updated independently.")
    }
    
    // Test that bindings are isolated: changes in one binding do not affect another binding.
    func testBindingsAreIsolated() async throws {
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
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert only the string state was updated
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "Only the string state should be updated.")
        XCTAssertEqual(store.state.anotherStateProperty, 0, "The integer state should remain unaffected.")
        
        // Now modify the int binding
        intBinding.wrappedValue = 99
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert the integer state was updated, string remains the same
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "The string state should remain the same.")
        XCTAssertEqual(store.state.anotherStateProperty, 99, "The integer state should be updated.")
    }
    
    // MARK: - Test Complex Cases with Async Waits
    
    // Test binding with nested state and async send
    func testBindingWithNestedStateAsync() async throws {
        let store = createStore()
        
        // Create a binding for a deeply nested state property
        let nestedBinding = store.binding(for: \.nestedState.someDeepProperty, set: { newValue in
            AppReducer.Action.updateDeepNestedProperty(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        nestedBinding.wrappedValue = "Updated Deep Value"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the nested state was updated
        XCTAssertEqual(store.state.nestedState.someDeepProperty, "Updated Deep Value", "The deeply nested state should be updated.")
    }
    
    // Test binding updates with async send
    func testBindingUpdatesStateAsync() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: { newValue in
            AppReducer.Action.updateSomeState(newValue)
        })
        
        // Modify the binding's value (this should trigger an action)
        binding.wrappedValue = "Updated State"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the state is updated as expected
        XCTAssertEqual(store.state.someStateProperty, "Updated State", "The state should update after the binding is modified.")
    }
    
    // Test predefined action send with async state update
    func testPredefinedActionDispatchAsync() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty, set: AppReducer.Action.updateSomeState("Direct Dispatch"))
        
        // Modify the binding's value (this value will be ignored, and the action will be triggered)
        binding.wrappedValue = "Ignored Value"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the state was updated by the predefined action
        XCTAssertEqual(store.state.someStateProperty, "Direct Dispatch", "The state should be updated by the predefined action.")
    }
    
    // Test multiple bindings with async updates
    func testMultipleBindingsUpdateIndependentlyAsync() async throws {
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
        
        // Wait for both updates to be processed
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
        
        // Assert that both state properties were updated independently
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "The string state should be updated independently.")
        XCTAssertEqual(store.state.anotherStateProperty, 42, "The integer state should be updated independently.")
    }
    
    // Test that bindings are isolated with async state updates
    func testBindingsAreIsolatedAsync() async throws {
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
        
        // Wait for async send to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert only the string state was updated
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "Only the string state should be updated.")
        XCTAssertEqual(store.state.anotherStateProperty, 0, "The integer state should remain unaffected.")
        
        // Now modify the int binding
        intBinding.wrappedValue = 99
        
        // Wait for async send to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert the integer state was updated, string remains the same
        XCTAssertEqual(store.state.someStateProperty, "Updated String", "The string state should remain the same.")
        XCTAssertEqual(store.state.anotherStateProperty, 99, "The integer state should be updated.")
    }
    
    // Test the `binding(for:)` method to ensure it correctly reads the initial state without an action.
    func testBindingGetsInitialStateWithoutAction() {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty)
        
        // Assert that the initial state value is read correctly
        XCTAssertEqual(binding.wrappedValue, "Initial State", "The binding should correctly return the initial state value without an action.")
    }
    
    // Test the `binding(for:)` method to ensure it correctly updates the state without an action.
    func testBindingUpdatesStateWithoutAction() async throws {
        let store = createStore()
        
        let binding = store.binding(for: \.someStateProperty)
        
        // Modify the binding's value (this should update the state directly)
        binding.wrappedValue = "Updated State Without Action"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that the state is updated as expected
        XCTAssertEqual(store.state.someStateProperty, "Updated State Without Action", "The state should update directly when the binding is modified without an action.")
    }
    
    // Test that multiple bindings update independently without actions.
    func testMultipleBindingsUpdateIndependentlyWithoutAction() async throws {
        let store = createStore()
        
        // Create bindings for two different properties without actions
        let stringBinding = store.binding(for: \.someStateProperty)
        let intBinding = store.binding(for: \.anotherStateProperty)
        
        // Modify both bindings
        stringBinding.wrappedValue = "Updated String Without Action"
        intBinding.wrappedValue = 42
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert that both state properties were updated independently
        XCTAssertEqual(store.state.someStateProperty, "Updated String Without Action", "The string state should be updated independently without an action.")
        XCTAssertEqual(store.state.anotherStateProperty, 42, "The integer state should be updated independently without an action.")
    }
    
    // Test that bindings are isolated: changes in one binding do not affect another binding without actions.
    func testBindingsAreIsolatedWithoutAction() async throws {
        let store = createStore()
        
        // Create two bindings for separate properties without actions
        let stringBinding = store.binding(for: \.someStateProperty)
        let intBinding = store.binding(for: \.anotherStateProperty)
        
        // Modify the string binding first
        stringBinding.wrappedValue = "Updated String Without Action"
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert only the string state was updated
        XCTAssertEqual(store.state.someStateProperty, "Updated String Without Action", "Only the string state should be updated without an action.")
        XCTAssertEqual(store.state.anotherStateProperty, 0, "The integer state should remain unaffected without an action.")
        
        // Now modify the int binding
        intBinding.wrappedValue = 99
        
        // Wait for the state to be updated
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        
        // Assert the integer state was updated, string remains the same
        XCTAssertEqual(store.state.someStateProperty, "Updated String Without Action", "The string state should remain the same without an action.")
        XCTAssertEqual(store.state.anotherStateProperty, 99, "The integer state should be updated without an action.")
    }
}
