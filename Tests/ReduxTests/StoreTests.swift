import XCTest
@testable import FlowKit

final class StoreTests: XCTestCase {
    
    var store: Store<TestReducer>!
    
    override func setUp() {
        super.setUp()
        let reducer = TestReducer()
        store = Store(initial: TestReducer.State(), reducer: reducer)
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // Utility function to wait for async state changes
    func waitForStateChange(timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = XCTestExpectation(description: "State change")
        
        // Poll the state periodically until the condition is met
        let pollInterval: TimeInterval = 0.05
        var elapsedTime: TimeInterval = 0
        _ = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            elapsedTime += pollInterval
            if condition() || elapsedTime >= timeout {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout + pollInterval)
    }
    
    // Test 1: Ensure the store initializes with the correct initial state.
    func testInitialState() {
        XCTAssertEqual(store.state.count, 0)
        XCTAssertEqual(store.state.message, "")
    }
    
    // Test 2: Ensure that the state is updated when an increment action is dispatched.
    @MainActor
    func testIncrementAction() throws {
        store.dispatch(.increment)
        
        // Wait for state change
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1
        }
        
        XCTAssertEqual(store.state.count, 1)
    }
    
    // Test 3: Ensure that the state is updated when a setMessage action is dispatched.
    @MainActor
    func testSetMessageAction() throws {
        store.dispatch(.setMessage("Hello, World!"))
        
        // Wait for state change
        waitForStateChange(timeout: 1.0) {
            self.store.state.message == "Hello, World!"
        }
        
        XCTAssertEqual(store.state.message, "Hello, World!")
    }
    
    // Test 4: Ensure that the state is updated correctly for a combined action (incrementAndSetMessage).
    @MainActor
    func testIncrementAndSetMessageAction() throws {
        store.dispatch(.incrementAndSetMessage("Updated"))
        
        // Wait for state change
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1 && self.store.state.message == "Updated"
        }
        
