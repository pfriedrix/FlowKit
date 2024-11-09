@_spi(Internals)
public actor CancellableCollection {
    // Dictionary to store tasks with their associated keys for easy cancellation and tracking.
    private var tasks: [AnyHashable: Task<Void, any Error>] = [:]

    /// Adds a new task to the collection with a specified key.
    ///
    /// This method associates the given task with the specified key in the collection.
    /// If a task already exists with the same key, it will be replaced with the new task.
    ///
    /// - Parameters:
    ///   - key: The key used to associate with the task. This key must conform to `AnyHashable`.
    ///   - task: The `Task` instance to add to the collection.
    public func add(task: Task<Void, any Error>, withKey key: AnyHashable) {
        tasks[key] = task
    }

    /// Cancels and removes a task with the specified key.
    ///
    /// This method cancels the task associated with the given key, if it exists,
    /// and then removes it from the collection.
    ///
    /// - Parameter key: The key of the task to cancel and remove.
    public func cancel(withKey key: AnyHashable) {
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }

    /// Cancels and removes all tasks in the collection.
    ///
    /// This method cancels all active tasks stored in the collection and clears the collection.
    public func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    /// Removes a task with the specified key without cancelling it.
    ///
    /// This method removes the task associated with the given key from the collection
    /// without calling its `cancel()` method.
    ///
    /// - Parameter key: The key of the task to remove.
    public func remove(withKey key: AnyHashable) {
        tasks.removeValue(forKey: key)
    }
}

@_spi(Internals)
public let _cancellationCollection = CancellableCollection()
