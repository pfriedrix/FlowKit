import os

final public class Logger {
    public static let shared = Logger()
    public static var logLevel: OSLogType = .debug
    public static var formatStyle: ActionFormatter.FormatStyle = .short
    
    private let formatter = ActionFormatter()
    
    private var logger: os.Logger {
        os.Logger(subsystem: "flow-kit", category: "store-events")
    }
    
    private init() { }
    
    private func log(_ message: String, type: OSLogType = .default) {
        guard type.rawValue >= Self.logLevel.rawValue else {
            return
        }
        
        logger.log(level: type, "\(message)")
    }
    
    func action(_ action: String) {
        log(formatter.format(action: action, style: Self.formatStyle), type: .debug)
    }
    
    func debug(_ message: String) {
        log(message, type: .debug)
    }
    
    func info(_ message: String) {
        log(message, type: .info)
    }
    
    func error(_ message: String) {
        log(message, type: .error)
    }
    
    func fault(_ message: String) {
        log(message, type: .fault)
    }
}
