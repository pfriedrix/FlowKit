import SwiftUI
@testable import FlowKit

/// View that observes a Store passed as a plain `let` property (no property wrapper).
/// Body reads `store.state.count`, which registers Observation tracking on Store,
/// and records each body evaluation to the probe.
struct StorePropProbeView: View {
    let store: Store<RenderingCounterReducer>
    let probe: RenderProbe

    var body: some View {
        let count = store.state.count
        probe.record(count)
        return Text("\(count)")
    }
}
