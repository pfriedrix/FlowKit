import XCTest
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
                send(.completed("done"))
            }

        case .runThatThrowsWithHandler:
            return .run { send in
                throw NSError(domain: "Test", code: 42)
            } catch: { error, send in
                let nsError = error as NSError
                send(.errorCaught("code:\(nsError.code)"))
            }

        case .runThatThrowsWithoutHandler:
            return .run { send in
                throw NSError(domain: "Test", code: 99)
            }

        case .runThatThrows:
            return .run { send in
                throw CancellationError()
            } catch: { error, send in
                send(.errorCaught("cancelled"))
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
final class EffectRunTests: XCTestCase {

    func testRunWithHighPriority() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(.high))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        XCTAssertEqual(store.state.value, "done")
    }

    func testRunWithLowPriority() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(.low))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        XCTAssertEqual(store.state.value, "done")
    }

    func testRunWithNilPriority() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runWithPriority(nil))

        try await waitForStateChange(timeout: 1.0) {
            store.state.value == "done"
        }

        XCTAssertEqual(store.state.value, "done")
    }

    func testRunErrorCaughtByHandler() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrowsWithHandler)

        try await waitForStateChange(timeout: 1.0) {
            store.state.errorMessage == "code:42"
        }

        XCTAssertEqual(store.state.errorMessage, "code:42")
        XCTAssertEqual(store.state.value, "")
    }

    func testRunCancellationErrorCaughtByHandler() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrows)

        try await waitForStateChange(timeout: 1.0) {
            store.state.errorMessage == "cancelled"
        }

        XCTAssertEqual(store.state.errorMessage, "cancelled")
    }

    func testRunWithoutHandlerDoesNotCrash() async throws {
        let store = Store(initial: EffectRunReducer.State(), reducer: EffectRunReducer())
        store.send(.runThatThrowsWithoutHandler)

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.state.value, "")
        XCTAssertEqual(store.state.errorMessage, "")
    }
}
