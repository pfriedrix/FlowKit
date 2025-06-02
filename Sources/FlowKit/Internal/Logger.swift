import os

final public class Logger {
    public static let shared = Logger()
    @MainActor
    public static var logLevel: OSLogType = .debug
    @MainActor
    public static var formatStyle: ActionFormatter.FormatStyle = .short
    
    private let formatter = ActionFormatter()
    
    private let logger: os.Logger
    
    private init() {
        logger = os.Logger(subsystem: "flow-kit", category: "store-events")
    }
    
    @MainActor
    func action(_ action: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let message = formatter.format(action: action(), style: Self.formatStyle)
        logger.log(level: type, "\(message)")
    }
    
    @MainActor
    func debug(_ message: @autoclosure () -> String) {
        let type = OSLogType.debug
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    @MainActor
    func info(_ message: @autoclosure () -> String) {
        let type = OSLogType.info
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    @MainActor
    func error(_ message: @autoclosure () -> String) {
        let type = OSLogType.error
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
    
    @MainActor
    func fault(_ message: @autoclosure () -> String) {
        let type = OSLogType.fault
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        let msg = message()
        logger.log(level: type, "\(msg)")
    }
}

extension Logger: @unchecked Sendable { }
