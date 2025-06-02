import os

struct LoggerConfig: Sendable {
    var logLevel: OSLogType
    var formatStyle: ActionFormatter.FormatStyle
    
    init(logLevel: OSLogType = .debug, formatStyle: ActionFormatter.FormatStyle = .short) {
        self.logLevel = logLevel
        self.formatStyle = formatStyle
    }
}
