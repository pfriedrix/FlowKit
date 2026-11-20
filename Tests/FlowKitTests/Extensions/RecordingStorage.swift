import Foundation
import os
@testable import FlowKit

/// A storage that records every state it is asked to save, in arrival order,
/// together with whether the save arrived on the main thread.
///
/// Saves land on the store's background queue, so a test waits for the number
/// of saves it expects (`saves.count`) before asserting. That stays correct
/// when the final state equals an earlier one, where waiting on the value
/// alone could stop at the earlier save.
final class RecordingStorage<State: Sendable>: StateStorage {
    private struct Save {
        let state: State
        let onMainThread: Bool
    }

    private let restoring: State?
    private let lock = OSAllocatedUnfairLock(initialState: [Save]())

    /// - Parameter restoring: What `load()` returns, i.e. the state the store
    ///   starts from. `nil` makes the store start from its default state.
    init(restoring: State? = nil) {
        self.restoring = restoring
    }

    var saves: [State] {
        lock.withLock { $0.map(\.state) }
    }

    var savesOnMainThread: [Bool] {
        lock.withLock { $0.map(\.onMainThread) }
    }

    func load() -> State? {
        restoring
    }

    func save(_ state: State) {
        let save = Save(state: state, onMainThread: Thread.isMainThread)
        lock.withLock { $0.append(save) }
    }
}
