import XCTest
import SwiftUI
@testable import FlowKit

@MainActor
final class BindingCapturePolicyTests: XCTestCase {
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

    func testGetterKeepsStoreAlive() {
        weak var weakStore: Store<CounterReducer>?
        var binding: Binding<Int>?
        do {
            let store = Store(initial: .init(count: 42), reducer: CounterReducer())
            weakStore = store
            binding = store.binding(for: \.count, set: { .set($0) })
        }
        XCTAssertNotNil(weakStore, "getter's [self] must keep Store alive while Binding exists")
        XCTAssertEqual(binding?.wrappedValue, 42)
        binding = nil
        XCTAssertNil(weakStore, "Store must be released once Binding is gone")
    }

    func testBindingDoesNotLeakStoreAfterRelease() {
        weak var weakStore: Store<CounterReducer>?
        do {
            let store = Store(initial: .init(count: 0), reducer: CounterReducer())
            weakStore = store
            _ = store.binding(for: \.count, set: { .set($0) })
        }
        XCTAssertNil(weakStore, "discarded Binding must not retain Store")
    }
}
