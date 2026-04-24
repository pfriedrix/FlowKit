import XCTest
@testable import FlowKit

struct CancelInFlightReducer: Reducer {
    struct State: Equatable {
        var completionCount: Int = 0
        var lastValue: String = ""
    }

    enum Action: Equatable {
        case startTask(String)
        case completed(String)
    }

    let cancelInFlight: Bool

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startTask(let value):
            return .run { send in
                try await Task.sleep(nanoseconds: 200_000_000)
                await send(.completed(value))
            } catch: { _, _ in }
            .cancellable(id: "task", cancelInFlight: cancelInFlight)

        case .completed(let value):
            state.completionCount += 1
            state.lastValue = value
            return .none
        }
    }
}

@MainActor
final class CancelInFlightTests: XCTestCase {

    func testCancelInFlightTrueCancelsPreviousTask() async throws {
        let store = Store(
            initial: CancelInFlightReducer.State(),
            reducer: CancelInFlightReducer(cancelInFlight: true)
        )

        store.send(.startTask("first"))
        try await Task.sleep(nanoseconds: 50_000_000)
        store.send(.startTask("second"))

        try await waitForStateChange(timeout: 2.0) {
            store.state.completionCount == 1
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(store.state.completionCount, 1)
        XCTAssertEqual(store.state.lastValue, "second")
    }

    func testCancelInFlightFalseAllowsBothTasks() async throws {
        let store = Store(
            initial: CancelInFlightReducer.State(),
            reducer: CancelInFlightReducer(cancelInFlight: false)
        )

        store.send(.startTask("first"))
        try await Task.sleep(nanoseconds: 50_000_000)
        store.send(.startTask("second"))

        try await waitForStateChange(timeout: 2.0) {
            store.state.completionCount == 2
        }

        XCTAssertEqual(store.state.completionCount, 2)
    }

    func testCancelInFlightFalseWithRapidDispatches() async throws {
        let store = Store(
            initial: CancelInFlightReducer.State(),
            reducer: CancelInFlightReducer(cancelInFlight: false)
        )

        for i in 0..<5 {
            store.send(.startTask("task-\(i)"))
        }

        try await waitForStateChange(timeout: 3.0) {
            store.state.completionCount == 5
        }

        XCTAssertEqual(store.state.completionCount, 5)
    }
}
