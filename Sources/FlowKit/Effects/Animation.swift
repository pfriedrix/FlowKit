import SwiftUI

extension Effect {
    /// Applies SwiftUI animation to all actions sent by this effect.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .send(.showSuccess)
    ///     .animation(.spring())
    /// ```
    ///
    /// - Parameter animation: A SwiftUI animation to apply to sent actions.
    /// - Returns: An effect that applies the animation to all actions it sends.
    public func animation(_ animation: Animation? = .default) -> Self {
        guard let animation = animation else { return self }
        
        return transform(Transform { send in
            Send { action in
                withAnimation(animation) {
                    send(action)
                }
            }
        })
    }
}
