import os

/// A shared logging system for FlowKit state management operations.
///
/// The Logger provides structured logging capabilities with configurable log levels
/// and formatting styles specifically designed for tracking store actions, state changes,
/// and debugging information in FlowKit applications.
///
/// The logger uses the unified logging system (os.Logger) under the hood and provides
/// thread-safe configuration through static properties. All logging operations are
/// optimized to avoid performance overhead when log levels are disabled.
///
/// Example usage:
/// ```swift
/// // Configure logging
/// Logger.logLevel = .info
/// Logger.formatStyle = .short
///
/// // Use through Store (automatic)
/// store.send(.updateUser("John"))
///
/// // Direct usage
/// Logger.shared.info("Custom message")
/// ```
public struct Logger {
    
    /// The shared singleton instance of the logger.
    ///
    /// Use this instance throughout your application to ensure consistent logging
    /// behavior and configuration across all FlowKit operations.
    public static let shared = Logger()
   
    /// Thread-safe configuration lock for logger settings.
    private static let configLock = OSAllocatedUnfairLock(initialState: LoggerConfig())
        
    /// Formatter for action-specific log messages.
    private let formatter = ActionFormatter()
    
    /// The underlying system logger instance.
    private let logger: os.Logger
    
    /// The current log level that determines which messages are actually logged.
    ///
    /// Messages with log levels below this threshold will be filtered out for performance.
    /// This property is thread-safe and can be modified at runtime to adjust logging verbosity.
    ///
    /// Available levels (in order of increasing severity):
    /// - `.debug`: Detailed debugging information
    /// - `.info`: General informational messages
    /// - `.error`: Error conditions
    /// - `.fault`: Critical faults that may cause app failure
    public static var logLevel: OSLogType {
       get {
           configLock.withLock { config in
               config.logLevel
           }
       }
       set {
           configLock.withLock { config in
               config.logLevel = newValue
           }
       }
   }
   
   /// The formatting style used for action logging.
   ///
   /// Controls how action messages are formatted when logged, affecting the verbosity
   /// and structure of logged action information. This property is thread-safe.
   ///
   /// Available styles:
   /// - `.full`: Complete action string with all parameters
   /// - `.short`: Action name with truncated parameters
   /// - `.abbreviated`: Action name only
   public static var formatStyle: ActionFormatter.FormatStyle {
       get {
           configLock.withLock { config in
               config.formatStyle
           }
       }
       set {
           configLock.withLock { config in
               config.formatStyle = newValue
           }
       }
   }
    
    /// Private initializer to ensure singleton usage.
    ///
    /// The logger is configured with a specific subsystem and category
    /// optimized for FlowKit store event tracking.
    private init() {
        logger = os.Logger(subsystem: "flow-kit", category: "store-events")
    }
    
    /// Logs an action dispatch event with configurable formatting.
    ///
    /// This method is specifically designed for logging store actions and respects
    /// both the current log level and formatting style configuration.
    ///
    /// - Parameter action: A closure that returns the action string to log.
    ///   Using @autoclosure enables lazy evaluation for performance.
    func action(_ action: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let message = formatter.format(action: action(), style: Self.formatStyle)
        logger.log(level: type, "\(message)")
    }
    
    /// Logs a debug-level message.
    ///
    /// Debug messages are typically used for detailed diagnostic information
    /// that is most useful when debugging problems.
    ///
    /// - Parameter message: A closure that returns the message to log.
    ///   Using @autoclosure enables lazy evaluation for performance.
    func debug(_ message: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    /// Logs an informational message.
    ///
    /// Info messages are used for general informational messages that highlight
    /// the progress of the application at a coarse-grained level.
    ///
    /// - Parameter message: A closure that returns the message to log.
    ///   Using @autoclosure enables lazy evaluation for performance.
    func info(_ message: @autoclosure () -> String) {
        let type = OSLogType.info
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    /// Logs an error-level message.
    ///
    /// Error messages indicate that something has gone wrong but the application
    /// can continue to operate, possibly with reduced functionality.
    ///
    /// - Parameter message: A closure that returns the message to log.
    ///   Using @autoclosure enables lazy evaluation for performance.
    func error(_ message: @autoclosure () -> String) {
        let type = OSLogType.error
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    /// Logs a fault-level message.
    ///
    /// Fault messages indicate serious errors that represent critical failures
    /// in the application that should be investigated immediately.
    ///
    /// - Parameter message: A closure that returns the message to log.
    ///   Using @autoclosure enables lazy evaluation for performance.
    func fault(_ message: @autoclosure () -> String) {
        let type = OSLogType.fault
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
}

extension Logger: Sendable { }
