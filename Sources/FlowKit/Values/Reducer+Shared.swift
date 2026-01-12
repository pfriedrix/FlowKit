
import Foundation

extension Reducer {
    /// Retrieves the current state from a shared store instance.
    ///
    /// Use this function to access the state of a store referenced by the given key path in `StoreValues`.
    /// This allows reducers to read state from other shared store instances.
    ///
    /// - Parameter keyPath: A key path that identifies the `Store` within `StoreValues`.
    /// - Returns: The current state of the shared store.
    @MainActor
    public func shared<R: Reducer, S: Store<R>>(
        _ keyPath: KeyPath<StoreValues, S>
    ) -> R.State {
        let values = StoreValues()
        let store = values[keyPath: keyPath]
        return store.state
    }
}
