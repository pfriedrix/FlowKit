extension Effect {
    /// Marks this effect as cancellable by a unique identifier.
    ///
    /// Embeds the `id` into the `.run` operation as metadata. When the store handles the
    /// effect, it enqueues a `.register` command to the per-store `CancellableCollection`
    /// synchronously on the reducer's isolation, guaranteeing register/cancel ordering
    /// with any subsequent `.cancel(id:)` dispatched in the same `send` chain.
    ///
    /// Only applies to `.run` effects; other operations are returned unchanged.
    ///
    /// - Note: For cancellation to actually stop work, `operation` must be cancellation-aware
    ///   (use `try await Task.sleep`, `try Task.checkCancellation()`, or other APIs that
    ///   observe `Task.isCancelled`).
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the cancellable effect.
    ///   - cancelInFlight: If true, any in-flight task registered under the same id is
    ///     cancelled before this one starts.
    /// - Returns: A new effect with the cancellation metadata attached.
    public func cancellable(id: some Hashable & Sendable, cancelInFlight: Bool = false) -> Self {
        switch self.operation {
        case let .run(priority, _, _, operation):
            return Self(
                operation: .run(
                    priority: priority,
                    cancellationId: AnyHashable(id),
                    cancelInFlight: cancelInFlight,
                    operation: operation
                ),
                animation: self.animation
            )
        case .none, .send, .merge, .cancel:
            return self
        }
    }

    /// Returns an effect that cancels any in-flight cancellable task registered with `id`.
    ///
    /// The returned effect is pure data; the actual cancellation is performed synchronously
    /// by the store when the effect is handled, on the same isolation as the enclosing
    /// `send`. This guarantees that if a matching `.cancellable(id:)` was dispatched in the
    /// preceding `send`, the cancel will observe its registration.
    public static func cancel(id: some Hashable & Sendable) -> Self {
        Self(operation: .cancel(AnyHashable(id)))
    }
}
