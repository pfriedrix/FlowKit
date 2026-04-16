
import Foundation

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
        let queue = DispatchQueue(label: "flowkit.\(name).save", qos: .background)
        willSave = { snapshot in queue.async { snapshot.save() } }

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
}
