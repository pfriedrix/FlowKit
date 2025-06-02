extension Effect {
    /// Returns a new effect that can be cancelled by a unique identifier.
    ///
    /// This method wraps the existing `operation` within a cancellable context,
    /// allowing it to be cancelled by the provided `id`. If `cancelInFlight` is true,
    /// any in-flight operation with the same `id` is cancelled before this effect runs.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the cancellable effect.
    ///   - cancelInFlight: A Boolean value indicating whether to cancel any existing
    ///     in-flight operation with the same `id` before starting this effect.
    /// - Returns: A new effect that wraps the original operation in a cancellable context.
    public func cancellable(id: some Hashable & Sendable, cancelInFlight: Bool = false) -> Self {
        switch self.operation {
        case .none, .send:
            return .none
        case let .run(priority, operation):
            return Self(
                operation: .run(priority) { send in
                    await Self.withTaskCancellation(id: id, cancelInFlight: cancelInFlight) {
                        await operation(send)
                    }
                }
            )
        }
    }
    
    /// Manages the creation of a task with cancellation support.
    ///
    /// This method handles the cancellation of any existing task with the same `id`
    /// if `cancelInFlight` is set to true. It then creates and tracks a new task
    /// in `_cancellationCollection`.
    ///
    /// - Parameters:
    ///   - id: A unique identifier used to track and cancel the task.
    ///   - cancelInFlight: A Boolean value that determines whether to cancel an
    ///     existing task with the same `id` before starting a new one.
    ///   - operation: An asynchronous operation to execute within the task.
    public static func withTaskCancellation(id: some Hashable & Sendable,
                                     cancelInFlight: Bool = false,
                                     operation: @escaping @Sendable () async throws -> Void) async {
        if cancelInFlight {
            await _cancellationCollection.cancel(withKey: id)
        }
        
        let task = Task {
            if Task.isCancelled {
                await Logger.shared.debug("Task \(id): cancelled")
                return
            }
            try await operation()
        }
        await _cancellationCollection.add(task: task, withKey: id)
    }
    
    /// Cancels an effect with the specified identifier.
    ///
    /// This method cancels any in-flight operation associated with the provided `id`.
    ///
    /// - Parameter id: A unique identifier for the effect to cancel.
    /// - Returns: An effect that performs no additional operations.
    public static func cancel(id: some Hashable & Sendable) -> Self {
        return .run { _ in
            await _cancellationCollection.cancel(withKey: id)
        }
    }
}
