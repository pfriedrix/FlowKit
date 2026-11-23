import os
import Testing
@testable import FlowKit

@MainActor
struct StoreTests {
    var store: Store<TestReducer> = Store(initial: TestReducer.State(), reducer: TestReducer())
    
    init() {
        Logger.logLevel = .info
    }
    
    // Test 1: Ensure the store initializes with the correct initial state.
    @Test func `Initial state`() {
        #expect(store.state.count == 0)
        #expect(store.state.message == "")
    }
    
    // Test 2: Ensure that the state is updated when an increment action is sended.
    @Test func `Increment action`() async throws {
        store.send(.increment)
        
        // Wait for state change
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1
        }
        
        #expect(store.state.count == 1)
    }
    
    // Test 3: Ensure that the state is updated when a setMessage action is sended.
    @Test func `Set message action`() async throws {
        store.send(.setMessage("Hello, World!"))
        
        // Wait for state change
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.message == "Hello, World!"
        }
        
        #expect(store.state.message == "Hello, World!")
    }
    
    // Test 4: Ensure that the state is updated correctly for a combined action (incrementAndSetMessage).
    @Test func `Increment and set message action`() async throws {
        store.send(.incrementAndSetMessage("Updated"))
        
        // Wait for state change
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1 && self.store.state.message == "Updated"
        }
        
        #expect(store.state.count == 1)
        #expect(store.state.message == "Updated")
    }
    
    // Test 5: Ensure recursive actions are handled correctly (if the reducer returns further actions).
    @Test func `Recursive action handling`() async throws {
        let reducer = RecursiveReducer()
        let recursiveStore = Store(initial: RecursiveReducer.State(), reducer: reducer)
        
        recursiveStore.send(.triggerRecursion)
        
        // Wait for state change
        try await waitForStateChange(timeout: 2.0) {
            recursiveStore.state.value == 2
        }
        
        #expect(recursiveStore.state.value == 2)
    }
    
    // Test 7: Sequential updates with fast send should update state correctly in order.
    @Test func `Sequential fast dispatch`() async throws {
        // Dispatch actions quickly in sequence
        store.send(.increment)
        store.send(.incrementAndSetMessage("Message After Two Increments"))
        store.send(.increment)
        
        // Wait for the state to reflect all changes
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.count == 3 && self.store.state.message == "Message After Two Increments"
        }
        
        #expect(store.state.count == 3)
        #expect(store.state.message == "Message After Two Increments")
    }
    
    // Test 8: Verify state integrity when multiple actions are sended at the same time.
    @Test func `State integrity with concurrent dispatch`() async throws {
        // Dispatch two actions in rapid succession
        store.send(.setMessage("Concurrent Update 2"))
        store.send(.incrementAndSetMessage("Updated Message"))

        // Wait for both actions to take effect
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.count == 1 && self.store.state.message == "Updated Message"
        }

        #expect(store.state.count == 1)
        #expect(store.state.message == "Updated Message")
    }
    
    // Test 9: Multiple sequential actions modifying the same state value.
    @Test func `Multiple sequential message updates`() async throws {
        // Dispatch multiple setMessage actions in sequence
        store.send(.setMessage("First Message"))
        store.send(.setMessage("Second Message"))
        store.send(.setMessage("Third Message"))
        
        // Wait for the state to reflect the last update
        try await waitForStateChange(timeout: 1.0) {
            self.store.state.message == "Third Message"
        }
        
        #expect(store.state.message == "Third Message")
    }
    
    // Test 3: Ensure that simultaneous state updates do not conflict.
    @Test func `Simultaneous state updates`() async throws {
        let reducer = TestReducer()
        let store = Store(initial: TestReducer.State(), reducer: reducer)

        // Dispatch multiple actions in rapid succession
        store.send(.setMessage("Message 1"))
        store.send(.setMessage("Message 2"))
        store.send(.increment)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1 && store.state.message == "Message 2"
        }

        #expect(store.state.count == 1)
        #expect(store.state.message == "Message 2")
    }
    
    // Test 4: Ensure state updates can be rolled back if a condition is met.
    @Test func `Action rollback`() async throws {
        let reducer = RollbackReducer()
        let store = Store(initial: RollbackReducer.State(), reducer: reducer)
        
        // Dispatch an action that triggers a rollback if a condition is met
        store.send(.incrementWithCondition(shouldRollback: true))
        
        // Wait for the state update
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        
        // Assert that the rollback occurred
        #expect(store.state.count == 0, "The state should remain unchanged due to rollback.")
    }
    
    // Test 5: Ensure that state integrity is maintained during complex mutations.
    @Test func `Complex state mutation`() async throws {
        let reducer = ComplexReducer()
        let store = Store(initial: ComplexReducer.State(), reducer: reducer)
        
        // Dispatch multiple complex actions in sequence
        store.send(.complexMutation("Update 1", 10))
        store.send(.complexMutation("Update 2", 20))
        
        // Wait for the state to reflect all changes
        try await waitForStateChange(timeout: 1.0) {
            store.state.someStateProperty == "Update 2" && store.state.anotherStateProperty == 20
        }
        
        #expect(store.state.someStateProperty == "Update 2")
        #expect(store.state.anotherStateProperty == 20)
    }
    
    /// Swift Testing runs suites in parallel, and they all share MainActor. Thousands of
    /// synchronous sends in one go hold MainActor for over a second on CI, long enough for
    /// other suites' `waitForStateChange` timeouts to fire. Yield between bursts instead.
    /// A burst of 50 takes about 7ms on CI. The three tests that use this run at the
    /// same time, so a waiting test sits behind up to three bursts per MainActor hop.
    private func yieldAfterBurst(_ sent: Int) async {
        if sent.isMultiple(of: 50) {
            await Task.yield()
        }
    }

    @Test func `High frequency action dispatch`() async throws {
        // Dispatch a single action repeatedly at high frequency
        let repeatCount = 10_000
        for i in 1...repeatCount {
            store.send(.increment)
            await yieldAfterBurst(i)
        }
        
        // Wait for all actions to be processed
        try await waitForStateChange(timeout: 5.0) {
            self.store.state.count == repeatCount
        }
        
        // Validate that the state reflects all increments
        #expect(store.state.count == repeatCount, "The count should equal the number of repeated actions.")
    }
    
    @Test func `Mixed high frequency actions`() async throws {
        // Dispatch a mix of actions repeatedly at high frequency
        let repeatCount = 5_000
        for i in 0..<repeatCount {
            if i % 2 == 0 {
                store.send(.increment)
            } else {
                store.send(.setMessage("Message \(i)"))
            }
            await yieldAfterBurst(i + 1)
        }
        
        // Wait for all actions to be processed
        try await waitForStateChange(timeout: 10.0) {
            self.store.state.count == repeatCount / 2 && self.store.state.message == "Message \(repeatCount - 1)"
        }
        
        // Validate the final state
        #expect(store.state.count == repeatCount / 2, "The count should reflect half the total actions (increments).")
        #expect(store.state.message == "Message \(repeatCount - 1)", "The message should reflect the last setMessage action.")
    }
    
    @Test func `High frequency actions with interruptions`() async {
        let totalPrimaryActions = 10_000
        let interruptionInterval = 100

        for i in 1...totalPrimaryActions {
            store.send(.increment)
            if i.isMultiple(of: interruptionInterval) {
                store.send(.num)
            }
            await yieldAfterBurst(i)
        }

        #expect(store.state.count == totalPrimaryActions)
        #expect(store.state.num == 100)
    }
    
}

final class TestReducer: Reducer {
    struct State {
        var count: Int = 0
        var num = 0
        var message: String = ""
    }
    
    enum Action {
        case increment
        case num
        case setMessage(String)
        case incrementAndSetMessage(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .num:
            state.num += 1
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


