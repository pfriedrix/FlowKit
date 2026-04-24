import SwiftUI
@testable import FlowKit

/// Two `@Shared` wrappers on the same key path. Body records their resolved
/// Store references so tests can assert identity — `@Shared` must not clone
/// or wrap the registry-backed Store.
struct SharedIdentityView: View {
    @Shared(\.renderingCounterStore) var a
    @Shared(\.renderingCounterStore) var b
    let probe: SharedIdentityProbe

    var body: some View {
        probe.record(ObjectIdentifier(a), ObjectIdentifier(b))
        return Text("identity")
    }
}
