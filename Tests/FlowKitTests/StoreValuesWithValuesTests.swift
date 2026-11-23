import Testing
@testable import FlowKit

@MainActor
struct StoreValuesWithValuesTests {
    struct CountReducer: Reducer {
        struct State: Equatable, Sendable { var count: Int = 0 }
        enum Action: Equatable, Sendable { case increment }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            state.count += 1
            return .none
        }
    }

    struct CountStoreKey: StoreKey {
        @MainActor static let defaultValue: Store<CountReducer> = .init(
            initial: .init(),
            reducer: .init()
        )
    }

    @Test func `Sync override resolves`() throws {
        let stub = Store(initial: CountReducer.State(count: 42), reducer: CountReducer())

        let observed = StoreValues.withValues {
            $0[CountStoreKey.self] = stub
        } operation: {
            StoreValues._global[CountStoreKey.self].state.count
        }

        #expect(observed == 42)
    }

    @Test func `Async override resolves`() async throws {
        let stub = Store(initial: CountReducer.State(count: 7), reducer: CountReducer())

        let observed: Int = await StoreValues.withValues { values in
            values[CountStoreKey.self] = stub
        } operation: {
            try? await Task.sleep(nanoseconds: 1_000_000)
            return await MainActor.run {
                StoreValues._global[CountStoreKey.self].state.count
            }
        }

        #expect(observed == 7)
    }

    @Test func `Override reverts after scope`() {
        let stub = Store(initial: CountReducer.State(count: 99), reducer: CountReducer())
        let defaultCount = StoreValues._global[CountStoreKey.self].state.count

        StoreValues.withValues {
            $0[CountStoreKey.self] = stub
        } operation: {
            #expect(StoreValues._global[CountStoreKey.self].state.count == 99)
        }

        #expect(
            StoreValues._global[CountStoreKey.self].state.count == defaultCount,
            "Task-local override should revert after scope"
        )
    }

    @Test func `Overrides are isolated between invocations`() {
        let stubA = Store(initial: CountReducer.State(count: 1), reducer: CountReducer())
        let stubB = Store(initial: CountReducer.State(count: 2), reducer: CountReducer())

        let a = StoreValues.withValues {
            $0[CountStoreKey.self] = stubA
        } operation: {
            StoreValues._global[CountStoreKey.self].state.count
        }

        let b = StoreValues.withValues {
            $0[CountStoreKey.self] = stubB
        } operation: {
            StoreValues._global[CountStoreKey.self].state.count
        }

        #expect(a == 1)
        #expect(b == 2)
    }
}
