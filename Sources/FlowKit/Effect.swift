
import Foundation
import SwiftUI

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
    /// - `run`: Executes an asynchronous task. When `cancellationId` is non-nil the
    ///   task is registered in the store's MainActor-isolated task registry and can
    ///   later be cancelled via `.cancel(id:)`.
    /// - `cancel`: Cancels any in-flight cancellable task associated with the given id.
    enum Operation {
        case none
        case send(Action)
        case merge([Action])
        case run(
            priority: TaskPriority?,
            cancellationId: AnyHashable?,
            cancelInFlight: Bool,
            operation: @Sendable (_ send: Send<Action>) async -> Void
        )
        case cancel(AnyHashable)
    }

    /// The operation that this effect represents.
    let operation: Operation

    /// Animation applied to the state mutations this effect triggers, if any.
    let animation: Animation?

    init(operation: Operation, animation: Animation? = nil) {
        self.operation = operation
        self.animation = animation
    }
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
        catch handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
    ) -> Self {
        Self(operation: .run(priority: priority, cancellationId: nil, cancelInFlight: false, operation: { send in
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
        }))
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

extension Effect {
    /// Returns `true` if this effect represents no operation.
    public var isNone: Bool {
        if case .none = operation { return true }
        return false
    }
}

extension Effect: Equatable where Action: Equatable {
    /// Structural equality for effects whose actions are `Equatable`.
    ///
    /// `.run` effects compare by `TaskPriority`, `cancellationId`, and
    /// `cancelInFlight` — the closure itself is treated as opaque, since
    /// closures cannot be compared.
    public static func == (lhs: Effect, rhs: Effect) -> Bool {
        switch (lhs.operation, rhs.operation) {
        case (.none, .none):
            return true
        case (.send(let a), .send(let b)):
            return a == b
        case (.merge(let a), .merge(let b)):
            return a == b
        case let (.run(lhsP, lhsId, lhsCancel, _), .run(rhsP, rhsId, rhsCancel, _)):
            return lhsP == rhsP && lhsId == rhsId && lhsCancel == rhsCancel
        case let (.cancel(lhsId), .cancel(rhsId)):
            return lhsId == rhsId
        default:
            return false
        }
    }
}

/// A type that sends actions, commonly used within async effects.
///
/// Used inside `.run` effect bodies to dispatch actions back to the store.
/// Call sites `await send(.action)` — the await hops the caller onto MainActor
/// for dispatch and resumes them on return. No internal Task spawning.
///
/// - Parameters:
///   - Action: The type of action to send.
public struct Send<Action>: Sendable {
    let send: @Sendable (Action) async -> Void

    public init(send: @escaping @Sendable (Action) async -> Void) {
        self.send = send
    }

    /// Dispatches an action on MainActor, unless the surrounding task is cancelled.
    public func callAsFunction(_ action: Action) async {
        guard !Task.isCancelled else { return }
        await self.send(action)
    }

    /// Dispatches an action to a shared store referenced by `keyPath` in `StoreValues`.
    public func callAsFunction<R: Reducer, S: Store<R>>(
        _ keyPath: sending KeyPath<StoreValues, S>,
        action: S.Action
    ) async {
        guard !Task.isCancelled else { return }
        await MainActor.run {
            StoreValues.current(keyPath).send(action)
        }
    }
}
