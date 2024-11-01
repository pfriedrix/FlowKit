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
        store.dispatch(.resetState)

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
}
