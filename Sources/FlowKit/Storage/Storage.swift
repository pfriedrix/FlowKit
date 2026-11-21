
import Foundation

/// Extension of `Store` that persists its state through a ``Persistence``.
///
/// A store created with a ``Persistence`` restores its state from it during
/// initialization and saves it there after every action, so the application state is
/// preserved across app launches and terminations. Where the state goes is decided by
/// the code that creates the store, not by the `State` type.
extension Store {

    /// Creates a store that restores its state from `persistence` and saves it there after every action.
    ///
    /// This initializer first asks `persistence` for a saved state. If one is found, the store starts
    /// from it; otherwise it starts from the provided `default` state and immediately saves that
    /// to `persistence` for future sessions. After every action the new state is saved on a per-store
    /// serial background queue, so saving stays off the main actor and keeps the order of actions.
    ///
    /// - Parameters:
    ///   - reducer: The reducer that handles state updates and actions.
    ///   - default: The default state to use if no saved state is found or restoration fails.
    ///   - persistence: Where the state is restored from and saved to.
    public convenience init(reducer: R, default state: State, persistence: some Persistence<State>) {
        let restored = persistence.load()
        self.init(initial: restored ?? state, reducer: reducer)
        let queue = DispatchQueue(label: "flowkit.\(name).save", qos: .background)
        willSave = { snapshot in queue.async { persistence.save(snapshot) } }

        if let _ = restored {
            logger.info("\(name): state restored from storage")
        } else {
            logger.info("\(name): using default state")
            persistence.save(self.state)
        }
    }
}

@available(*, deprecated, message: "Use Store(reducer:default:persistence:) instead.")
extension Store where State: Storable {

    /// Convenience initializer for `Store` that restores the state through `Storable`.
    ///
    /// Restores from `State.load()` if available, otherwise starts from `default` and saves it.
    /// Every action is followed by `state.save()` on a per-store serial background queue.
    ///
    /// - Parameters:
    ///   - reducer: The reducer that handles state updates and actions.
    ///   - default: The default state to use if no saved state is found or restoration fails.
    public convenience init(reducer: R, default state: State) {
        self.init(reducer: reducer, default: state, persistence: LegacyPersistence<State>())
    }
}

/// Adapts a `Storable` state, which saves and loads itself, to ``Persistence``.
@available(*, deprecated)
struct LegacyPersistence<State: Storable>: Persistence {
    func load() -> State? { State.load() }
    func save(_ state: State) { state.save() }
}
