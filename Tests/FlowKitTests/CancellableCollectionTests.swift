@_spi(Internals) @testable import FlowKit
import XCTest

@MainActor
final class CancellableCollectionTests: XCTestCase {
    var collection: CancellableCollection!
    
    override func setUp() async throws {
        collection = CancellableCollection()
    }
    
    /// Test that tasks are properly added and can be retrieved
    func testTaskAddition() async {
        let expectation = XCTestExpectation(description: "Task completed")
        
        let task: Task<Void, any Error> = Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            expectation.fulfill()
        }
        
        await collection.add(task: task, withKey: "testTask")
        
        // Verify task count increased
        let count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Should have one active task")
        
        // Wait for task completion
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /// Test manual cleanup of completed tasks
    func testManualCleanup() async {
        let task: Task<Void, any Error> = Task {
            // Task that completes quickly
            return
        }
        
        await collection.add(task: task, withKey: "quickTask")
        
        // Verify task was added
        var count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Should have one active task")
        
        // Wait for task to complete
        _ = await task.result
        
        // Task should still be in collection (manual cleanup)
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Task should still be in collection after completion")
        
        // Manually remove the task
        await collection.remove(withKey: "quickTask")
        
        // Verify task was removed
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 0, "Task should be removed after manual cleanup")
    }
    
    /// Test task cancellation
    func testTaskCancellation() async {
        let task: Task<Void, any Error> = Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        await collection.add(task: task, withKey: "longTask")
        
        // Verify task was added
        var count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Should have one active task")
        
        // Cancel the task
        await collection.cancel(withKey: "longTask")
        
        // Verify task was removed
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 0, "Task should be removed after cancellation")
        
        // Verify task was actually cancelled
        let result = await task.result
        switch result {
        case .failure(let error):
            XCTAssertTrue(error is CancellationError, "Task should be cancelled with CancellationError")
        case .success:
            XCTFail("Task should have been cancelled")
        }
    }
    
    /// Test cancel all functionality
    func testCancelAll() async {
        // Add multiple tasks
        for i in 0..<3 {
            let task: Task<Void, any Error> = Task {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            await collection.add(task: task, withKey: "task\(i)")
        }
        
        // Verify all tasks were added
        var count = await collection.activeTaskCount
        XCTAssertEqual(count, 3, "Should have three active tasks")
        
        // Cancel all tasks
        await collection.cancelAll()
        
        // Verify all tasks were removed
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 0, "All tasks should be removed after cancel all")
    }
    
    /// Test task replacement when same key is used
    func testTaskReplacement() async {
        let firstTask: Task<Void, any Error> = Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        await collection.add(task: firstTask, withKey: "sameKey")
        
        // Verify first task was added
        var count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Should have one active task")
        
        let secondTask: Task<Void, any Error> = Task {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Add second task with same key (should replace first)
        await collection.add(task: secondTask, withKey: "sameKey")
        
        // Should still have only one task
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 1, "Should still have one active task after replacement")
        
        // Clean up
        await collection.cancelAll()
    }
    
    /// Test activeTaskCount accuracy
    func testActiveTaskCount() async {
        // Start with zero tasks
        var count = await collection.activeTaskCount
        XCTAssertEqual(count, 0, "Should start with zero active tasks")
        
        // Add tasks one by one and verify count
        for i in 1...5 {
            let task: Task<Void, any Error> = Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            await collection.add(task: task, withKey: "task\(i)")
            
            count = await collection.activeTaskCount
            XCTAssertEqual(count, i, "Should have \(i) active tasks")
        }
        
        // Clean up
        await collection.cancelAll()
        
        count = await collection.activeTaskCount
        XCTAssertEqual(count, 0, "Should have zero active tasks after cleanup")
    }
}
