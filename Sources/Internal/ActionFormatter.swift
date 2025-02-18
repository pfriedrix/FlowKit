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
            let abbreviation = action.split(separator: "(").first ?? Substring(action)
            let prefix = "Dispatching action: \(abbreviation)"

            let maxAdditionalLength = 32
            let remainingContent = action.dropFirst(abbreviation.count).prefix(maxAdditionalLength)
            
            let result = "\(prefix)\(remainingContent)"
            
            if action.count > abbreviation.count + maxAdditionalLength {
                return result + "..."
            }
            return result
        case .abbreviated:
            let abbreviation = action.split(separator: "(").first ?? Substring(action)
            return "Dispatching action: \(abbreviation)"
        }
    }
    
    /// Represents different styles for formatting.
    public enum FormatStyle: Sendable {
        case full
        case short
        case abbreviated
    }
}
