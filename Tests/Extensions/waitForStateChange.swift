import XCTest

extension XCTestCase {
    /// Utility function to wait for a state change condition to be met within a timeout period.
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the condition to be met.
    ///   - condition: A closure that returns `true` when the desired state change has occurred.
    @MainActor
    func waitForStateChange(timeout: TimeInterval, condition: @escaping () -> Bool) async throws {
         let start = DispatchTime.now()
         while !condition() {
             let now = DispatchTime.now()
             if now.uptimeNanoseconds - start.uptimeNanoseconds > UInt64(timeout * 1_000_000_000) {
                 throw NSError(domain: "WaitForStateChangeTimeout", code: 1, userInfo: nil)
             }
             try await Task.sleep(nanoseconds: 50_000_000) // sleep 50ms
         }
    }
}
