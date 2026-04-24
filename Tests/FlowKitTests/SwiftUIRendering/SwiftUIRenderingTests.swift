#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import SwiftUI
import Testing
@testable import FlowKit

// Baseline runtime tests that mount real SwiftUI views in a hosting view/window
// and verify FlowKit's Store integrates correctly with SwiftUI's Observation-driven
// rendering pipeline. These guard against regressions in the Store / @Observable /
// @Shared wiring that would not be caught by Observation-framework-level tests.
//
// Positive invariants asserted: body re-runs after mutation; body sees fresh state
// on mount; multiple @Shared handles observe shared mutations; @Shared resolves to
// identical Store; dispatch from inside a view (onAppear) completes the round trip.
//
// Negative invariants asserted: body does NOT re-run when nothing mutates; one
// Store's mutation does NOT re-render a view bound to a different Store.
//
// Assertions are "view eventually observes expected state" — never exact render
// counts — because SwiftUI coalesces transactions nondeterministically.
//
// `.serialized` is required: Swift Testing runs @Tests in parallel by default, and
// tests that touch the registry share the singleton `\StoreValues.renderingCounterStore`.
//
// Support types live in sibling folders:
//   Reducers/ — RenderingCounterReducer, RenderingCounterStoreKey, \.renderingCounterStore
//   Models/   — RenderProbe, SharedIdentityProbe, RenderTimeout
//   Views/    — probe views used below

@MainActor
@Suite("SwiftUI rendering baseline", .serialized)
struct SwiftUIRenderingTests {

    init() async throws {
        // Reset the registry-backed counter store before every @Test so state
        // doesn't leak across tests.
        Shared(\StoreValues.renderingCounterStore).wrappedValue.send(.reset)
    }

    // MARK: - Path 1: view holds Store as a plain `let` property

