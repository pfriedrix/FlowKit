public struct ActionFormatter {
    /// Formats the action based on the specified format style.
    /// - Parameters:
    ///   - action: The action to format, represented as a string.
    ///   - style: The style in which the action should be formatted.
    /// - Returns: A formatted string based on the style.
    public func format(action: String, style: FormatStyle) -> String {
        switch style {
        case .full:
            return "Dispatching action: \(action)"
        case .short:
            let firstLine = action.prefix(20)
            return "Dispatching action: \(firstLine)..."
        case .abbreviated:
            let words = action.split(separator: "(")
            let abbreviated = words.map { String($0.prefix(1)) }.joined()
            return "Dispatching action: \(abbreviated)"
        }
    }
    
    /// Represents different styles for formatting.
    public enum FormatStyle {
        case full
        case short
        case abbreviated
    }
}
