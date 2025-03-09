import SwiftUI

/// A property wrapper that provides a convenient interface for accessing a shared store instance.
/// This wrapper observes changes in the store and automatically updates the UI accordingly,
/// integrating a centralized state management solution into SwiftUI views.
///
/// - Generic Parameters:
///   - R: The type of the reducer responsible for processing actions and updating state.
///   - S: The type of the store that maintains application state and interacts with the reducer.
@propertyWrapper
@MainActor
public struct Shared<R: Reducer, S: Store<R>>: DynamicProperty {
    /// A reference to the shared store values repository.
    let values: StoreValues

    /// The observed store instance. Changes to this store trigger UI updates.
    @ObservedObject private var store: S

    /// The underlying store instance accessed from the shared repository.
    /// SwiftUI views use this property to reflect state changes.
    public var wrappedValue: S {
        get { store }
        set { store = newValue }
    }

    /// Initializes the Shared property wrapper by retrieving the store
    /// from the global store values using the provided key path.
    ///
    /// - Parameter keyPath: A key path to the store within the global store values repository.
    public init(_ keyPath: KeyPath<StoreValues, S>) {
        self.values = StoreValues._global
        self.store = values[keyPath: keyPath]
    }
}
