import Foundation

@_spi(Internals)
public actor CancellableCollection {
    private struct Entry {
        let nonce: UUID
        let task: Task<Void, any Error>
    }

    private var tasks: [AnyHashable: Entry] = [:]

    /// Atomically cancels any existing task for `key` (when `cancelInFlight` is true), constructs
    /// a new task via `makeTask`, stores it under `key`, and returns a nonce that uniquely
    /// identifies this registration.
    ///
    /// The entire body runs in a single non-suspending actor step, so no concurrent
    /// `cancel(withKey:)` can observe the collection between the optional in-flight cancel and
    /// the new registration.
    public func register<Key: Hashable & Sendable>(
        key: Key,
        cancelInFlight: Bool,
        makeTask: (UUID) -> Task<Void, any Error>
    ) -> UUID {
        let anyKey = AnyHashable(key)
        if cancelInFlight {
            tasks[anyKey]?.task.cancel()
            tasks.removeValue(forKey: anyKey)
        }
        let nonce = UUID()
        let task = makeTask(nonce)
        tasks[anyKey] = Entry(nonce: nonce, task: task)
        return nonce
    }

    /// Removes the entry for `key` only if it is still the registration identified by `nonce`.
    /// This prevents a late-finishing task from evicting a newer registration that reused the
    /// same `key`.
    public func removeIfCurrent<Key: Hashable & Sendable>(key: Key, nonce: UUID) {
        let anyKey = AnyHashable(key)
        if tasks[anyKey]?.nonce == nonce {
            tasks.removeValue(forKey: anyKey)
        }
    }

    /// Adds a new task to the collection with a specified key.
    ///
    /// This method associates the given task with the specified key in the collection.
    /// If a task already exists with the same key, it will be replaced with the new task.
    /// Entries added via this method are not auto-removed on completion; use `register` for
    /// auto-cleaning registrations.
    ///
    /// - Parameters:
    ///   - key: The key used to associate with the task. Must be `Hashable & Sendable`.
    ///   - task: The `Task` instance to add to the collection.
    public func add<Key: Hashable & Sendable>(task: Task<Void, any Error>, withKey key: Key) {
        tasks[AnyHashable(key)] = Entry(nonce: UUID(), task: task)
    }

    /// Cancels and removes a task with the specified key.
    ///
    /// This method cancels the task associated with the given key, if it exists,
    /// and then removes it from the collection.
    ///
    /// - Parameter key: The key of the task to cancel and remove.
    public func cancel<Key: Hashable & Sendable>(withKey key: Key) {
        let anyKey = AnyHashable(key)
        tasks[anyKey]?.task.cancel()
        tasks.removeValue(forKey: anyKey)
    }

    /// Cancels and removes all tasks in the collection.
    ///
    /// This method cancels all active tasks stored in the collection and clears the collection.
    public func cancelAll() {
        tasks.values.forEach { $0.task.cancel() }
        tasks.removeAll()
    }

    /// Removes a task with the specified key without cancelling it.
    ///
    /// This method removes the task associated with the given key from the collection
    /// without calling its `cancel()` method.
    ///
    /// - Parameter key: The key of the task to remove.
    public func remove<Key: Hashable & Sendable>(withKey key: Key) {
        tasks.removeValue(forKey: AnyHashable(key))
    }

    /// Returns the current number of active tasks in the collection.
    ///
    /// This method provides visibility into the collection's state for monitoring purposes.
    ///
    /// - Returns: The number of tasks currently stored in the collection.
    public var activeTaskCount: Int {
        tasks.count
    }
}

let _cancellationCollection = CancellableCollection()
