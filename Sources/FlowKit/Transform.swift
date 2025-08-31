struct Transform<Action: Sendable> {
    let _transform: @Sendable (Send<Action>) -> Send<Action>
    let _isIdentity: Bool
    
    init(_ transform: @escaping @Sendable (Send<Action>) -> Send<Action>) {
        self._transform = transform
        self._isIdentity = false
    }
    
    static var identity: Transform<Action> {
        Transform(isIdentity: true) { $0 }
    }
    
    init(isIdentity: Bool, _ transform: @escaping @Sendable (Send<Action>) -> Send<Action>) {
        self._transform = transform
        self._isIdentity = isIdentity
    }
    
    func apply(to send: Send<Action>) -> Send<Action> {
        guard !_isIdentity else { return send }
        return _transform(send)
    }
}

extension Effect {
    /// Applies a transformation to this effect
    /// - Parameter transform: The transformation to apply
    /// - Returns: A new effect with the transformation applied
    func transform(_ transform: Transform<Action>) -> Effect<Action> {
        guard !transform._isIdentity else { return self }
        
        switch operation {
        case .none:
            return .none
            
        case .send(let action):
            return .run { send in
                let transformedSend = transform.apply(to: send)
                await transformedSend(action)
            }
            
        case .run(let priority, let operation):
            return .run(priority: priority) { send in
                let transformedSend = transform.apply(to: send)
                await operation(transformedSend)
            }
        }
    }
}
