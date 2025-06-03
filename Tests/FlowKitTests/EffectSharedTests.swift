import XCTest
import SwiftUI
@testable import FlowKit

extension StoreValues {
    
    struct ManualCounterStoreKey: StoreKey {
        static let defaultValue = Store(initial: ManualCounterReducer.State(), reducer: ManualCounterReducer())
    }
    
    struct ManualLoggerStoreKey: StoreKey {
        static let defaultValue = Store(initial: ManualLoggerReducer.State(), reducer: ManualLoggerReducer())
    }
    
    @MainActor
    var manualCounterStore: Store<ManualCounterReducer> {
        get { self[ManualCounterStoreKey.self] }
        set { self[ManualCounterStoreKey.self] = newValue }
    }
    
    @MainActor
    var manualLoggerStore: Store<ManualLoggerReducer> {
        get { self[ManualLoggerStoreKey.self] }
        set { self[ManualLoggerStoreKey.self] = newValue }
    }
    
    @Inject var injectCounterStore: Store<InjectCounterReducer> = Store(initial: InjectCounterReducer.State(), reducer: InjectCounterReducer())
    @Inject var injectLoggerStore: Store<InjectLoggerReducer> = Store(initial: InjectLoggerReducer.State(), reducer: InjectLoggerReducer())
}

struct ManualCounterReducer: Reducer {
    struct State: Sendable {
        var count: Int = 0
        var source: String = "Manual"
    }
    
    enum Action: Sendable {
        case increment
        case reset
    }
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .send(\StoreValues.manualLoggerStore, action: .log("MANUAL: Incremented to \(state.count)"))
        case .reset:
            state = .init()
            return .none
        }
    }
}

struct ManualLoggerReducer: Reducer {
    struct State: Sendable {
        var logs: [String] = []
        var source: String = "Manual"
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

struct InjectCounterReducer: Reducer {
    struct State: Sendable {
        var count: Int = 0
        var source: String = "Inject"
    }
    
    enum Action: Sendable {
        case increment
        case reset
    }
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .send(\StoreValues.injectLoggerStore, action: .log("INJECT: Incremented to \(state.count)"))
        case .reset:
            state = .init()
            return .none
        }
    }
}

struct InjectLoggerReducer: Reducer {
    struct State: Sendable {
        var logs: [String] = []
        var source: String = "Inject"
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
    
    @Shared(\.manualCounterStore) var manualCounterStore
    @Shared(\.manualLoggerStore) var manualLoggerStore

    @MainActor
    func testManualStoreImplementation() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        
        XCTAssertEqual(manualCounterStore.state.count, 0)
        XCTAssertEqual(manualCounterStore.state.source, "Manual")
        XCTAssertEqual(manualLoggerStore.state.logs, [])
        XCTAssertEqual(manualLoggerStore.state.source, "Manual")
        
        manualCounterStore.send(.increment)
        
        XCTAssertEqual(manualCounterStore.state.count, 1)
        XCTAssertEqual(manualLoggerStore.state.logs, ["MANUAL: Incremented to 1"])
    }
    
    @MainActor
    func testManualMultipleIncrements() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        
        manualCounterStore.send(.increment)
        manualCounterStore.send(.increment)
        manualCounterStore.send(.increment)
        
        XCTAssertEqual(manualCounterStore.state.count, 3)
        XCTAssertEqual(manualLoggerStore.state.logs, [
            "MANUAL: Incremented to 1",
            "MANUAL: Incremented to 2",
            "MANUAL: Incremented to 3"
        ])
    }
    
    @Shared(\.injectCounterStore) var injectCounterStore
    @Shared(\.injectLoggerStore) var injectLoggerStore

    @MainActor
    func testInjectMacroImplementation() {
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        XCTAssertEqual(injectCounterStore.state.count, 0)
        XCTAssertEqual(injectCounterStore.state.source, "Inject")
        XCTAssertEqual(injectLoggerStore.state.logs, [])
        XCTAssertEqual(injectLoggerStore.state.source, "Inject")
        
        injectCounterStore.send(.increment)
        
        XCTAssertEqual(injectCounterStore.state.count, 1)
        XCTAssertEqual(injectLoggerStore.state.logs, ["INJECT: Incremented to 1"])
    }
    
    @MainActor
    func testInjectMultipleIncrements() {
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        injectCounterStore.send(.increment)
        injectCounterStore.send(.increment)
        injectCounterStore.send(.increment)
        
        XCTAssertEqual(injectCounterStore.state.count, 3)
        XCTAssertEqual(injectLoggerStore.state.logs, [
            "INJECT: Incremented to 1",
            "INJECT: Incremented to 2", 
            "INJECT: Incremented to 3"
        ])
    }
    
    @MainActor
    func testBothImplementationsAreIsolated() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        manualCounterStore.send(.increment)
        
        XCTAssertEqual(injectCounterStore.state.count, 0)
        XCTAssertEqual(injectLoggerStore.state.logs, [])
        
        XCTAssertEqual(manualCounterStore.state.count, 1)
        XCTAssertEqual(manualLoggerStore.state.logs, ["MANUAL: Incremented to 1"])
        
        injectCounterStore.send(.increment)
        
        XCTAssertEqual(manualCounterStore.state.count, 1)
        XCTAssertEqual(manualLoggerStore.state.logs, ["MANUAL: Incremented to 1"])
        
        XCTAssertEqual(injectCounterStore.state.count, 1)
        XCTAssertEqual(injectLoggerStore.state.logs, ["INJECT: Incremented to 1"])
    }
    
    @MainActor
    func testCodeComparisonDemo() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        manualCounterStore.send(.increment)
        injectCounterStore.send(.increment)
        
        XCTAssertEqual(manualCounterStore.state.count, injectCounterStore.state.count)
        XCTAssertEqual(manualLoggerStore.state.logs.count, injectLoggerStore.state.logs.count)
        XCTAssertTrue(manualLoggerStore.state.logs.first?.contains("MANUAL") == true)
        XCTAssertTrue(injectLoggerStore.state.logs.first?.contains("INJECT") == true)
    }
}
