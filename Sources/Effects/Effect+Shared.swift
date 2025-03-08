extension Effect {
    /// Dispatches an action to a shared store instance.
    ///
    /// Use this function to send an action to a store referenced by the given key path in `StoreValues`.
    /// This allows multiple parts of an application to interact with the same store instance.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that identifies the `Store` within `StoreValues`.
    ///   - action: The action to be sent to the store.
    /// - Returns: An `Effect` that performs no additional work (`.none`).
    @MainActor
    public static func send<R: Reducer, S: Store<R>>(_ keyPath: KeyPath<StoreValues, S>, action: S.Action) -> Self {
        let values = StoreValues()
        let store = values[keyPath: keyPath]
        store.send(action)
        return .none
    }
}
