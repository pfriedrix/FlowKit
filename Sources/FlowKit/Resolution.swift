/// A type that encapsulates the result of a state reduction operation.
///
/// `Resolution` represents the outcome of applying an action to a state through a reducer.
/// It contains both the updated state and any side effects that should be executed as a result
/// of the state change. This type serves as the return value from state reduction operations,
/// providing a clean separation between state updates and effect handling.
///
/// The resolution pattern allows reducers to be pure functions that don't directly execute
/// side effects, while still being able to specify what effects should occur. This maintains
/// the predictability of state changes while enabling complex asynchronous workflows.
///
/// - Parameters:
///   - State: The type representing the application state being managed.
///   - Action: The type representing the actions that can trigger state changes.
struct Resolution<State: Sendable, Action: Sendable> {
    
    /// The updated state after the action has been applied.
    ///
    /// This represents the new state that should replace the current state in the store.
    /// The state is computed by the reducer based on the previous state and the dispatched action.
    let state: State
    
    /// The effect that should be executed as a result of the state change.
    ///
    /// Effects represent side effects such as network requests, database operations,
    /// or additional actions that should be dispatched. The effect is handled separately
    /// from the state update to maintain the purity of the reduction process.
    let effect: Effect<Action>
}
