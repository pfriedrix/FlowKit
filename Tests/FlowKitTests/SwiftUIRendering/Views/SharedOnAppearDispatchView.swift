import SwiftUI
@testable import FlowKit

/// Exercises the round-trip: body renders → `.onAppear` dispatches through the
/// `@Shared` wrappedValue → Store mutates → Observation fires → body re-renders.
struct SharedOnAppearDispatchView: View {
    @Shared(\.renderingCounterStore) var counter
    let probe: RenderProbe

    var body: some View {
        let count = counter.state.count
        probe.record(count)
        return Text("\(count)")
            .onAppear {
                counter.send(.increment)
            }
    }
}
