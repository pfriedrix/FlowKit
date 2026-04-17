import XCTest
@testable import FlowKit

@MainActor
final class StoreValuesWithValuesTests: XCTestCase {
    struct CountReducer: Reducer {
        struct State: Equatable, Sendable { var count: Int = 0 }
        enum Action: Equatable, Sendable { case increment }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            state.count += 1
            return .none
        }
    }

    struct CountStoreKey: StoreKey {
        static let defaultValue: Store<CountReducer> = .init(
            initial: .init(),
            reducer: .init()
        )
    }

    func testSyncOverrideResolves() throws {
        let stub = Store(initial: CountReducer.State(count: 42), reducer: CountReducer())

        let observed = StoreValues.withValues {
            $0[CountStoreKey.self] = stub
        } operation: {
            StoreValues._global[CountStoreKey.self].state.count
        }

        XCTAssertEqual(observed, 42)
    }

    func testAsyncOverrideResolves() async throws {
        let stub = Store(initial: CountReducer.State(count: 7), reducer: CountReducer())

        let observed: Int = await StoreValues.withValues { values in
            values[CountStoreKey.self] = stub
        } operation: {
            try? await Task.sleep(nanoseconds: 1_000_000)
            return await MainActor.run {
                StoreValues._global[CountStoreKey.self].state.count
            }
        }

        XCTAssertEqual(observed, 7)
    }

    func testOverrideRevertsAfterScope() {
        let stub = Store(initial: CountReducer.State(count: 99), reducer: CountReducer())
        let defaultCount = StoreValues._global[CountStoreKey.self].state.count

        StoreValues.withValues {
            $0[CountStoreKey.self] = stub
        } operation: {
            XCTAssertEqual(StoreValues._global[CountStoreKey.self].state.count, 99)
        }

        XCTAssertEqual(
            StoreValues._global[CountStoreKey.self].state.count,
            defaultCount,
            "Task-local override should revert after scope"
        )
    }

    func testOverridesAreIsolatedBetweenInvocations() {
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

        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, 2)
    }
}
