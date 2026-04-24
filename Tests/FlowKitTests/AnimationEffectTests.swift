import XCTest
import SwiftUI
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
                await send(.increment)
            }
            .animation(.spring)
        case .animatedNilAnimation:
            return .send(.increment)
                .animation(nil)
        }
    }
}

@MainActor
final class AnimationEffectTests: XCTestCase {

    // MARK: - Delivery

    func testAnimatedSendDeliversAction() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedIncrement)

        XCTAssertEqual(store.state.count, 1)
    }

    func testAnimatedMergeDeliversAllActions() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedMerge)

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

    func testNilAnimationPassesThrough() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedNilAnimation)

        XCTAssertEqual(store.state.count, 1)
    }

    // MARK: - Structure

    func testAnimatedSendKeepsSendOperation() {
        let effect = Effect<AnimationReducer.Action>.send(.increment).animation(.easeIn)

        guard case .send(let action) = effect.operation else {
            XCTFail("expected .send, got \(effect.operation)")
            return
        }
        XCTAssertEqual(action, .increment)
        XCTAssertNotNil(effect.animation)
    }

    func testAnimatedMergeKeepsMergeOperation() {
        let effect = Effect<AnimationReducer.Action>.merge(.increment, .increment).animation(.easeInOut)

        guard case .merge(let actions) = effect.operation else {
            XCTFail("expected .merge, got \(effect.operation)")
            return
        }
        XCTAssertEqual(actions, [.increment, .increment])
        XCTAssertNotNil(effect.animation)
    }

    func testAnimatedRunKeepsRunOperation() {
        let effect = Effect<AnimationReducer.Action>.run { send in
            await send(.increment)
        }.animation(.spring)

        guard case .run = effect.operation else {
            XCTFail("expected .run, got \(effect.operation)")
            return
        }
        XCTAssertNotNil(effect.animation)
    }

    func testNilAnimationDropsAnimation() {
        let effect = Effect<AnimationReducer.Action>.send(.increment).animation(nil)

        guard case .send(let action) = effect.operation else {
            XCTFail("expected .send, got \(effect.operation)")
            return
        }
        XCTAssertEqual(action, .increment)
        XCTAssertNil(effect.animation)
    }

    // MARK: - Synchronous dispatch
    //
    // Regression guard: prior to the fix, `.send(...).animation(...)` was rewritten
    // to `.run { ... }` and dispatched through a background Task + MainActor hop.
    // That made the state mutation both async and non-transactional — `withAnimation`
    // had already closed its transaction before the state actually changed. The
    // synchronous assertions below fail if the `.run` detour is re-introduced.

    func testAnimatedSendDispatchesSynchronouslyOnMainActor() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())

        store.send(.animatedIncrement)

        XCTAssertEqual(store.state.count, 1,
                       "Animated .send must mutate state synchronously on MainActor — no Task hop.")
    }

    func testAnimatedMergeDispatchesSynchronouslyOnMainActor() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())

        store.send(.animatedMerge)

        XCTAssertEqual(store.state.count, 2,
                       "Animated .merge must mutate state synchronously on MainActor — no Task hop.")
        XCTAssertEqual(store.state.message, "animated")
    }
}
