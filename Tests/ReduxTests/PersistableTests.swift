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
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .updateValue(let newValue):
            state.value = newValue
            return .none
        }
    }
}


final class PersistableTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: TestState.key)
    }
    
    override func tearDown() {
        // Clear UserDefaults after each test
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
    
    /// Test that Store saves state to UserDefaults after dispatching an action
    @MainActor
    func testStoreSavesStateAfterDispatch() {
        let initialState = TestState(value: "Initial")
        let store = Store<SampleReducer>(reducer: SampleReducer(), default: initialState)
        
        // Dispatch an action to update state
        store.dispatch(.updateValue("Updated"))
        
        // Load the saved state from UserDefaults
        let savedState = TestState.load()
        
        XCTAssertEqual(savedState?.value, "Updated", "Store should save updated state to UserDefaults after dispatching an action.")
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
}
