struct AnyTransform<Action: Sendable> {
    let _transform: @Sendable (Send<Action>) -> Send<Action>
    let _isIdentity: Bool
    
    init(_ transform: @escaping @Sendable (Send<Action>) -> Send<Action>) {
        self._transform = transform
        self._isIdentity = false
    }
    
    static var identity: AnyTransform<Action> {
        AnyTransform(isIdentity: true) { $0 }
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
