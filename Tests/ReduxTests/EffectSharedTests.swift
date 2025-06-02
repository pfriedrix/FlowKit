import XCTest
import SwiftUI
@testable import FlowKit

// MARK: - StoreValues Extension
extension StoreValues {
    struct CounterStoreKey: StoreKey {
        static let defaultValue = Store(initial: CounterReducer.State(), reducer: CounterReducer())
    }
    
    struct LoggerStoreKey: StoreKey {
        static let defaultValue = Store(initial: LoggerReducer.State(), reducer: LoggerReducer())
    }
    
    @MainActor
    var counterStore: Store<CounterReducer> {
        get { self[CounterStoreKey.self] }
        set { self[CounterStoreKey.self] = newValue }
    }
    
    @MainActor
    var loggerStore: Store<LoggerReducer> {
        get { self[LoggerStoreKey.self] }
        set { self[LoggerStoreKey.self] = newValue }
    }
}

// MARK: - Reducers
struct CounterReducer: Reducer {
    struct State: Sendable {
        var count: Int = 0
    }
    
    enum Action: Sendable {
        case increment
        case notifyLogger(String)
        case reset
    }
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .send(\StoreValues.loggerStore, action: .log("Incremented to \(state.count)"))
        case .notifyLogger:
            return .none
        case .reset:
            state = .init()
            return .none
            
        }
    }
}

struct LoggerReducer: Reducer {
    struct State: Sendable {
        var logs: [String] = []
    }
    
    enum Action: Sendable {
        case log(String)
        case reset
    }
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .log(let message):
            state.logs.append(message)
            return .none
        case .reset:
            state = .init()
            return .none
        }
    }
}

final class EffectSharedTests: XCTestCase {
    @Shared(\.counterStore) var counterStore
    @Shared(\.loggerStore) var loggerStore

    // MARK: - Test Cases

    @MainActor
    func testSharedEffectBetweenReducers() {
        counterStore.send(.reset)
        loggerStore.send(.reset)
        
        counterStore.send(.increment)
        
        XCTAssertEqual(counterStore.state.count, 1)
        XCTAssertEqual(loggerStore.state.logs, ["Incremented to 1"])
    }
    
    @MainActor
    func testMultipleIncrements() {
        counterStore.send(.reset)
        loggerStore.send(.reset)
        
        counterStore.send(.increment)
        counterStore.send(.increment)
        counterStore.send(.increment)
        
        XCTAssertEqual(counterStore.state.count, 3)
        XCTAssertEqual(loggerStore.state.logs, [
            "Incremented to 1",
            "Incremented to 2",
            "Incremented to 3"
        ])
    }
    
    @MainActor
    func testLoggerReceivesManualLog() {
        counterStore.send(.reset)
        loggerStore.send(.reset)
        
        loggerStore.send(.log("Manual log entry"))
        
        XCTAssertEqual(loggerStore.state.logs, ["Manual log entry"])
    }
    
    @MainActor
    func testIncrementDoesNotTriggerUnrelatedLogs() {
        counterStore.send(.reset)
        loggerStore.send(.reset)
        
        counterStore.send(.increment)
        
        XCTAssertEqual(loggerStore.state.logs, ["Incremented to 1"])
        
        loggerStore.send(.log("Another log entry"))
        
        XCTAssertEqual(loggerStore.state.logs, [
            "Incremented to 1",
            "Another log entry"
        ])
    }
}
