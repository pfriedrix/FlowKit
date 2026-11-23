import Testing
import SwiftUI
@testable import FlowKit

@MainActor
extension StoreValues {

    struct ManualCounterStoreKey: StoreKey {
        static let defaultValue = Store(initial: ManualCounterReducer.State(), reducer: ManualCounterReducer())
    }

    struct ManualLoggerStoreKey: StoreKey {
        static let defaultValue = Store(initial: ManualLoggerReducer.State(), reducer: ManualLoggerReducer())
    }

    var manualCounterStore: Store<ManualCounterReducer> {
        get { self[ManualCounterStoreKey.self] }
        set { self[ManualCounterStoreKey.self] = newValue }
    }

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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .send(\.manualLoggerStore, action: .log("MANUAL: Incremented to \(state.count)"))
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
            return .send(\.injectLoggerStore, action: .log("INJECT: Incremented to \(state.count)"))
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

// Serialized: tests reset and mutate the process-wide `StoreValues` registry stores (manual StoreKeys + @Inject).
@Suite(.serialized)
@MainActor
struct EffectSharedTests {
    
    @Shared(\.manualCounterStore) var manualCounterStore
    @Shared(\.manualLoggerStore) var manualLoggerStore

    @Test @MainActor
    func `Manual store implementation`() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        
        #expect(manualCounterStore.state.count == 0)
        #expect(manualCounterStore.state.source == "Manual")
        #expect(manualLoggerStore.state.logs == [])
        #expect(manualLoggerStore.state.source == "Manual")
        
        manualCounterStore.send(.increment)
        
        #expect(manualCounterStore.state.count == 1)
        #expect(manualLoggerStore.state.logs == ["MANUAL: Incremented to 1"])
    }
    
    @Test @MainActor
    func `Manual multiple increments`() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        
        manualCounterStore.send(.increment)
        manualCounterStore.send(.increment)
        manualCounterStore.send(.increment)
        
        #expect(manualCounterStore.state.count == 3)
        #expect(manualLoggerStore.state.logs == [
            "MANUAL: Incremented to 1",
            "MANUAL: Incremented to 2",
            "MANUAL: Incremented to 3"
        ])
    }
    
    @Shared(\.injectCounterStore) var injectCounterStore
    @Shared(\.injectLoggerStore) var injectLoggerStore

    @Test @MainActor
    func `Inject macro implementation`() {
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        #expect(injectCounterStore.state.count == 0)
        #expect(injectCounterStore.state.source == "Inject")
        #expect(injectLoggerStore.state.logs == [])
        #expect(injectLoggerStore.state.source == "Inject")
        
        injectCounterStore.send(.increment)
        
        #expect(injectCounterStore.state.count == 1)
        #expect(injectLoggerStore.state.logs == ["INJECT: Incremented to 1"])
    }
    
    @Test @MainActor
    func `Inject multiple increments`() {
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        injectCounterStore.send(.increment)
        injectCounterStore.send(.increment)
        injectCounterStore.send(.increment)
        
        #expect(injectCounterStore.state.count == 3)
        #expect(injectLoggerStore.state.logs == [
            "INJECT: Incremented to 1",
            "INJECT: Incremented to 2", 
            "INJECT: Incremented to 3"
        ])
    }
    
    @Test @MainActor
    func `Both implementations are isolated`() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)
        
        manualCounterStore.send(.increment)
        
        #expect(injectCounterStore.state.count == 0)
        #expect(injectLoggerStore.state.logs == [])
        
        #expect(manualCounterStore.state.count == 1)
        #expect(manualLoggerStore.state.logs == ["MANUAL: Incremented to 1"])
        
        injectCounterStore.send(.increment)
        
        #expect(manualCounterStore.state.count == 1)
        #expect(manualLoggerStore.state.logs == ["MANUAL: Incremented to 1"])
        
        #expect(injectCounterStore.state.count == 1)
        #expect(injectLoggerStore.state.logs == ["INJECT: Incremented to 1"])
    }
    
    @Test @MainActor
    func `Manual and inject stores produce equal counts`() {
        manualCounterStore.send(.reset)
        injectCounterStore.send(.reset)

        manualCounterStore.send(.increment)
        injectCounterStore.send(.increment)

        #expect(manualCounterStore.state.count == 1)
        #expect(injectCounterStore.state.count == 1)
    }

    @Test @MainActor
    func `Manual and inject stores produce equal log counts`() {
        manualCounterStore.send(.reset)
        manualLoggerStore.send(.reset)
        injectCounterStore.send(.reset)
        injectLoggerStore.send(.reset)

        manualCounterStore.send(.increment)
        injectCounterStore.send(.increment)

        #expect(manualLoggerStore.state.logs.count == 1)
        #expect(injectLoggerStore.state.logs.count == 1)
    }

    /// `Send.callAsFunction(keyPath:, action:)` dispatches to the store
    /// referenced by `keyPath` in `StoreValues`, regardless of which store
    /// owns the Send.
    @Test @MainActor
    func `Send key path variant dispatches to cross store`() async throws {
        manualLoggerStore.send(.reset)
        let send = Send<Int> { _ in }

        await send(\.manualLoggerStore, action: .log("direct"))

        try await waitForStateChange(timeout: 5.0) {
            self.manualLoggerStore.state.logs == ["direct"]
        }
        #expect(manualLoggerStore.state.logs == ["direct"])
    }
}
