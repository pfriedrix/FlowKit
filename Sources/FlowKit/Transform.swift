extension Effect {
    /// Applies a transformation to this effect
    /// - Parameter transform: The transformation to apply
    /// - Returns: A new effect with the transformation applied
    func transform(_ transform: AnyTransform<Action>) -> Effect<Action> {
        guard !transform._isIdentity else { return self }
        
        switch self.operation {
        case .none:
            return .none
            
        case .send(let action):
            return Effect(operation: .run { send in
                let transformedSend = transform.apply(to: send)
                await transformedSend(action)
            })
            
        case .run(let priority, let operation):
            return Effect(operation: .run(priority) { send in
                let transformedSend = transform.apply(to: send)
                await operation(transformedSend)
            })
        }
    }
}
