import os

final public class Logger: @unchecked Sendable {
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
    
    private func log(_ message: String, type: OSLogType = .default) {
        Task {
            guard await type.rawValue >= Self.logLevel.rawValue else {
                return
            }
            
            logger.log(level: type, "\(message)")
        }
    }
    
    func action(_ action: String) {
        Task {
            await log(formatter.format(action: action, style: Self.formatStyle), type: .debug)
        }
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
