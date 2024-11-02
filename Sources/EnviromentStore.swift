import SwiftUI

/// A property wrapper that provides access to a `Store` from the environment.
///
/// This property wrapper automatically observes changes to the `Store` and triggers a
/// UI update when the store's state changes. It is used to integrate a global state
/// into SwiftUI views via the environment.
///
/// - Parameters:
///   - R: The type of the `Reducer` that defines how actions are handled and how the state evolves.
///   - S: The type of the `Store` that holds the application state and interacts with the reducer.
@propertyWrapper
public struct EnvironmentStore<R: Reducer, S: Store<R>>: DynamicProperty {
    
    /// The `EnvironmentValues` instance to access values from the environment.
    private let values: EnvironmentValues = .init()
    
    /// The observed `Store` instance. This store is observed for any changes, triggering UI updates when needed.
    @ObservedObject private var store: S
    
    /// The value of the `Store` retrieved from the environment. This value is wrapped
    /// and exposed to SwiftUI views.
    public var wrappedValue: S {
        get { store }
        set {
            store = newValue
        }
    }
    
    /// Initializes the `EnvironmentStore` by accessing the `Store` from the environment
    /// using the provided `KeyPath`.
    ///
    /// - Parameter keyPath: A key path to the `Store` in `EnvironmentValues`.
    public init(_ keyPath: KeyPath<EnvironmentValues, S>) {
        self.store = values[keyPath: keyPath]
    }
}
