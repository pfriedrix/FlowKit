/// Error thrown by `waitFor…` helpers when a polled condition is not met
/// within the configured timeout.
struct RenderTimeout: Error, CustomStringConvertible {
    let description: String
}
