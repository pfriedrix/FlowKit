/// A collection of store values that are globally accessible.
///
/// This structure manages a collection of store instances that can be retrieved using a key conforming to the StoreKey protocol. If a store is not found for a given key, its default value is returned.
///
/// - Important: This type conforms to `Sendable` to allow safe usage across concurrent contexts.
public struct StoreValues: Sendable {
    /// A task-local global instance of StoreValues.
    @TaskLocal static var _global = Self()

    /// Internal storage for the store values, keyed by ObjectIdentifier.
    /// Access is serialized by MainActor isolation on the subscript and
    /// `withValues`, so no lock is needed.
    private var storage: [ObjectIdentifier: any Sendable] = [:]

    /// Retrieves or sets the store value for the specified key.
    ///
    /// If no store has been set for the given key, the default value defined by the key is returned.
    ///
    /// - Parameter key: The type of the key conforming to `StoreKey` used to identify the store value.
    /// - Returns: The store value corresponding to the provided key.
    @MainActor
    public subscript<Key: StoreKey>(key: Key.Type) -> Key.Value {
        get {
            if let stored = storage[ObjectIdentifier(key)] as? Key.Value {
                return stored
            }
            return Key.defaultValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    /// Runs `operation` with a fresh `StoreValues` instance bound to `_global`
    /// for the duration of the call. Use this in tests to inject stubs/mocks
    /// without leaking state across tests.
    @MainActor
    public static func withValues<T>(
        _ configure: (inout StoreValues) -> Void,
        operation: () throws -> T
    ) rethrows -> T {
        var values = StoreValues()
        configure(&values)
        return try $_global.withValue(values, operation: operation)
    }

    /// Async variant of ``withValues(_:operation:)``. Both closures run from
    /// MainActor (this function is `@MainActor`-isolated). `operation` is
    /// `@Sendable` because it may suspend and resume on any executor.
    @MainActor
    public static func withValues<T: Sendable>(
        _ configure: (inout StoreValues) -> Void,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        var values = StoreValues()
        configure(&values)
        return try await $_global.withValue(values, operation: operation)
    }
}
