import Testing
import SwiftUI
@testable import FlowKit

@MainActor
struct BindingCapturePolicyTests {
    struct CounterReducer: Reducer {
        struct State: Equatable {
            var count: Int
        }

        enum Action {
            case set(Int)
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .set(let value):
                state.count = value
                return .none
            }
        }
    }

    @Test func `Getter keeps store alive`() {
        weak var weakStore: Store<CounterReducer>?
        var binding: Binding<Int>?
        do {
            let store = Store(initial: .init(count: 42), reducer: CounterReducer())
            weakStore = store
            binding = store.binding(for: \.count, set: { .set($0) })
        }
        #expect(weakStore != nil, "getter's [self] must keep Store alive while Binding exists")
        #expect(binding?.wrappedValue == 42)
        binding = nil
        #expect(weakStore == nil, "Store must be released once Binding is gone")
    }

    @Test func `Binding does not leak store after release`() {
        weak var weakStore: Store<CounterReducer>?
        do {
            let store = Store(initial: .init(count: 0), reducer: CounterReducer())
            weakStore = store
            _ = store.binding(for: \.count, set: { .set($0) })
        }
        #expect(weakStore == nil, "discarded Binding must not retain Store")
    }
}
