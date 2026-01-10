/// A type that represents an effect which can trigger a side effect in a state management system.
///
/// `Effect` encapsulates a state-dependent operation, allowing optional actions
/// to be dispatched as part of a state change, commonly used with reducers to
/// handle asynchronous tasks or side effects.
///
/// - Parameters:
///   - Action: The type of action the effect can dispatch.
public struct Effect<Action: Sendable> {
    /// An enumeration describing the types of operations an `Effect` can perform.
    ///
    /// - `none`: Represents the absence of an effect.
    /// - `send`: Directly sends an action.
    /// - `merge`: Sends multiple actions sequentially.
    /// - `run`: Executes an asynchronous task...
    enum Operation {
        case none
        case send(Action)
        case merge([Action])
        case run(TaskPriority? = nil, @Sendable (_ send: Send<Action>) async -> Void)
    }
    
    /// The operation that this effect represents.
    let operation: Operation
}

extension Effect {
    /// A no-operation effect.
    ///
    /// Use this static property when no effect is needed, making it easier to return
    /// an effect without additional behavior.
    public static var none: Self {
        return Self(operation: .none)
    }
    
    /// Creates an asynchronous effect that can trigger multiple actions during its execution.
    ///
    /// - Parameters:
    ///   - priority: The priority for the asynchronous task. Default is `nil`.
    ///   - operation: A closure representing the asynchronous task.
    ///   - handler: A closure to handle errors thrown by the operation, if any.
    /// - Returns: An `Effect` that runs the specified operation.
    public static func run(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
        catch handler: (@Sendable (_ error: Error, _ send: Send<Action>) async -> Void)? = nil
    ) -> Self {
        Self(operation: .run(priority) { send in
            do {
                try await operation(send)
            } catch {
                guard let handler = handler else {
                    #if DEBUG
                    Logger.shared.fault("🚨 UNHANDLED EFFECT ERROR: \(error)")
                    Logger.shared.fault("📍 This error was silently swallowed! Add error handling.")
                    #else
                    Logger.shared.error("Unhandled effect error (silent failure): \(error)")
                    #endif
                    return  
                }
                await handler(error, send)
            }
        })
    }
    
    /// Creates an effect that immediately sends an action.
    ///
    /// - Parameter action: The action to be sent.
    /// - Returns: An `Effect` that dispatches the specified action.
    public static func send(_ action: Action) -> Self {
        Self(operation: .send(action))
    }
    
    /// Creates an effect that sends multiple actions sequentially.
    ///
    /// - Parameter actions: The actions to be sent in order.
    /// - Returns: An `Effect` that dispatches the specified actions.
    public static func merge(_ actions: Action...) -> Self {
        guard !actions.isEmpty else { return .none }
        return Self(operation: .merge(actions))
    }
}

extension Effect.Operation: Equatable {
    /// Compares two `Effect.Operation` values for equality.
    ///
    /// This implementation considers only the `none` case and compares the `TaskPriority`
    /// values for `run` cases. `send` operations are considered unequal as actions can vary.
    static func == (lhs: Effect.Operation, rhs: Effect.Operation) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.merge, .merge):
            return true
        case (.run(let lhsPriority, _), .run(let rhsPriority, _)):
            return lhsPriority == rhsPriority
        default:
            return false
        }
    }
}

/// A type that sends actions, commonly used within async effects.
///
/// `Send` is utilized to dispatch actions during the execution of an effect.
/// It ensures actions are sent to the main actor to update the UI safely.
///
/// - Parameters:
///   - Action: The type of action to send.
public struct Send<Action>: Sendable {
    /// A closure that sends the specified action.
    let send: @Sendable (Action) -> Void
    
    /// Creates a new `Send` instance with a given action dispatcher.
    ///
    /// - Parameter send: A closure to dispatch actions.
    public init(send: @escaping @Sendable (Action) -> Void) {
        self.send = send
    }
    
    /// Dispatches an action, unless the task is canceled.
    ///
    /// - Parameter action: The action to be sent.
    public func callAsFunction(_ action: Action) {
        guard !Task.isCancelled else { return }
        self.send(action)
    }
}
