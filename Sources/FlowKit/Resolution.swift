struct Resolution<State: Sendable, Action: Sendable> {
    let state: State
    let effect: Effect<Action>
}
