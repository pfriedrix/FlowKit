/// A utility for formatting action strings in different styles for logging purposes.
///
/// The ActionFormatter handles the conversion of raw action strings into formatted
/// log messages with various levels of detail. This is particularly useful for
/// debugging and monitoring state management operations where you need to control
/// the verbosity of logged information.
///
/// The formatter intelligently handles action strings with parameters by extracting
/// the action name (portion before the first parenthesis) and applying different
/// truncation strategies based on the selected format style.
public struct ActionFormatter: Sendable {
    
    /// Formats an action string according to the specified style.
    ///
    /// This method transforms raw action strings into formatted log messages,
    /// applying different truncation and styling rules based on the chosen format style.
    /// For actions with parameters, it intelligently extracts the action name and
    /// manages parameter display based on the selected style.
    ///
    /// - Parameters:
    ///   - action: The raw action string to format (e.g., "updateUser(name: \"John\", age: 30)")
    ///   - style: The formatting style to apply
    /// - Returns: A formatted string suitable for logging
    ///
    /// Example outputs:
    /// ```
    /// Original: "updateUser(name: \"John\", age: 30)"
    ///
    /// .full:        "Dispatching action: updateUser(name: \"John\", age: 30)"
    /// .short:       "Dispatching action: updateUser(name: \"John\", age: 30)"
    /// .abbreviated: "Dispatching action: updateUser"
    /// ```
    public func format(action: String, style: FormatStyle) -> String {
        switch style {
        case .full:
            // Return complete action string with all parameters
            return "Dispatching action: \(action)"
            
        case .short:
            // Extract action name (portion before first parenthesis)
            let abbreviation = action.split(separator: "(").first ?? Substring(action)
            let prefix = "Dispatching action: \(abbreviation)"

            // Limit additional content to prevent log spam
            let maxAdditionalLength = 32
            let remainingContent = action.dropFirst(abbreviation.count).prefix(maxAdditionalLength)
            
            let result = "\(prefix)\(remainingContent)"
            
            // Add ellipsis if content was truncated
            if action.count > abbreviation.count + maxAdditionalLength {
                return result + "..."
            }
            return result
            
        case .abbreviated:
            // Show only the action name without any parameters
            let abbreviation = action.split(separator: "(").first ?? Substring(action)
            return "Dispatching action: \(abbreviation)"
        }
    }
    
    /// Defines the available formatting styles for action logging.
    ///
    /// Each style provides a different level of detail and verbosity, allowing
    /// developers to choose the appropriate amount of information for their
    /// debugging and monitoring needs.
    public enum FormatStyle: Sendable {
        /// Shows the complete action string including all parameters.
        ///
        /// Use this style when you need full visibility into action payloads
        /// for detailed debugging. Be aware that this can generate verbose logs.
        case full
        
        /// Shows action name with truncated parameters (maximum 32 additional characters).
        ///
        /// This style provides a good balance between information and readability,
        /// showing the action name and a preview of parameters without overwhelming
        /// the log output. Longer parameter lists are truncated with "...".
        case short
        
        /// Shows only the action name without any parameters.
        ///
        /// Use this style for high-level monitoring where you only need to track
        /// which actions are being dispatched without parameter details.
        case abbreviated
    }
}
