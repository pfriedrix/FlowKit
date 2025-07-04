import SwiftUI

extension Store {
    
    /// Creates a `Binding` with a custom getter and action-based setter.
    /// - Parameters:
    ///   - get: A closure that returns the current value.
    ///   - set: A closure that takes the new value and returns an `Action` to be dispatched.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write using custom logic.
    @MainActor
    public func binding<Value>(
        get: @escaping @Sendable () -> Value,
        set: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { [ weak self ] newValue in
                guard let self else { return }
                send(set(newValue))
            }
        )
    }
    
    /// Creates a `Binding` with a custom getter that has access to the current state.
    /// - Parameters:
    ///   - get: A closure that receives the current state and returns a value.
    ///   - set: A closure that takes the new value and returns an `Action` to be dispatched.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write using custom logic.
    @MainActor
    public func binding<Value>(
        get: @escaping (State) -> Value,
        set: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { [ weak self ] in
                guard let self else { fatalError("Store is deallocated") }
                return get(state)
            },
            set: { [ weak self ] newValue in
                guard let self else { return }
                send(set(newValue))
            }
        )
    }
    
    /// Creates a `Binding` for a property in the store's state.
    /// - Parameters:
    ///   - keyPath: A key path to the specific property in the store's state that you want to bind to.
    ///   - action: A closure that takes the new value of the property and returns an `Action`
    ///             to be dispatched, updating the state accordingly.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write to the value at the specified key path.
    @MainActor
    public func binding<Value>(for keyPath: KeyPath<State, Value>, set action: @escaping (Value) -> Action) -> Binding<Value> {
        Binding(
            get: { [weak self] in
                guard let self else { fatalError("Store is deallocated") }
                return state[keyPath: keyPath]
            },
            set: { [ weak self ] newValue in
                guard let self else { return }
                send(action(newValue))
            }
        )
    }
    
    /// Creates a `Binding` for a property in the store's state, directly dispatching a specific `Action`.
    /// - Parameters:
    ///   - keyPath: A key path to the specific property in the store's state that you want to bind to.
    ///   - action: An `Action` that will be dispatched every time the value changes.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write to the value at the specified key path.
    @MainActor
    public func binding<Value>(for keyPath: KeyPath<State, Value>, set action: Action) -> Binding<Value> {
        Binding(
            get: { [ weak self ] in
                guard let self else { fatalError("Store is deallocated") }
                return state[keyPath: keyPath]
            },
            set: { [ weak self ] _ in
                guard let self else { return }
                send(action)
            }
        )
    }
}

extension Store where State: Storable {
    /// Creates a `Binding` with a custom getter and action-based setter.
    /// - Parameters:
    ///   - get: A closure that returns the current value.
    ///   - set: A closure that takes the new value and returns an `Action` to be dispatched.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write using custom logic.
    @MainActor
    public func binding<Value>(
        get: @escaping @Sendable () -> Value,
        set: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { [ weak self ] newValue in
                guard let self else { return }
                send(set(newValue))
            }
        )
    }
    
    /// Creates a `Binding` with a custom getter that has access to the current state.
    /// - Parameters:
    ///   - get: A closure that receives the current state and returns a value.
    ///   - set: A closure that takes the new value and returns an `Action` to be dispatched.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write using custom logic.
    @MainActor
    public func binding<Value>(
        get: @Sendable @escaping (State) -> Value,
        set: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { [ weak self ] in
                guard let self else { fatalError("Store is deallocated") }
                return get(state)
            },
            set: { [weak self] newValue in
                guard let self else { return }
                send(set(newValue))
            }
        )
    }
    
    /// Creates a `Binding` for a property in the store's state.
    /// - Parameters:
    ///   - keyPath: A key path to a specific property in the store's state.
    ///   - action: A closure that takes the new value of the property and returns an `Action`
    ///             to be dispatched in order to update the state.
    /// - Returns: A `Binding` to the value at the provided key path.
    ///
    /// This method is rewritten here for the `Codable` state to provide future flexibility.
    /// While the functionality remains identical, having this version under the `Codable`
    /// constraint allows for possible extensions or adjustments when dealing with
    /// serializable states, such as when you might need to encode, decode, or persist the state.
    @MainActor
    public func binding<Value>(for keyPath: KeyPath<State, Value>, set action: @escaping (Value) -> Action) -> Binding<Value> {
        Binding(
            get: { [ weak self ] in
                guard let self else { fatalError("Store is deallocated") }
                return state[keyPath: keyPath]
            },
            set: { [ weak self ] newValue in
                guard let self else { return }
                send(action(newValue))
            }
        )
    }
    
    /// Creates a `Binding` for a property in the store's state, directly dispatching a specific `Action`.
    /// - Parameters:
    ///   - keyPath: A key path to the specific property in the store's state that you want to bind to.
    ///   - action: An `Action` that will be dispatched every time the value changes.
    /// - Returns: A `Binding` that allows SwiftUI views to read and write to the value at the specified key path.
    @MainActor
    public func binding<Value>(for keyPath: KeyPath<State, Value>, set action: Action) -> Binding<Value> {
        Binding(
            get: { [ weak self ] in
                guard let self else { fatalError("Store is deallocated") }
                return state[keyPath: keyPath]
            },
            set: { [ weak self ] _ in
                guard let self else { return }
                send(action)
            }
        )
    }
}
