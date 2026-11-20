import Foundation

/// A state that saves and loads itself.
///
/// Deprecated: with `Storable` the state type decides where it is persisted, so
/// every store with that state shares one place. Give the store a
/// ``StateStorage`` instead and the state type no longer needs to know.
@available(*, deprecated, message: "Pass a StateStorage to Store(reducer:default:storage:) instead of making the state save and load itself.")
public protocol Storable {

    /// Saves the current state to persistent storage.
    ///
    /// This method should handle serializing and storing the current state
    /// in a way that allows it to be restored later.
    func save()

    /// Loads the state from persistent storage.
    ///
    /// This method should handle retrieving and deserializing the state from
    /// storage. If no state is found, or if deserialization fails, it should return `nil`.
    ///
    /// - Returns: The loaded state, or `nil` if no valid state is found.
    static func load() -> Self?
}
