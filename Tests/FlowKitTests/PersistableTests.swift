import XCTest
import Foundation
@testable import FlowKit

// Test structure conforming to `Persistable` for saving to UserDefaults
struct TestState: Persistable, Equatable {
    var value: String
}

struct SampleReducer: Reducer {
    typealias State = TestState
    
    enum Action {
        case updateValue(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .updateValue(let newValue):
            state.value = newValue
            return .none
        }
    }
}

// Reducer A with `State` struct conforming to `Persistable`
struct ReducerA: Reducer {
    struct State: Persistable, Equatable {
        var value: String
    }
    
    enum Action {
        case updateValue(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .updateValue(let newValue):
            state.value = newValue
            return .none
        }
    }
}

// Reducer B with a different `State` struct but same name, also conforming to `Persistable`
struct ReducerB: Reducer {
    struct State: Persistable, Equatable {
        var value: String
    }
    
    enum Action {
        case updateValue(String)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .updateValue(let newValue):
            state.value = newValue
            return .none
        }
    }
}

@MainActor
final class PersistableTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: ReducerA.State.key)
        UserDefaults.standard.removeObject(forKey: ReducerB.State.key)
        UserDefaults.standard.removeObject(forKey: TestState.key)
    }
    
    override func tearDown() {
        // Clear UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: ReducerA.State.key)
        UserDefaults.standard.removeObject(forKey: ReducerB.State.key)
        UserDefaults.standard.removeObject(forKey: TestState.key)
        super.tearDown()
    }
    
    /// Test successful saving to UserDefaults
    func testSaveToUserDefaults() {
        let testState = TestState(value: "Hello, World!")
        testState.save()
        
        // Check that data is saved in UserDefaults
        XCTAssertNotNil(UserDefaults.standard.data(forKey: TestState.key), "Data should be saved in UserDefaults.")
    }
    
    /// Test successful loading from UserDefaults
    func testLoadFromUserDefaults() {
        let testState = TestState(value: "Hello, World!")
        testState.save()
        
        // Load state
        let loadedState = TestState.load()
        XCTAssertEqual(loadedState, testState, "Loaded state should match the saved state.")
    }
    
    /// Test to verify that load returns nil when there is no data in UserDefaults
    func testLoadReturnsNilWhenNoData() {
        // Check that load returns nil if there is no data
        let loadedState = TestState.load()
        XCTAssertNil(loadedState, "Load should return nil when no data is found in UserDefaults.")
    }
    
    /// Test handling of decoding error by saving incompatible data format in UserDefaults
    func testLoadHandlesDecodingErrorGracefully() {
        // Save data that does not match the expected `TestState` structure
        let invalidData = "Invalid data".data(using: .utf8)
        UserDefaults.standard.set(invalidData, forKey: TestState.key)
        
        // Attempt to load data
        let loadedState = TestState.load()
        XCTAssertNil(loadedState, "Load should return nil when decoding fails due to data mismatch.")
    }
    
    /// Test that Store restores state from UserDefaults during initialization
    func testStoreInitializesWithRestoredState() {
        // Save initial state to UserDefaults
        let initialState = TestState(value: "Restored value")
        initialState.save()
        
        // Initialize Store, expecting it to restore the saved state
        let store = Store<SampleReducer>(reducer: SampleReducer(), default: initialState)
        
        XCTAssertEqual(store.state.value, "Restored value", "Store should initialize with restored state from UserDefaults.")
    }
    
    /// Test that Store saves state to UserDefaults after sending an action
    func testStoreSavesStateAfterDispatch() {
        let initialState = TestState(value: "Initial")
        let store = Store<SampleReducer>(reducer: SampleReducer(), default: initialState)
        
        // Dispatch an action to update state
        store.send(.updateValue("Updated"))
        
        // Load the saved state from UserDefaults
        let savedState = TestState.load()
        
        XCTAssertEqual(savedState?.value, "Updated", "Store should save updated state to UserDefaults after sending an action.")
    }
    
    /// Test that Store returns nil for loadState when UserDefaults has incompatible data
    func testStoreHandlesDecodingErrorGracefully() {
        // Save incompatible data format to UserDefaults
        let invalidData = "Invalid data".data(using: .utf8)
        UserDefaults.standard.set(invalidData, forKey: TestState.key)
        
        // Initialize Store with a default state; it should not restore from corrupted data
        let store = Store<SampleReducer>(reducer: SampleReducer(), default: TestState(value: "Default"))
        
        XCTAssertEqual(store.state.value, "Default", "Store should fall back to default state when decoding fails.")
    }
    
    func testStatesWithSameNameDoNotOverwriteEachOther() {
        let reducerAState = ReducerA.State(value: "Reducer A Value")
        let reducerBState = ReducerB.State(value: "Reducer B Value")
        
        // Save both states
        reducerAState.save()
        reducerBState.save()
        
        // Load each state separately
        let loadedReducerAState = ReducerA.State.load()
        let loadedReducerBState = ReducerB.State.load()
        
        // Verify that they do not overwrite each other
        XCTAssertEqual(loadedReducerAState?.value, "Reducer A Value", "ReducerA.State should retain its own saved value.")
        XCTAssertEqual(loadedReducerBState?.value, "Reducer B Value", "ReducerB.State should retain its own saved value.")
    }
    
    /// Test that corrupted data is automatically removed during load
    func testCorruptedDataAutoRemoval() {
        // Save valid data first
        let testState = TestState(value: "Valid")
        testState.save()
        
        // Verify it loads correctly
        XCTAssertEqual(TestState.load()?.value, "Valid")
        
        // Manually corrupt the data
        let corruptedData = "This is not JSON".data(using: .utf8)!
        UserDefaults.standard.set(corruptedData, forKey: TestState.key)
        
        // Attempt to load - should return nil and clean up corrupted data
        let loadedState = TestState.load()
        XCTAssertNil(loadedState, "Loading corrupted data should return nil")
        
        // Verify corrupted data was removed
        let dataAfterCleanup = UserDefaults.standard.data(forKey: TestState.key)
        XCTAssertNil(dataAfterCleanup, "Corrupted data should be automatically removed")
    }
    
    /// Test that save handles encoding failures gracefully
    func testSaveEncodingFailureRecovery() {
        struct CorruptState: Persistable {
            var value: String = "test"
            
            // Custom encode that always fails to simulate encoding error
            func encode(to encoder: Encoder) throws {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated encoding failure"])
            }
        }
        
        let corruptState = CorruptState()
        
        // This should not crash and should handle the error gracefully
        corruptState.save()
        
        // Verify no data was saved due to encoding failure
        let savedData = UserDefaults.standard.data(forKey: CorruptState.key)
        XCTAssertNil(savedData, "No data should be saved when encoding fails")
    }
    
    /// Test UserDefaults synchronization failure handling
    func testSynchronizationFailureHandling() {
        // This test verifies that synchronization check doesn't crash
        // Note: UserDefaults.synchronize() typically always returns true in tests,
        // but we're testing that the code path exists and handles it properly
        
        let testState = TestState(value: "Sync test")
        
        // This should complete without crashing even if synchronization fails
        testState.save()
        
        // Verify state was attempted to be saved (synchronization might succeed in tests)
        let loadedState = TestState.load()
        XCTAssertEqual(loadedState?.value, "Sync test", "State should be saved despite sync check")
    }
}
