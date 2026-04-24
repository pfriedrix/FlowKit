public import SwiftUI

/// A property wrapper that provides a convenient interface for accessing a shared store instance.
/// This wrapper observes changes in the store and automatically updates the UI accordingly,
/// integrating a centralized state management solution into SwiftUI views.
///
/// `wrappedValue` is read-only. The underlying `Store` is a reference type, so you can dispatch
/// actions and mutate its state through the returned instance — but you cannot rebind the handle
/// to a different store. For test-time overrides of what `StoreValues` resolves a key path to,
/// use `StoreValues.withValues { ... }` rather than assigning through `@Shared`.
///
/// - Generic Parameters:
///   - R: The type of the reducer responsible for processing actions and updating state.
///   - S: The type of the store that maintains application state and interacts with the reducer.
@propertyWrapper
@MainActor
public struct Shared<R: Reducer, S: Store<R>>: DynamicProperty {
    /// The store instance resolved from `StoreValues._global` at init time.
    /// Changes to this store trigger UI updates via `@Observable`.
    private let store: S

    /// The underlying store instance resolved from the shared registry.
    /// SwiftUI views use this property to reflect state changes.
    public var wrappedValue: S { store }

    /// Initializes the Shared property wrapper by retrieving the store
    /// from the global store values using the provided key path.
    ///
    /// - Parameter keyPath: A key path to the store within the global store values repository.
    public init(_ keyPath: KeyPath<StoreValues, S>) {
        self.store = StoreValues._global[keyPath: keyPath]
    }
}
