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

        try await withCheckedThrowingContinuation { (outer: CheckedContinuation<Void, any Error>) in
            @Sendable func tryResume(_ result: Result<Void, any Error>) {
                let alreadyResumed = resumed.withLock { flag -> Bool in
                    let previous = flag
                    flag = true
                    return previous
                }
                if !alreadyResumed {
                    outer.resume(with: result)
                }
            }

            Task { @MainActor in
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

                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms poll fallback
                            resumeInnerOnce()
                        }
                    }
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                tryResume(.failure(WaitForStateChangeTimeout()))
            }
        }
    }
}
