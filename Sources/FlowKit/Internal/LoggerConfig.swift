import os

/// Configuration settings for the FlowKit logging system.
///
/// This structure encapsulates the configurable aspects of logging behavior,
/// including log level filtering and action formatting preferences. It is designed
/// to be thread-safe and used in conjunction with the Logger's static configuration
/// properties.
///
/// The configuration is stored within the Logger using a thread-safe lock mechanism,
/// ensuring that changes to logging behavior are immediately visible across all
/// threads without race conditions.
struct LoggerConfig: Sendable {
    
    /// The minimum log level that will be processed and output.
    ///
    /// Messages with log levels below this threshold will be filtered out
    /// before any formatting or processing occurs, providing performance benefits
    /// when verbose logging is disabled.
    var logLevel: OSLogType
    
    /// The style used for formatting action log messages.
    ///
    /// This setting controls how action dispatch events are formatted in the logs,
    /// allowing developers to choose between detailed, moderate, or minimal verbosity
    /// based on their debugging needs.
    var formatStyle: ActionFormatter.FormatStyle
    
    /// Creates a new logger configuration with specified settings.
    ///
    /// - Parameters:
    ///   - logLevel: The minimum log level to process. Defaults to `.debug` for
    ///     comprehensive logging during development.
    ///   - formatStyle: The action formatting style. Defaults to `.short` for
    ///     a good balance between information and readability.
    init(logLevel: OSLogType = .debug, formatStyle: ActionFormatter.FormatStyle = .short) {
        self.logLevel = logLevel
        self.formatStyle = formatStyle
    }
}
