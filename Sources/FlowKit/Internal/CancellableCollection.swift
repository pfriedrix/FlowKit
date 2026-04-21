import Foundation
import SwiftUI

/// Per-`Store` cancellation registry.
///
/// Commands (`register`, `cancel`) are sync-enqueued into an internal `AsyncStream`
/// and processed sequentially by a long-running driver task. This serializes all
/// register/cancel operations through one task, eliminating the race between
/// independent `Task { }` instances that plagued the previous design.
///
/// `register` and `cancel` from the same synchronous `send` chain are guaranteed to
/// be observed by the driver in submission order — so a cancel dispatched immediately
/// after a start always finds the freshly-registered entry.
actor CancellableCollection<Action: Sendable> {
    enum Command: @unchecked Sendable {
        // Marked `@unchecked Sendable` because `AnyHashable` and SwiftUI `Animation`
        // are not statically `Sendable`, though by API contract callers wrap values
        // that are `Hashable & Sendable` / thread-safe animation descriptors.
        case register(
            id: AnyHashable,
            cancelInFlight: Bool,
            priority: TaskPriority?,
            animation: Animation?,
            operation: @Sendable (Send<Action>) async -> Void
        )
        case cancel(id: AnyHashable)
    }

    private struct Entry: Sendable {
        let nonce: UUID
        let task: Task<Void, Never>
    }

    private var tasks: [AnyHashable: Entry] = [:]
    private nonisolated let continuation: AsyncStream<Command>.Continuation
    private nonisolated let sendAction: @Sendable (Action, Animation?) async -> Void

    init(sendAction: @escaping @Sendable (Action, Animation?) async -> Void) {
        let (stream, continuation) = AsyncStream.makeStream(of: Command.self)
        self.continuation = continuation
        self.sendAction = sendAction
        Task { [weak self] in
            await self?.process(inbox: stream)
        }
    }

    /// Signals the driver task to finish. The caller should invoke this when the
    /// owning scope (typically the `Store`) is tearing down. After shutdown, any
    /// remaining registered tasks are cancelled by the driver's cleanup path.
    nonisolated func shutdown() {
        continuation.finish()
    }

    /// Synchronously enqueues a command. Safe to call from any isolation.
    nonisolated func enqueue(_ command: Command) {
        continuation.yield(command)
    }

    var activeTaskCount: Int {
        tasks.count
    }

    func process(inbox: AsyncStream<Command>) async {
        for await command in inbox {
            handle(command)
        }
        // Stream finished — cancel any leftover tasks.
        tasks.values.forEach { $0.task.cancel() }
        tasks.removeAll()
    }

    private func handle(_ command: Command) {
        switch command {
        case let .register(id, cancelInFlight, priority, animation, operation):
            if cancelInFlight, let existing = tasks.removeValue(forKey: id) {
                existing.task.cancel()
            }
            let nonce = UUID()
            let sendAction = self.sendAction
            let boxedId = UncheckedSendableBox(id)
            let task = Task(priority: priority) { [weak self] in
                let send = Send<Action> { action in
                    guard !Task.isCancelled else { return }
                    Task { await sendAction(action, animation) }
                }
                await withTaskCancellationHandler {
                    await operation(send)
                } onCancel: {}
                await self?.removeIfCurrent(idBox: boxedId, nonce: nonce)
            }
            tasks[id] = Entry(nonce: nonce, task: task)

        case .cancel(let id):
            if let entry = tasks.removeValue(forKey: id) {
                entry.task.cancel()
            }
        }
    }

    private func removeIfCurrent(idBox: UncheckedSendableBox<AnyHashable>, nonce: UUID) {
        let id = idBox.value
        if tasks[id]?.nonce == nonce {
            tasks.removeValue(forKey: id)
        }
    }
}

/// Internal wrapper to pass non-`Sendable` values across isolation boundaries when
/// the value is known to be safely transferable by API contract.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
