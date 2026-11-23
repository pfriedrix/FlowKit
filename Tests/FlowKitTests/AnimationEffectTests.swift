import Testing
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
struct AnimationEffectTests {

    // MARK: - Delivery

    @Test func `Animated send delivers action`() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedIncrement)

        #expect(store.state.count == 1)
    }

    @Test func `Animated merge delivers all actions`() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedMerge)

        #expect(store.state.count == 2)
        #expect(store.state.message == "animated")
    }

    @Test func `Animated run delivers action`() async throws {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedRun)

        try await waitForStateChange(timeout: 1.0) {
            store.state.count == 1
        }

        #expect(store.state.count == 1)
    }

    @Test func `Nil animation passes through`() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())
        store.send(.animatedNilAnimation)

        #expect(store.state.count == 1)
    }

    // MARK: - Structure

    @Test func `Animated send keeps send operation`() {
        let effect = Effect<AnimationReducer.Action>.send(.increment).animation(.easeIn)

        guard case .send(let action) = effect.operation else {
            Issue.record("expected .send, got \(effect.operation)")
            return
        }
        #expect(action == .increment)
        #expect(effect.animation != nil)
    }

    @Test func `Animated merge keeps merge operation`() {
        let effect = Effect<AnimationReducer.Action>.merge(.increment, .increment).animation(.easeInOut)

        guard case .merge(let actions) = effect.operation else {
            Issue.record("expected .merge, got \(effect.operation)")
            return
        }
        #expect(actions == [.increment, .increment])
        #expect(effect.animation != nil)
    }

    @Test func `Animated run keeps run operation`() {
        let effect = Effect<AnimationReducer.Action>.run { send in
            await send(.increment)
        }.animation(.spring)

        guard case .run = effect.operation else {
            Issue.record("expected .run, got \(effect.operation)")
            return
        }
        #expect(effect.animation != nil)
    }

    @Test func `Nil animation drops animation`() {
        let effect = Effect<AnimationReducer.Action>.send(.increment).animation(nil)

        guard case .send(let action) = effect.operation else {
            Issue.record("expected .send, got \(effect.operation)")
            return
        }
        #expect(action == .increment)
        #expect(effect.animation == nil)
    }

    /// Regression guard: `.animation(nil)` must actually clear a previously-attached
    /// animation, not silently no-op. Before the fix the method guarded on `nil` and
    /// returned `self`, so this chain would have kept `.easeIn` instead of clearing it.
    @Test func `Nil animation clears previously attached animation`() {
        let effect = Effect<AnimationReducer.Action>
            .send(.increment)
            .animation(.easeIn)
            .animation(nil)

        #expect(effect.animation == nil)
    }

    // MARK: - Synchronous dispatch
    //
    // Regression guard: prior to the fix, `.send(...).animation(...)` was rewritten
    // to `.run { ... }` and dispatched through a background Task + MainActor hop.
    // That made the state mutation both async and non-transactional — `withAnimation`
    // had already closed its transaction before the state actually changed. The
    // synchronous assertions below fail if the `.run` detour is re-introduced.

    @Test func `Animated send dispatches synchronously on MainActor`() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())

        store.send(.animatedIncrement)

        #expect(store.state.count == 1,
                "Animated .send must mutate state synchronously on MainActor — no Task hop.")
    }

    @Test func `Animated merge dispatches synchronously on MainActor`() {
        let store = Store(initial: AnimationReducer.State(), reducer: AnimationReducer())

        store.send(.animatedMerge)

        #expect(store.state.count == 2,
                "Animated .merge must mutate state synchronously on MainActor — no Task hop.")
        #expect(store.state.message == "animated")
    }
}
