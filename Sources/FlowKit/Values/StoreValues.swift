import os

/// A collection of store values that are globally accessible.
///
/// This structure manages a collection of store instances that can be retrieved using a key conforming to the StoreKey protocol. If a store is not found for a given key, its default value is returned.
///
/// - Important: This type conforms to `Sendable` to allow safe usage across concurrent contexts.
public struct StoreValues: Sendable {
    /// A task-local global instance of StoreValues.
    @TaskLocal static var _global = Self()
    
    /// Internal storage for the store values, keyed by ObjectIdentifier.
    private var storage: OSAllocatedUnfairLock<[ObjectIdentifier: any Sendable]> = .init(initialState: [:])
    
    /// Retrieves or sets the store value for the specified key.
    ///
    /// If no store has been set for the given key, the default value defined by the key is returned.
    ///
    /// - Parameter key: The type of the key conforming to `StoreKey` used to identify the store value.
    /// - Returns: The store value corresponding to the provided key.
    @MainActor
    public subscript<Key: StoreKey>(key: Key.Type) -> Key.Value {
        get {
            storage.withLock { storage in
                storage[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue
            }
        }
        set {
            storage.withLock { storage in
                storage[ObjectIdentifier(key)] = newValue
            }
        }
    }
}
