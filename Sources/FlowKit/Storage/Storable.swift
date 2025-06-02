import Foundation

public protocol Storable {
    
    /// Saves the current state to persistent storage.
    ///
    /// This method should handle serializing and storing the current state
    /// in a way that allows it to be restored later.
    @MainActor func save()
    
    /// Loads the state from persistent storage.
    ///
    /// This method should handle retrieving and deserializing the state from
    /// storage. If no state is found, or if deserialization fails, it should return `nil`.
    ///
    /// - Returns: The loaded state, or `nil` if no valid state is found.
    @MainActor static func load() -> Self?
}
