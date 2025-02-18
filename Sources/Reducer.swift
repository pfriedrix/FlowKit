/// A protocol that defines the basic requirements for a reducer in a state management system.
///
/// The `Reducer` protocol is responsible for handling actions and updating
/// the state accordingly. Reducers take the current state and an action,
/// and return an effect that can update the state or trigger side effects.
///
/// This protocol is asynchronous, allowing for the handling of state updates
/// that involve async operations, such as network requests.
///
/// - Parameters:
///   - State: The type representing the state managed by the reducer.
///   - Action: The type representing the actions handled by the reducer.
public protocol Reducer<State, Action> {
    
    /// The type of state being stored.
    associatedtype State: Sendable
    
    /// The type of action that may trigger state transitions.
    associatedtype Action: Sendable
    
    /// Reduces the current state by applying the given action.
    ///
    /// This method modifies the state based on the provided action and returns
    /// an effect that may include additional state changes or trigger side effects.
    ///
    /// - Parameters:
    ///   - state: The current state of the application, which will be modified by the action.
    ///   - action: The action to apply to the state.
    /// - Returns: An effect that may trigger further state updates or actions.
    @MainActor func reduce(into state: inout State, action: Action) -> Effect<Action>
}
