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
// We assert only "view eventually observes the expected state" — never exact render
// counts — because SwiftUI coalesces transactions nondeterministically.
//
// `.serialized` is required: Swift Testing runs @Tests in parallel by default, and
// these tests share the process-wide singleton `\StoreValues.counterStore`.

@MainActor
private final class RenderProbe {
    private(set) var bodyCount = 0
    private(set) var lastCount: Int? = nil

    func record(_ count: Int) {
        bodyCount += 1
        lastCount = count
    }
}

private struct RenderTimeout: Error, CustomStringConvertible {
    let description: String
}

@MainActor
@Suite("SwiftUI rendering baseline", .serialized)
struct SwiftUIRenderingTests {

    init() async throws {
        // Reset the registry-backed counter store before every @Test so state
        // doesn't leak across tests.
        Shared(\StoreValues.counterStore).wrappedValue.send(.reset)
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
        let registryStore = Shared(\StoreValues.counterStore).wrappedValue
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

        Shared(\StoreValues.counterStore).wrappedValue.send(.increment)

        try await waitForLastCount(probe, equals: 1, timeout: 2.0)
        #expect(probe.lastCount == 1)
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

        Shared(\StoreValues.counterStore).wrappedValue.send(.increment)

        try await waitForLastCount(probeA, equals: 1, timeout: 2.0)
        try await waitForLastCount(probeB, equals: 1, timeout: 2.0)
        #expect(probeA.lastCount == 1)
        #expect(probeB.lastCount == 1)
    }

    // MARK: - SUT factory

    private func makeCounterStore() -> Store<CounterReducer> {
        Store(initial: CounterReducer.State(), reducer: CounterReducer())
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
        host.contentView = nil
        host.close()
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
}

// MARK: - Probe views
//
// File-scope private so their @MainActor inference isn't tangled with the
// Suite's isolation when used inside @Test methods.

private struct StorePropProbeView: View {
    let store: Store<CounterReducer>
    let probe: RenderProbe

    var body: some View {
        let count = store.state.count
        probe.record(count)
        return Text("\(count)")
    }
}

private struct SharedWrapperProbeView: View {
    @Shared(\.counterStore) var counter
    let probe: RenderProbe

    var body: some View {
        let count = counter.state.count
        probe.record(count)
        return Text("\(count)")
    }
}
