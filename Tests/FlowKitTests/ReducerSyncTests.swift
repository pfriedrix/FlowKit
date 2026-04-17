import XCTest
@testable import FlowKit

/// Demonstrates testing a reducer synchronously as a pure function,
/// with no Store, no async, and no polling.
@MainActor
final class ReducerSyncTests: XCTestCase {

    struct CounterReducer: Reducer {
        struct State: Equatable, Sendable {
            var count: Int = 0
            var message: String = ""
        }

        enum Action: Equatable, Sendable {
            case increment
            case decrement
            case setMessage(String)
            case start
            case reset
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .increment:
                state.count += 1
                return .none
            case .decrement:
                state.count -= 1
                return .none
            case .setMessage(let text):
                state.message = text
                return .none
            case .start:
                return .run { send in
                    send(.increment)
                }
            case .reset:
                state.count = 0
                return .merge(.setMessage(""))
            }
        }
    }

    func testIncrementMutatesState() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .increment)
        XCTAssertEqual(state.count, 1)
        XCTAssertEqual(effect, .none)
    }

    func testDecrementMutatesState() {
        var state = CounterReducer.State(count: 5, message: "")
        let effect = CounterReducer().reduce(into: &state, action: .decrement)
        XCTAssertEqual(state.count, 4)
        XCTAssertTrue(effect.isNone)
    }

    func testSetMessageMutatesState() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .setMessage("hi"))
        XCTAssertEqual(state.message, "hi")
        XCTAssertEqual(effect, .none)
    }

    func testStartReturnsRunEffect() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .start)
        XCTAssertFalse(effect.isNone)
        XCTAssertEqual(state, CounterReducer.State())
        XCTAssertNotEqual(effect, .none)
    }

    func testResetReturnsMergeEffect() {
        var state = CounterReducer.State(count: 10, message: "stale")
        let effect = CounterReducer().reduce(into: &state, action: .reset)
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(effect, .merge(.setMessage("")))
    }
}
