import XCTest
@testable import FlowKit

struct AnimationReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
        var message: String = ""
    }

    enum Action: Equatable {
        case increment
        case setMessage(String)
        case animatedIncrement
        case animatedMerge
        case animatedRun
        case animatedNone
        case animatedNilAnimation
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .setMessage(let msg):
            state.message = msg
            return .none
        case .animatedIncrement:
            return .send(.increment)
                .animation(.easeIn)
        case .animatedMerge:
            return .merge(.increment, .increment, .setMessage("animated"))
                .animation(.easeInOut)
        case .animatedRun:
            return .run { send in
                send(.increment)
            }
            .animation(.spring)
        case .animatedNone:
            return Effect<Action>.none
                .animation(.default)
        case .animatedNilAnimation:
            return .send(.increment)
                .animation(nil)
        }
    }
}

@MainActor
final class AnimationEffectTests: XCTestCase {

    func testAnimatedSendDeliversAction() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedIncrement)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }

        XCTAssertEqual(store.state.count, 1)
    }

    func testAnimatedMergeDeliversAllActions() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedMerge)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 2 && store.state.message == "animated"
        }

        XCTAssertEqual(store.state.count, 2)
        XCTAssertEqual(store.state.message, "animated")
    }

    func testAnimatedRunDeliversAction() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedRun)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }

        XCTAssertEqual(store.state.count, 1)
    }

    func testAnimatedNoneHasNoEffect() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedNone)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(store.state.count, 0)
        XCTAssertEqual(store.state.message, "")
    }

    func testNilAnimationPassesThrough() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedNilAnimation)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }

        XCTAssertEqual(store.state.count, 1)
    }
}
