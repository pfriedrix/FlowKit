public import SwiftUI

extension Effect {
    /// Applies a SwiftUI animation to all actions sent by this effect.
    ///
    /// Passing `nil` explicitly clears any animation previously attached to the
    /// effect — useful when composing effects that inherit an animation you
    /// want to drop for this branch.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .send(.showSuccess)
    ///     .animation(.spring())
    ///
    /// case .silentRefresh:
    ///   return inheritedEffect.animation(nil) // drop inherited animation
    /// ```
    ///
    /// - Parameter animation: A SwiftUI animation to apply, or `nil` to clear
    ///   any currently-attached animation. Defaults to `.default` so
    ///   `.animation()` with no argument is a quick opt-in to the system default.
    /// - Returns: An effect with the given animation (or lack thereof) attached.
    public func animation(_ animation: Animation? = .default) -> Self {
        Self(operation: operation, animation: animation)
    }
}
