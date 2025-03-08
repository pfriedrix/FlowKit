/// A protocol that defines a key for accessing a store value in the StoreValues repository.
///
/// This protocol works similarly to SwiftUI's EnvironmentKey. Conforming types specify an associated
/// store value type and a default value for that key.
///
/// - Note: The associated type `Value` defaults to `Self`.
public protocol StoreKey: Sendable {
    /// The type of the store value associated with this key.
    associatedtype Value: Sendable = Self
    
    /// The default value for the store key.
    static var defaultValue: Self.Value { get }
}
