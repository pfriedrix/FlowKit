import XCTest

extension XCTestCase {
    /// Utility function to wait for a state change condition to be met within a timeout period.
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the condition to be met.
    ///   - condition: A closure that returns `true` when the desired state change has occurred.
    func waitForStateChange(timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = XCTestExpectation(description: "State change")
        
        // Poll the state periodically until the condition is met or the timeout is reached
        let pollInterval: TimeInterval = 0.05
        var elapsedTime: TimeInterval = 0
        _ = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            elapsedTime += pollInterval
            if condition() || elapsedTime >= timeout {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout + pollInterval)
    }
}
