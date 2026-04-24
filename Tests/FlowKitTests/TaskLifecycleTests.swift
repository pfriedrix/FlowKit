import XCTest
@testable import FlowKit

final class AsyncTaskReducer: Reducer {
    struct State {
        var completedCount: Int = 0
    }

    enum Action {
        case startShortTask
        case startLongTask
        case taskCompleted
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startShortTask:
            return .run { send in
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                await send(.taskCompleted)
            } catch: { _, _ in }
        case .startLongTask:
            return .run { send in
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                await send(.taskCompleted)
            } catch: { _, _ in }
        case .taskCompleted:
            state.completedCount += 1
            return .none
        }
    }
}

@MainActor
final class TaskLifecycleTests: XCTestCase {

    // Test 1: Task entry is removed from the dictionary after the effect completes.
    func testTaskRemovedFromDictionaryAfterCompletion() async throws {
        let store = Store(initial: AsyncTaskReducer.State(), reducer: AsyncTaskReducer())

        store.send(.startShortTask)

        // With lock-based cleanup, removeValue runs on the background thread immediately
        // after the operation finishes — potentially before send(.taskCompleted) is
        // dispatched to MainActor. Wait for both to avoid a flaky assertion.
        try await waitForStateChange(timeout: 2.0) {
            store.tasks.isEmpty && store.state.completedCount == 1
        }

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(store.state.completedCount, 1)
    }

    // Test 2: Task is registered while running, then removed after completion.
    func testTaskCountDuringAndAfterExecution() async throws {
        let store = Store(initial: AsyncTaskReducer.State(), reducer: AsyncTaskReducer())

        store.send(.startShortTask)
        XCTAssertEqual(store.tasks.count, 1, "Task must be registered synchronously before async body runs")

        try await waitForStateChange(timeout: 2.0) {
            store.tasks.isEmpty
        }

        XCTAssertTrue(store.tasks.isEmpty)
    }

    // Test 3: Multiple concurrent tasks are all removed after they complete.
    func testMultipleTasksAllCleanedUp() async throws {
        let store = Store(initial: AsyncTaskReducer.State(), reducer: AsyncTaskReducer())

        store.send(.startShortTask)
        store.send(.startShortTask)
        store.send(.startShortTask)

        XCTAssertEqual(store.tasks.count, 3, "All three tasks must be registered")

        try await waitForStateChange(timeout: 2.0) {
            store.state.completedCount == 3 && store.tasks.isEmpty
        }

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(store.state.completedCount, 3)
    }

    // Test 4: Race condition — new tasks are added while previous ones are completing.
    // With 10ms between sends and 50ms task sleep, ~5 tasks overlap at any moment,
    // producing continuous concurrent add (MainActor) + remove (background) on tasksLock.
    func testConcurrentAddAndRemoveDoesNotCrash() async throws {
        let store = Store(initial: AsyncTaskReducer.State(), reducer: AsyncTaskReducer())

        for _ in 0..<20 {
            store.send(.startShortTask)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        try await waitForStateChange(timeout: 5.0) {
            store.state.completedCount == 20 && store.tasks.isEmpty
        }

        XCTAssertEqual(store.state.completedCount, 20)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    // Test 5: Deallocating the store while a task is still running does not crash.
    // deinit cancels the task; the background cleanup then hits self?.tasksLock — but
    // self is nil (weak ref), so the optional chain is a no-op instead of a crash.
    func testStoreDeallocWhileTaskRunningDoesNotCrash() async throws {
        var store: Store<AsyncTaskReducer>? = Store(
            initial: AsyncTaskReducer.State(),
            reducer: AsyncTaskReducer()
        )

        store!.send(.startLongTask)
        XCTAssertEqual(store!.tasks.count, 1)

        // deinit cancels the task; the cleanup Task may still be enqueued on MainActor.
        store = nil

        // Allow any enqueued cleanup tasks to drain.
        try await Task.sleep(nanoseconds: 500_000_000)

        // Reaching this line without a crash confirms the fix.
    }
}
