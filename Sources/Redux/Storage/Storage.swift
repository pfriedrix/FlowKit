/// Extension of `Store` that adds persistent storage capabilities for state management.
///
/// This extension allows the `Store` to automatically persist its state after each action
/// and restore its state during initialization. It is designed to work with states that conform
/// to the `Storable` protocol, which provides the `save` and `load` methods for managing persistence.
extension Store where State: Storable {
    
    /// Convenience initializer for `Store` that restores the state from storage if available.
    ///
    /// This initializer first attempts to restore the state from persistent storage using the `Storable.load()` method.
    /// If no saved state is found, or if the restoration fails, it defaults to the provided `default`.
    /// After initialization, the state is immediately saved to storage.
    ///
    /// - Parameters:
    ///   - reducer: The reducer that handles state updates and actions.
    ///   - default: The default state to use if no saved state is found.
    public convenience init(reducer: R, default state: State) {
        let restored = Self.restore()
        self.init(initial: restored ?? state , reducer: reducer)
        
        if restored == nil {
            logger.info("State restored from storage: \(state)")
            state.save()
        } else {
            logger.info("State default used: \(state)")
        }
    }
    
    /// Restores the saved state from persistent storage.
    ///
    /// This method uses the `Storable.load()` function to retrieve the state from persistent storage.
    /// If no valid state is found, it returns `nil`, allowing the store to use the provided `default`.
    ///
    /// - Returns: The restored state, or `nil` if no valid state is available.
    private static func restore() -> State? {
        State.load()
    }
    
    /// Dispatches an action to the store, triggering state updates and persisting the new state.
    ///
    /// This method asynchronously processes an action, allowing the reducer to apply changes to the state.
    /// After the state is updated, it is immediately saved to persistent storage using the `Storable.save()` method.
    /// All state changes are applied within the main actor context to ensure thread safety.
    ///
    /// - Parameter action: The action to be dispatched to the reducer for processing.
    @MainActor
    public func dispatch(_ action: Action) {
        logger.debug("Dispatching action: \(action)")
        
        dispatch(state, action)
        objectWillChange.send()
    }
    
    /// Handles the core logic for dispatching an action, reducing the state, and processing effects.
    ///
    /// This method uses the provided action to update the current state, then saves the updated state to storage.
    /// If the reducer returns an effect, it processes the effect, which may involve dispatching another action
    /// or performing asynchronous operations. This ensures that side effects are properly handled.
    ///
    /// - Parameters:
    ///   - state: The current state to be updated.
    ///   - action: The action to apply to the state.
    @MainActor
    internal func dispatch(_ state: State, _ action: Action) {
        var currentState = state
        let effect = reducer.reduce(into: &currentState, action: action)
        
        logger.info("New state after action \(action): \(currentState)")
        
        self.state = currentState
        self.state.save()
        
        switch effect.operation {
        case .none: return
        case let .send(action):
            dispatch(action)
        case let .run(priority, operation):
            Task(priority: priority) { [ weak self ] in
                await operation(Send { action in
                    self?.dispatch(action)
                })
            }
        }
    }
}
