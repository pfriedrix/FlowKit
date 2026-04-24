import Foundation
public import Observation
import os
import SwiftUI

/// A class responsible for managing the application's state and dispatching actions.
///
/// The `Store` class holds the application's state and provides a mechanism to dispatch
/// actions, which are handled by the associated reducer. The reducer updates the state
/// based on the action, and the store publishes the new state to any observing views or objects.
///
/// This class also handles asynchronous state updates and supports side effects through the
/// reducer's `Effect` mechanism.
///
/// All mutation is MainActor-isolated: state, the reducer, and the effect registry live on
/// MainActor. Only the user's `async` effect body runs off-actor; follow-up actions hop
/// back via `Send` for dispatch.
///
/// - Parameters:
///   - R: The type of the reducer, which conforms to the `Reducer` protocol and defines
///        the state's structure and how actions are handled.
@MainActor
@Observable
final public class Store<R: Reducer> {

    /// The type representing the current state of the store.
    public typealias State = R.State

    /// The type representing the actions handled by the store.
    public typealias Action = R.Action

    /// The current state of the store.
    public var state: State

    /// The reducer responsible for handling actions and updating the state.
    let reducer: R

    /// Logger instance for tracking state changes and actions.
    let logger = Logger.shared

    /// The name of the store, derived from the reducer type name.
    nonisolated var name: String {
        let full = String(describing: R.self)
        return full.components(separatedBy: ".").last ?? full
    }

    /// Internal hook wired by the `Storable` integration in `Storage.swift`.
    /// Invoked synchronously on MainActor after every successful reduce.
    /// The `Storable` wiring dispatches the body onto a serial background
    /// queue so encoding/UserDefaults writes stay off MainActor while
    /// preserving per-action ordering. Not intended as a general-purpose hook.
    var willSave: (@Sendable (State) -> Void)? = nil

    /// Every in-flight `.run` effect — cancellable or not. Keyed by a fresh
    /// `UUID` so the detached task can capture a `Sendable` key for its
    /// self-removal hop. `id` is the user-supplied cancellation id, if any;
    /// `.cancel(id:)` and `cancelInFlight` scan values by `id`.
    struct RunningEffect {
        let id: AnyHashable?
        let task: Task<Void, Never>
    }

    var tasks: [UUID: RunningEffect] = [:]

    /// Initializes the store with an initial state and a reducer.
    ///
    /// MainActor-isolated: every `StoreKey.defaultValue` that constructs a store
    /// must be declared `@MainActor` (the `@Inject` macro emits this by default).
    ///
    /// - Parameters:
    ///   - initial: The initial state of the store.
    ///   - reducer: The reducer that will handle actions and state updates.
    public required init(initial: State, reducer: R) {
        self.state = initial
        self.reducer = reducer
        logger.info("\(name): store initialized")
    }

    /// Sends an action to the store, triggering a state update.
    ///
    /// This method processes the action through the reducer, applies any state updates,
    /// and triggers associated effects, which may include additional actions or asynchronous operations.
    ///
    /// - Parameter action: The action to send to the reducer for processing.
    public func send(_ action: Action) {
        logger.action("\(name).\(action)")
        dispatch(state, action)
    }

    /// Handles the dispatching of actions and state updates.
    ///
    /// Invokes the reducer, commits the new state, fires the save hook, and handles the effect.
    private func dispatch(_ state: State, _ action: Action) {
        let result = resolve(state, action)
        self.state = result.state
        willSave?(result.state)
        handle(result.effect)
    }

    /// Resolves the action by applying it to the current state, and returns an effect.
    func resolve(_ state: State, _ action: Action) -> Resolution<State, Action> {
        var currentState = state
        let effect = reducer.reduce(into: &currentState, action: action)
        logger.info("\(name): resolve `\(action)`: \(currentState)")
        return Resolution(state: currentState, effect: effect)
    }

    /// Handles the provided effect. `.send`/`.merge` dispatch synchronously; `.run`
    /// spawns a detached Task via `runEffect`; `.cancel` looks up and cancels an
    /// entry in the registry.
    private func handle(_ effect: Effect<Action>) {
        switch effect.operation {
        case .none:
            return
        case let .send(action):
            if let animation = effect.animation {
                withAnimation(animation) { send(action) }
            } else {
                send(action)
            }
        case let .merge(actions):
            if let animation = effect.animation {
                withAnimation(animation) {
                    for action in actions { send(action) }
                }
            } else {
                for action in actions { send(action) }
            }
        case let .run(priority, cancellationId, cancelInFlight, operation):
            runEffect(
                id: cancellationId,
                cancelInFlight: cancelInFlight,
                priority: priority,
                animation: effect.animation,
                operation: operation
            )
        case let .cancel(id):
            cancel(id: id)
        }
    }

    /// The single entry point for every `.run` effect, cancellable or not.
    ///
    /// Registration and cancel-in-flight are synchronous on MainActor, so a `.cancel(id:)`
    /// dispatched in the same `send` chain always observes a freshly-registered entry.
    /// The user's async `operation` runs detached; completion hops back to MainActor
    /// to remove the entry from `tasks`.
    private func runEffect(
        id: AnyHashable?,
        cancelInFlight: Bool,
        priority: TaskPriority?,
        animation: Animation?,
        operation: @escaping @Sendable (Send<Action>) async -> Void
    ) {
        if let id, cancelInFlight { cancel(id: id) }

        let key = UUID()

        let send = Send<Action> { [weak self] action in
            guard let self else { return }
            await MainActor.run {
                if let animation {
                    withAnimation(animation) { self.send(action) }
                } else {
                    self.send(action)
                }
            }
        }

        let task = Task.detached(priority: priority) { [weak self] in
            await operation(send)
            await self?.finish(key: key)
        }

        tasks[key] = RunningEffect(id: id, task: task)
    }

    /// Called from the detached task when `operation` returns. No-op if the
    /// entry was already pulled by `.cancel(id:)` / `cancelInFlight`.
    private func finish(key: UUID) {
        tasks.removeValue(forKey: key)
    }

    /// Cancels the cancellable effect registered under `id`, if any.
    /// O(n) in the size of `tasks`; fine for UDF workloads.
    /// Logs on miss so typo'd ids and stale cancels don't silently no-op.
    private func cancel(id: AnyHashable) {
        for (key, entry) in tasks where entry.id == id {
            tasks.removeValue(forKey: key)
            entry.task.cancel()
            return
        }
        logger.info("\(self.name): cancel miss for id \(String(describing: id))")
    }
}
