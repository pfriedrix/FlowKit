import Foundation

/// A class responsible for managing the application's state and dispatching actions.
///
/// The `Store` class holds the application's state and provides a mechanism to dispatch
/// actions, which are handled by the associated reducer. The reducer updates the state
/// based on the action, and the store publishes the new state to any observing views or objects.
///
/// This class also handles asynchronous state updates and supports side effects through the
/// reducer's `Effect` mechanism.
///
/// - Parameters:
///   - R: The type of the reducer, which conforms to the `Reducer` protocol and defines
///        the state's structure and how actions are handled.
final public class Store<R: Reducer>: ObservableObject {
    
    /// The type representing the current state of the store.
    public typealias State = R.State
    
    /// The type representing the actions handled by the store.
    public typealias Action = R.Action
    
    /// The current state of the store.
    public internal(set) var state: State
    
    /// The reducer responsible for handling actions and updating the state.
    let reducer: R
    
    /// Logger instance for tracking state changes and actions.
    let logger = Logger.shared
    
    /// The name of the store, based on the reducer type.
    lazy var name: String = String(describing: type(of: reducer))
    
    /// Task storage for automatic cleanup
    private var tasks: [UUID: Task<Void, Never>] = [:]
    
    deinit {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
    
    /// Initializes the store with an initial state and a reducer.
    ///
    /// - Parameters:
    ///   - initial: The initial state of the store.
    ///   - reducer: The reducer that will handle actions and state updates.
    public required init(initial: State, reducer: R) {
        self.state = initial
        self.reducer = reducer
        logger.info("\(name): store initialized")
    }
    
    /// Sends an action to the store, triggering a state update.
    ///
    /// This method processes the action through the reducer, applies any state updates,
    /// and triggers associated effects, which may include additional actions or asynchronous operations.
    ///
    /// - Parameter action: The action to send to the reducer for processing.
    @MainActor
    public func send(_ action: Action) {
        logger.action("\(name).\(action)")
        
        dispatch(state, action)
    }
    
    /// Handles the dispatching of actions and state updates asynchronously.
    ///
    /// This method invokes the reducer to process the action and returns an effect. If the effect
    /// includes a new action, the method recursively dispatches the action until no further actions
    /// are returned.
    ///
    /// - Parameters:
    ///   - state: The current state before the action is applied.
    ///   - action: The action to process and apply to the state.
    @MainActor
    private func dispatch(_ state: State, _ action: Action) {
        let result = resolve(state, action)
        
        objectWillChange.send()
        self.state = result.state
        
        handle(result.effect)
    }
    
    /// Runs a task with automatic cleanup
    @MainActor
    func runTask(priority: TaskPriority?, operation: @escaping @Sendable (Send<Action>) async -> Void) {
        let taskId = UUID()
        let task = Task(priority: priority) { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    if let task = self?.tasks.removeValue(forKey: taskId) {
                        task.cancel()
                    }
                }
            }
            await operation(Send { [weak self] action in
                guard !Task.isCancelled, let self = self else { return }
                self.send(action)
            })
        }
        tasks[taskId] = task
    }
    
    /// Resolves the action by applying it to the current state, and returns an effect.
    ///
    /// This method uses the reducer to process the action, updating the state and generating
    /// an effect if necessary. The new state and effect are returned to be handled asynchronously.
    ///
    /// - Parameters:
    ///   - state: The state to update.
    ///   - action: The action applied to update the state.
    /// - Returns: An effect that may trigger further actions or operations.
    func resolve(_ state: State, _ action: Action) -> Resolution<State, Action> {
        var currentState = state
        let effect = reducer.reduce(into: &currentState, action: action)
        
        logger.info("\(name): resolve `\(action)`: \(currentState)")
        
        return .init(state: currentState, effect: effect)
    }
    
    /// Handles the provided effect, performing any operations or additional actions it specifies.
    ///
    /// This method executes the effect's operation, which may be synchronous or asynchronous.
    /// Asynchronous operations are scheduled with a task to ensure proper execution.
    ///
    /// - Parameter effect: The effect to be handled.
    @MainActor
    private func handle(_ effect: Effect<Action>) {
        switch effect.operation {
        case .none: return
        case let .send(action):
            send(action)
        case let .run(priority, operation):
            runTask(priority: priority, operation: operation)
        }
    }
}

extension Store: @unchecked Sendable { }
