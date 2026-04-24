import Foundation
@testable import FlowKit

/// Counter reducer scoped to SwiftUI rendering tests.
///
/// Intentionally separate from `ReducerSharedTests`'s `CounterReducer` so that
/// SwiftUI rendering tests don't share singleton registry state with the rest
/// of the test suite — isolation by construction, not by `setUp` discipline.
struct RenderingCounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
    }

    enum Action: Equatable {
        case increment
        case reset
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .reset:
            state = .init()
            return .none
        }
    }
}

struct RenderingCounterStoreKey: StoreKey {
    @MainActor static let defaultValue: Store<RenderingCounterReducer> = .init(
        initial: .init(),
        reducer: .init()
    )
}

extension StoreValues {
    @MainActor
    var renderingCounterStore: Store<RenderingCounterReducer> {
        get { self[RenderingCounterStoreKey.self] }
        set { self[RenderingCounterStoreKey.self] = newValue }
    }
}
