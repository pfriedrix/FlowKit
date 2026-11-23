import Foundation
import Testing
@testable import FlowKit

struct EffectRunReducer: Reducer {
    struct State: Equatable {
        var value: String = ""
        var errorMessage: String = ""
    }

    enum Action: Equatable {
        case runWithPriority(TaskPriority?)
        case runThatThrows
        case runThatThrowsWithHandler
        case runThatThrowsWithoutHandler
        case completed(String)
        case errorCaught(String)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .runWithPriority(let priority):
            return .run(priority: priority) { send in
                await send(.completed("done"))
            }

        case .runThatThrowsWithHandler:
            return .run { send in
                throw NSError(domain: "Test", code: 42)
            } catch: { error, send in
                let nsError = error as NSError
                await send(.errorCaught("code:\(nsError.code)"))
            }

        case .runThatThrowsWithoutHandler:
            return .run { send in
                throw NSError(domain: "Test", code: 99)
            }

        case .runThatThrows:
            return .run { send in
                throw CancellationError()
            } catch: { error, send in
                await send(.errorCaught("cancelled"))
            }

        case .completed(let value):
            state.value = value
            return .none

        case .errorCaught(let msg):
            state.errorMessage = msg
            return .none
        }
    }
}

@MainActor
struct EffectRunTests {

    @Test func `Run with high priority`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(.high))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        #expect(store.state.value == "done")
    }

    @Test func `Run with low priority`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(.low))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        #expect(store.state.value == "done")
    }

    @Test func `Run with nil priority`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(nil))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        #expect(store.state.value == "done")
    }

    @Test func `Run error caught by handler`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrowsWithHandler)

        try await waitForStateChange(timeout: 1.0) {
            store.state.errorMessage == "code:42"
        }

        #expect(store.state.errorMessage == "code:42")
        #expect(store.state.value == "")
    }

    @Test func `Run cancellation error caught by handler`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrows)

        try await waitForStateChange(timeout: 1.0) {
            store.state.errorMessage == "cancelled"
        }

        #expect(store.state.errorMessage == "cancelled")
    }

    @Test func `Run without handler does not crash`() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrowsWithoutHandler)

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(store.state.value == "")
        #expect(store.state.errorMessage == "")
    }
}
