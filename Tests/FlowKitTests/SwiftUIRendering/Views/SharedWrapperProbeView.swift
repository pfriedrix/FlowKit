import SwiftUI
@testable import FlowKit

/// View that observes the registry-backed counter Store via `@Shared` property
/// wrapper. Body reads `counter.state.count` (wrappedValue getter + Store.state
/// observation).
struct SharedWrapperProbeView: View {
    @Shared(\.renderingCounterStore) var counter
    let probe: RenderProbe

    var body: some View {
        let count = counter.state.count
        probe.record(count)
        return Text("\(count)")
    }
}
