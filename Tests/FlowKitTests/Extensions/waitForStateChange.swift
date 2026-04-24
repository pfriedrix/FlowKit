import XCTest
import Observation
import os

struct WaitForStateChangeTimeout: Error {}

extension XCTestCase {
    /// Awaits until `condition` returns true. Driven primarily by `@Observable`
    /// state changes (re-evaluates on every Observation fire), with a 100ms
    /// polling fallback so conditions that read non-observable state (e.g. locks)
    /// still resolve. Throws `WaitForStateChangeTimeout` if `timeout` elapses.
    ///
    /// - Parameters:
    ///   - timeout: Maximum time to wait, in seconds.
    ///   - condition: Closure evaluating state. Reads of `@Observable` state
    ///     register subscriptions and trigger prompt re-evaluation.
    @MainActor
    func waitForStateChange(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        if condition() { return }

        let resumed = OSAllocatedUnfairLock<Bool>(initialState: false)
        let tasks = OSAllocatedUnfairLock<(waiter: Task<Void, Never>?, timeout: Task<Void, Never>?)>(
            initialState: (nil, nil)
        )

        try await withCheckedThrowingContinuation { (outer: CheckedContinuation<Void, any Error>) in
            @Sendable func tryResume(_ result: Result<Void, any Error>) {
                let alreadyResumed = resumed.withLock { flag -> Bool in
                    let previous = flag
                    flag = true
                    return previous
                }
                guard !alreadyResumed else { return }
                let (waiter, timeoutTask) = tasks.withLock { $0 }
                waiter?.cancel()
                timeoutTask?.cancel()
                outer.resume(with: result)
            }

            let waiter = Task { @MainActor in
                while !Task.isCancelled {
                    if condition() {
                        tryResume(.success(()))
                        return
                    }
                    await withCheckedContinuation { (inner: CheckedContinuation<Void, Never>) in
                        let innerResumed = OSAllocatedUnfairLock<Bool>(initialState: false)
                        @Sendable func resumeInnerOnce() {
                            let already = innerResumed.withLock { flag -> Bool in
                                let prev = flag
                                flag = true
                                return prev
                            }
                            if !already { inner.resume() }
                        }

                        withObservationTracking {
                            _ = condition()
                        } onChange: {
                            Task { @MainActor in resumeInnerOnce() }
                        }

                        // 100ms poll fallback — also the max delay after cancellation
                        // before the loop observes `Task.isCancelled` and exits, since
                        // `withCheckedContinuation` ignores cancellation.
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            resumeInnerOnce()
                        }
                    }
                }
            }

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                tryResume(.failure(WaitForStateChangeTimeout()))
            }

            tasks.withLock { $0 = (waiter, timeoutTask) }
        }
    }
}