        XCTAssertEqual(store.state.count, 1)
        XCTAssertEqual(store.state.message, "Updated")
    }
    
    // Test 5: Ensure recursive actions are handled correctly (if the reducer returns further actions).
    @MainActor
    func testRecursiveActionHandling() throws {
        let reducer = RecursiveReducer()
        let recursiveStore = Store(initial: RecursiveReducer.State(), reducer: reducer)
        
        recursiveStore.dispatch(.triggerRecursion)
        
        // Wait for state change
        waitForStateChange(timeout: 2.0) {
            recursiveStore.state.value == 2
        }
        
        XCTAssertEqual(recursiveStore.state.value, 2)
    }
    
    // Test 6: Simultaneous dispatches should update the state concurrently.
    @MainActor
    func testConcurrentStateUpdates() throws {
        // Dispatch two actions concurrently
        Task {
            store.dispatch(.setMessage("Concurrent Update 1"))
        }
        
        Task {
            store.dispatch(.increment)
        }
        
        // Wait for state to reflect both changes
        waitForStateChange(timeout: 1.0) {
            self.store.state.message == "Concurrent Update 1" && self.store.state.count == 1
        }
        
        XCTAssertEqual(store.state.message, "Concurrent Update 1")
        XCTAssertEqual(store.state.count, 1)
    }
    
    // Test 7: Sequential updates with fast dispatch should update state correctly in order.
    @MainActor
    func testSequentialFastDispatch() throws {
        // Dispatch actions quickly in sequence
        store.dispatch(.increment)
        store.dispatch(.incrementAndSetMessage("Message After Two Increments"))
        store.dispatch(.increment)
        
        // Wait for the state to reflect all changes
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 3 && self.store.state.message == "Message After Two Increments"
        }
        
        XCTAssertEqual(store.state.count, 3)
        XCTAssertEqual(store.state.message, "Message After Two Increments")
    }
    
    // Test 8: Verify state integrity when multiple actions are dispatched at the same time.
    @MainActor
    func testStateIntegrityWithConcurrentDispatch() throws {
        // Dispatch two actions concurrently
        Task {
            store.dispatch(.setMessage("Concurrent Update 2"))
        }
        
        Task {
            store.dispatch(.incrementAndSetMessage("Updated Message"))
        }
        
        // Wait for both actions to take effect
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1 && self.store.state.message == "Updated Message"
        }

        XCTAssertEqual(store.state.count, 1)
        XCTAssertEqual(store.state.message, "Updated Message")
    }
    
    // Test 9: Multiple sequential actions modifying the same state value.
    @MainActor
    func testMultipleSequentialMessageUpdates() throws {
        // Dispatch multiple setMessage actions in sequence
        store.dispatch(.setMessage("First Message"))
        store.dispatch(.setMessage("Second Message"))
        store.dispatch(.setMessage("Third Message"))
        
        // Wait for the state to reflect the last update
        waitForStateChange(timeout: 1.0) {
            self.store.state.message == "Third Message"
        }
        
        XCTAssertEqual(store.state.message, "Third Message")
    }
    
    // Test 10: Race condition prevention: Dispatch multiple actions concurrently and ensure all updates are applied.
    @MainActor
    func testRaceConditionPrevention() throws {
        // Dispatch multiple actions concurrently
        Task {
            store.dispatch(.setMessage("Message 1"))
        }
        
        Task {
            store.dispatch(.setMessage("Message 2"))
        }
        
        Task {
            store.dispatch(.increment)
        }
        
        Task {
            store.dispatch(.increment)
        }
        
        // Wait for all changes to be reflected in the state
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 2 && (self.store.state.message == "Message 1" || self.store.state.message == "Message 2")
        }
        
        XCTAssertEqual(store.state.count, 2)
        XCTAssertTrue(store.state.message == "Message 1" || store.state.message == "Message 2")
    }
    
    // Test 1: Ensure async actions with side effects work correctly.
    @MainActor
    func testAsyncActionWithSideEffect() async throws {
        let reducer = SideEffectReducer()
        let store = Store(initial: SideEffectReducer.State(), reducer: reducer)

        // Dispatch an async action that triggers a side effect
        store.dispatch(.fetchData)

        // Wait for the side effect to complete
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Assert that the side effect updated the state
        XCTAssertEqual(store.state.data, "Update Data")
    }

    // Test 2: Concurrent async actions should resolve in the correct order.
    @MainActor
    func testConcurrentAsyncActions() async throws {
        let reducer = SideEffectReducer()
        let store = Store(initial: SideEffectReducer.State(), reducer: reducer)

        // Dispatch two async actions concurrently
        Task {
            store.dispatch(.fetchData)
        }
        
        Task {
            store.dispatch(.updateData("New Data"))
        }

        // Wait for a shorter time to allow `updateData` to complete before `fetchData` finishes
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

        // Assert that `fetchData` was handled correctly
        XCTAssertEqual(store.state.data, "New Data", "The state should reflect the result of the `updateData` action.")
    }

    // Test 3: Ensure that simultaneous state updates do not conflict.
    @MainActor
    func testSimultaneousStateUpdates() throws {
        let reducer = TestReducer()
        let store = Store(initial: TestReducer.State(), reducer: reducer)

        // Dispatch multiple actions simultaneously
        Task {
            store.dispatch(.setMessage("Message 1"))
        }

        Task {
            store.dispatch(.setMessage("Message 2"))
        }

        Task {
            store.dispatch(.increment)
        }

        // Wait for the state to reflect all changes
        waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1 && (self.store.state.message == "Message 1" || self.store.state.message == "Message 2")
        }

        XCTAssertEqual(store.state.count, 1)
        XCTAssertTrue(store.state.message == "Message 1" || store.state.message == "Message 2")
    }

    // Test 4: Ensure state updates can be rolled back if a condition is met.
    @MainActor
    func testActionRollback() async throws {
        let reducer = RollbackReducer()
        let store = Store(initial: RollbackReducer.State(), reducer: reducer)

        // Dispatch an action that triggers a rollback if a condition is met
        store.dispatch(.incrementWithCondition(shouldRollback: true))

        // Wait for the state update
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Assert that the rollback occurred
        XCTAssertEqual(store.state.count, 0, "The state should remain unchanged due to rollback.")
    }

    // Test 5: Ensure that state integrity is maintained during complex mutations.
    @MainActor
    func testComplexStateMutation() throws {
        let reducer = ComplexReducer()
        let store = Store(initial: ComplexReducer.State(), reducer: reducer)

        // Dispatch multiple complex actions in sequence
        store.dispatch(.complexMutation("Update 1", 10))
        store.dispatch(.complexMutation("Update 2", 20))

        // Wait for the state to reflect all changes
        waitForStateChange(timeout: 1.0) {
            store.state.someStateProperty == "Update 2" && store.state.anotherStateProperty == 20
        }

        XCTAssertEqual(store.state.someStateProperty, "Update 2")
        XCTAssertEqual(store.state.anotherStateProperty, 20)
    }

}

final class TestReducer: Reducer {
    struct State {
        var count: Int = 0
        var message: String = ""
    }
    
    enum Action {
        case increment
        case setMessage(String)
        case incrementAndSetMessage(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .setMessage(let newMessage):
            state.message = newMessage
            return .none
        case .incrementAndSetMessage(let newMessage):
            state.count += 1
            state.message = newMessage
            return .none
        }
    }
}

final class RecursiveReducer: Reducer {
    struct State {
        var value: Int = 0
    }
    
    enum Action {
        case triggerRecursion
        case increment
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .triggerRecursion:
            state.value += 1
            return .send(.increment)
        case .increment:
            state.value += 1
            return .none
        }
    }
}

final class SideEffectReducer: Reducer {
    struct State {
        var data: String = ""
    }
    
    enum Action {
        case fetchData
        case updateData(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fetchData:
            return .send(.updateData("Update Data"))
        case .updateData(let newData):
            state.data = newData
            return .none
        }
    }
}

final class RollbackReducer: Reducer {
    struct State {
        var count: Int = 0
    }
    
    enum Action {
        case incrementWithCondition(shouldRollback: Bool)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .incrementWithCondition(let shouldRollback):
            state.count += 1
            if shouldRollback {
                state.count -= 1
            }
            return .none
        }
    }
}

final class ComplexReducer: Reducer {
    struct State {
        var someStateProperty: String = "Initial"
        var anotherStateProperty: Int = 0
    }
    
    enum Action {
        case complexMutation(String, Int)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .complexMutation(let newString, let newInt):
            state.someStateProperty = newString
            state.anotherStateProperty = newInt
            return .none
        }
    }
}


