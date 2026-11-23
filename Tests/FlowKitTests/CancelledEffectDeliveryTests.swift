import Foundation
import os
import Testing
@testable import FlowKit

/// Sends one action from a cancellable effect and records the moment just
/// before it does, so a test can cancel the effect while that send is on its
/// way to MainActor.
private struct HopReducer: Reducer {
    struct State: Equatable, Sendable {
        var delivered = 0
    }

    enum Action: Equatable, Sendable {
        case start
        case cancel
        case delivered
    }

    let aboutToSend: OSAllocatedUnfairLock<Bool>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .start:
            return .run { [aboutToSend] send in
                aboutToSend.withLock { $0 = true }
                await send(.delivered)
            }
            .cancellable(id: "hop")
        case .cancel:
            return .cancel(id: "hop")
        case .delivered:
            state.delivered += 1
            return .none
        }
    }
}

@MainActor
struct CancelledEffectDeliveryTests {

    @Test func `Effect cancelled while its send waits for MainActor delivers nothing`() async throws {
        let aboutToSend = OSAllocatedUnfairLock(initialState: false)
        let store = Store(initial: HopReducer.State(), reducer: HopReducer(aboutToSend: aboutToSend))

        store.send(.start)

        // Hold MainActor without suspending until the effect is about to send,
        // then a little longer, so its send passes the cancellation check and
        // queues up for MainActor behind this test.
        let deadline = Date().addingTimeInterval(1)
        while !aboutToSend.withLock({ $0 }), Date() < deadline {}
        try #require(aboutToSend.withLock { $0 }, "Effect never started")
        let settle = Date().addingTimeInterval(0.05)
        while Date() < settle {}

        store.send(.cancel)

        // Let the queued send reach MainActor.
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(store.state.delivered == 0, "A cancelled effect must not deliver its action")
    }
}
