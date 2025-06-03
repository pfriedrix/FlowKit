/// Extension of `Store` that adds persistent storage capabilities for state management.
///
/// This extension allows the `Store` to automatically persist its state after each action
/// and restore its state during initialization. It is designed to work with states that conform
/// to the `Storable` protocol, which provides the `save` and `load` methods for managing persistence.
///
/// When using this extension, the store will automatically save the state after every action,
/// ensuring that the application state is preserved across app launches and terminations.
extension Store where State: Storable {
    
    /// Convenience initializer for `Store` that restores the state from storage if available.
    ///
    /// This initializer first attempts to restore the state from persistent storage using the `Storable.load()` method.
    /// If a saved state is found and successfully loaded, it uses that state; otherwise, it defaults to the provided
    /// `default` state. When using the default state, it immediately saves it to storage for future sessions.
    ///
    /// - Parameters:
    ///   - reducer: The reducer that handles state updates and actions.
    ///   - default: The default state to use if no saved state is found or restoration fails.
    public convenience init(reducer: R, default state: State) {
        let restored = Self.restore()
        self.init(initial: restored ?? state, reducer: reducer)
        
        if let _ = restored {
            logger.info("\(name): state restored from storage")
        } else {
            logger.info("\(name): using default state")
            self.state.save()
        }
    }
    
    /// Restores the saved state from persistent storage.
    ///
    /// This method uses the `Storable.load()` function to retrieve the state from persistent storage.
    /// If no valid state is found, it returns `nil`, allowing the store to use the provided default.
    ///
    /// - Returns: The restored state, or `nil` if no valid state is available.
    private static func restore() -> State? {
        State.load()
    }
    
    /// Sends an action to the store, triggering a state update with automatic persistence.
    ///
    /// This method processes the action through the reducer, applies any state updates,
    /// automatically saves the new state to storage, and triggers associated effects.
    /// This ensures that all state changes are immediately persisted.
    ///
    /// - Parameter action: The action to send to the reducer for processing.
    @MainActor
    public func send(_ action: Action) {
        logger.action("\(name).\(action)")
        
        dispatch(state, action)
        objectWillChange.send()
    }
    
    /// Handles the core logic for dispatching an action with automatic state persistence.
    ///
    /// This method uses the provided action to update the current state through the reducer,
    /// then immediately saves the updated state to storage. If the reducer returns an effect,
    /// it processes that effect, which may involve dispatching additional actions or performing
    /// asynchronous operations.
    ///
    /// The automatic saving ensures that no state changes are lost, even if the app is
    /// terminated unexpectedly after an action is processed.
    ///
    /// - Parameters:
    ///   - state: The current state to be updated.
    ///   - action: The action to apply to the state.
    @MainActor
    private func dispatch(_ state: State, _ action: Action) {
        let result = resolve(state, action)
        
        self.state = result.state
        self.state.save()
        
        handle(result.effect)
    }
    
    /// Handles the provided effect, performing any operations or additional actions it specifies.
    ///
    /// This method executes the effect's operation, which may be synchronous or asynchronous.
    /// Asynchronous operations are scheduled with a task to ensure proper execution while
    /// maintaining the automatic persistence behavior of the storage-enabled store.
    ///
    /// - Parameter effect: The effect to be handled.
    @MainActor
    private func handle(_ effect: Effect<Action>) {
        switch effect.operation {
        case .none:
            return
        case let .send(action):
            send(action)
        case let .run(priority, operation):
            Task(priority: priority) { [weak self] in
                await operation(Send { action in
                    self?.send(action)
                })
            }
        }
    }
}
