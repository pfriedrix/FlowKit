import Testing
@testable import FlowKit

/// Demonstrates testing a reducer synchronously as a pure function,
/// with no Store, no async, and no polling.
@MainActor
struct ReducerSyncTests {

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
                    await send(.increment)
                }
            case .reset:
                state.count = 0
                return .merge(.setMessage(""))
            }
        }
    }

    @Test func `Increment mutates state`() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .increment)
        #expect(state.count == 1)
        #expect(effect == .none)
    }

    @Test func `Decrement mutates state`() {
        var state = CounterReducer.State(count: 5, message: "")
        let effect = CounterReducer().reduce(into: &state, action: .decrement)
        #expect(state.count == 4)
        #expect(effect.isNone)
    }

    @Test func `Set message mutates state`() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .setMessage("hi"))
        #expect(state.message == "hi")
        #expect(effect == .none)
    }

    @Test func `Start returns run effect`() {
        var state = CounterReducer.State()
        let effect = CounterReducer().reduce(into: &state, action: .start)
        #expect(!effect.isNone)
        #expect(state == CounterReducer.State())
        #expect(effect != .none)
    }

    @Test func `Reset returns merge effect`() {
        var state = CounterReducer.State(count: 10, message: "stale")
        let effect = CounterReducer().reduce(into: &state, action: .reset)
        #expect(state.count == 0)
        #expect(effect == .merge(.setMessage("")))
    }
}
