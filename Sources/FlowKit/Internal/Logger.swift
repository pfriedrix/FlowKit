import os

public struct Logger {
    public static let shared = Logger()
   
    private static let configLock = OSAllocatedUnfairLock(initialState: LoggerConfig())
        
    private let formatter = ActionFormatter()
    private let logger: os.Logger
    
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
   
   /// Thread-safe format style access
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
    
    private init() {
        logger = os.Logger(subsystem: "flow-kit", category: "store-events")
    }
    
    func action(_ action: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let message = formatter.format(action: action(), style: Self.formatStyle)
        logger.log(level: type, "\(message)")
    }
    
    func debug(_ message: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    func info(_ message: @autoclosure () -> String) {
        let type = OSLogType.info
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    func error(_ message: @autoclosure () -> String) {
        let type = OSLogType.error
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
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