    @Test("Body invoked with live state when view mounts after mutations — Store prop")
    func storeProp_whenMountedAfterIncrements_observesCurrentCount() async throws {
        let probe = RenderProbe()
        let store = makeCounterStore()
        store.send(.increment)
        store.send(.increment)

        let host = mount(StorePropProbeView(store: store, probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)
        #expect(probe.lastCount == 2)
    }

    @Test("Body re-runs after single increment — Store prop")
    func storeProp_whenStoreIncrementsOnce_observesOne() async throws {
        let probe = RenderProbe()
        let store = makeCounterStore()

        let host = mount(StorePropProbeView(store: store, probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)

        store.send(.increment)

        try await waitForLastCount(probe, equals: 1, timeout: 2.0)
        #expect(probe.lastCount == 1)
    }

    @Test("Body observes both increment and reset transitions — Store prop")
    func storeProp_whenIncrementThenReset_observesBothTransitions() async throws {
        let probe = RenderProbe()
        let store = makeCounterStore()

        let host = mount(StorePropProbeView(store: store, probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)

        store.send(.increment)
        store.send(.increment)
        store.send(.increment)
        try await waitForLastCount(probe, equals: 3, timeout: 2.0)

        store.send(.reset)
        try await waitForLastCount(probe, equals: 0, timeout: 2.0)
        #expect(probe.lastCount == 0)
    }

    // MARK: - Path 2: view uses @Shared property wrapper

    @Test("Body invoked with live registry state when view mounts after mutations — @Shared")
    func shared_whenMountedAfterIncrements_observesCurrentCount() async throws {
        let probe = RenderProbe()
        let registryStore = Shared(\StoreValues.renderingCounterStore).wrappedValue
        registryStore.send(.increment)
        registryStore.send(.increment)

        let host = mount(SharedWrapperProbeView(probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)
        #expect(probe.lastCount == 2)
    }

    @Test("Body re-runs after registry store increments — @Shared")
    func shared_whenRegistryIncrementsOnce_observesOne() async throws {
        let probe = RenderProbe()

        let host = mount(SharedWrapperProbeView(probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)

        Shared(\StoreValues.renderingCounterStore).wrappedValue.send(.increment)

        try await waitForLastCount(probe, equals: 1, timeout: 2.0)
        #expect(probe.lastCount == 1)
    }

    @Test("Body re-renders after view dispatches through @Shared wrappedValue from onAppear")
    func shared_whenViewDispatchesFromOnAppear_observesIncrement() async throws {
        let probe = RenderProbe()

        let host = mount(SharedOnAppearDispatchView(probe: probe))
        defer { teardown(host) }

        try await waitForLastCount(probe, equals: 1, timeout: 2.0)
        #expect(probe.lastCount == 1)
    }

    @Test("Two @Shared handles in one view resolve wrappedValue to identical Store")
    func shared_whenTwoHandlesInSameView_wrappedValueResolvesToIdenticalStore() async throws {
        let probe = SharedIdentityProbe()

        let host = mount(SharedIdentityView(probe: probe))
        defer { teardown(host) }

        try await waitForIdentityProbe(probe, timeout: 2.0)
        let identities = try #require(probe.identities)
        #expect(identities.0 == identities.1)
    }

    @Test("Two @Shared handles both observe same registry mutation")
    func shared_twoHandles_whenRegistryIncrements_bothObserveOne() async throws {
        let probeA = RenderProbe()
        let probeB = RenderProbe()

        let hostA = mount(SharedWrapperProbeView(probe: probeA))
        let hostB = mount(SharedWrapperProbeView(probe: probeB))
        defer {
            teardown(hostA)
            teardown(hostB)
        }

        try await waitForBodyCount(probeA, atLeast: 1, timeout: 2.0)
        try await waitForBodyCount(probeB, atLeast: 1, timeout: 2.0)

        Shared(\StoreValues.renderingCounterStore).wrappedValue.send(.increment)

        try await waitForLastCount(probeA, equals: 1, timeout: 2.0)
        try await waitForLastCount(probeB, equals: 1, timeout: 2.0)
        #expect(probeA.lastCount == 1)
        #expect(probeB.lastCount == 1)
    }

    // MARK: - Negative invariants

    @Test("Body does not re-run in absence of Store mutations")
    func storeProp_whenNoMutation_bodyCountStaysStable() async throws {
        let probe = RenderProbe()
        let store = makeCounterStore()

        let host = mount(StorePropProbeView(store: store, probe: probe))
        defer { teardown(host) }

        try await waitForBodyCount(probe, atLeast: 1, timeout: 2.0)
        await pump()
        await pump()
        let settled = probe.bodyCount

        // Negative assertion: give any spurious re-render time to happen, then assert it didn't.
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        #expect(probe.bodyCount == settled)
    }

    @Test("Mutating one Store does not re-render a view bound to a different Store")
    func storeProp_whenSiblingStoreMutates_unrelatedViewDoesNotReRun() async throws {
        let probeA = RenderProbe()
        let probeB = RenderProbe()
        let storeA = makeCounterStore()
        let storeB = makeCounterStore()

        let hostA = mount(StorePropProbeView(store: storeA, probe: probeA))
        let hostB = mount(StorePropProbeView(store: storeB, probe: probeB))
        defer {
            teardown(hostA)
            teardown(hostB)
        }

        try await waitForBodyCount(probeA, atLeast: 1, timeout: 2.0)
        try await waitForBodyCount(probeB, atLeast: 1, timeout: 2.0)
        await pump()
        await pump()
        let bBefore = probeB.bodyCount

        storeA.send(.increment)
        try await waitForLastCount(probeA, equals: 1, timeout: 2.0)

        // Negative assertion: wait long enough for spurious cross-store renders to surface.
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        #expect(probeB.bodyCount == bBefore)
        #expect(probeB.lastCount == 0)
    }

    // MARK: - SUT factory

    private func makeCounterStore() -> Store<RenderingCounterReducer> {
        Store(initial: RenderingCounterReducer.State(), reducer: RenderingCounterReducer())
    }

    // MARK: - Hosting helpers

    #if canImport(AppKit)
    typealias Host = NSWindow

    private func mount<V: View>(_ view: V) -> Host {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    private func teardown(_ host: Host) {
        host.orderOut(nil)
        host.contentView = nil
    }
    #elseif canImport(UIKit)
    typealias Host = UIWindow

    private func mount<V: View>(_ view: V) -> Host {
        let hosting = UIHostingController(rootView: view)
        hosting.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let window = UIWindow(frame: hosting.view.frame)
        window.rootViewController = hosting
        window.isHidden = false
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        return window
    }

    private func teardown(_ host: Host) {
        host.isHidden = true
        host.rootViewController = nil
    }
    #endif

    // MARK: - Render synchronization

    /// Bounded poll helper. Not a banned `Task.sleep` for positive assertion —
    /// the positive assertion is checked each iteration; the sleep just gives
    /// SwiftUI's pending Observation-triggered transactions time to settle.
    private func pump() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        await Task.yield()
    }

    private func waitForBodyCount(
        _ probe: RenderProbe,
        atLeast target: Int,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.bodyCount >= target { return }
            await pump()
        }
        throw RenderTimeout(
            description: "Timed out waiting for bodyCount >= \(target); got \(probe.bodyCount)"
        )
    }

    private func waitForLastCount(
        _ probe: RenderProbe,
        equals target: Int,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.lastCount == target { return }
            await pump()
        }
        throw RenderTimeout(
            description: "Timed out waiting for lastCount == \(target); got \(String(describing: probe.lastCount))"
        )
    }

    private func waitForIdentityProbe(
        _ probe: SharedIdentityProbe,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.identities != nil { return }
            await pump()
        }
        throw RenderTimeout(description: "Timed out waiting for identity probe to record")
    }
}
