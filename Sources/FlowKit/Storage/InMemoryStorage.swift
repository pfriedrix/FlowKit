import os

/// A ``StateStorage`` that keeps the state in memory.
///
/// Use it in tests and headless runs to start a store from any saved state and
/// to inspect what the store saved, without touching the disk:
///
/// ```swift
/// let memory = InMemoryStorage(AppState(isOnboarded: true))
/// let store = Store(reducer: AppReducer(), default: AppState(), storage: memory)
///
/// store.send(.logout)
/// // later: memory.value is the last state the store saved
/// ```
///
/// Saves arrive from the store's background queue, so ``value`` catches up
/// shortly after `send(_:)` returns rather than synchronously.
public final class InMemoryStorage<State: Sendable>: StateStorage {

    private let lock: OSAllocatedUnfairLock<State?>

    /// Creates a storage that already holds `initial`, or an empty one when
    /// `initial` is `nil`.
    public init(_ initial: State? = nil) {
        lock = OSAllocatedUnfairLock(initialState: initial)
    }

    /// The state currently held: the last saved one, or the initial one if
    /// nothing has been saved yet.
    public var value: State? {
        lock.withLock { $0 }
    }

    public func load() -> State? {
        value
    }

    public func save(_ state: State) {
        lock.withLock { $0 = state }
    }
}
