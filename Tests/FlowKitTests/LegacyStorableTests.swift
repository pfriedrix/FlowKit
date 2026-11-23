import Foundation
import Testing
import os
@testable import FlowKit

// The deprecated path: states that save and load themselves through `Storable`
// or `Persistable`, and `Store(reducer:default:)` on top of them.
//
// `Persistable` always writes to `UserDefaults.standard` under a key derived
// from the type name, so this is the one test file that touches
// `UserDefaults.standard`. It removes its keys before and after every test.

@available(*, deprecated)
private struct SelfStoringReducer: Reducer {
    struct State: Storable, Equatable, Sendable {
        static let saved = OSAllocatedUnfairLock<State?>(initialState: nil)

        var value: Int

        func save() {
            Self.saved.withLock { $0 = self }
        }

        static func load() -> State? {
            saved.withLock { $0 }
        }
    }

    enum Action {
        case increment
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        state.value += 1
        return .none
    }
}

private enum TextAction {
    case update(String)
}

@available(*, deprecated)
private struct LegacyReducerA: Reducer {
    struct State: Persistable, Equatable, Sendable {
        var value: String
    }

    func reduce(into state: inout State, action: TextAction) -> Effect<TextAction> {
        if case let .update(value) = action { state.value = value }
        return .none
    }
}

@available(*, deprecated)
private struct LegacyReducerB: Reducer {
    struct State: Persistable, Equatable, Sendable {
        var value: String
    }

    func reduce(into state: inout State, action: TextAction) -> Effect<TextAction> {
        if case let .update(value) = action { state.value = value }
        return .none
    }
}

/// `LegacyReducerA` after migration: the state is plain `Codable` and the store
/// is given a persistence.
private struct MigratedReducer: Reducer {
    struct State: Codable, Equatable, Sendable {
        var value: String
    }

    func reduce(into state: inout State, action: TextAction) -> Effect<TextAction> {
        if case let .update(value) = action { state.value = value }
        return .none
    }
}

// `@available(*, deprecated)` is on every member instead of on the class:
// Swift Testing rejects `@Suite` and `@Test` inside a deprecated type.
@MainActor
@Suite(.serialized)  // tests share `UserDefaults.standard` keys and `SelfStoringReducer.State.saved`
final class LegacyStorableTests {

    @available(*, deprecated)
    init() {
        clearSavedState()
    }

    @available(*, deprecated)
    deinit {
        clearSavedState()
    }

    /// `nonisolated` so the nonisolated `deinit` can call it: the lock and
    /// `UserDefaults` are thread-safe.
    @available(*, deprecated)
    nonisolated private func clearSavedState() {
        SelfStoringReducer.State.saved.withLock { $0 = nil }
        UserDefaults.standard.removeObject(forKey: LegacyReducerA.State.key)
        UserDefaults.standard.removeObject(forKey: LegacyReducerB.State.key)
    }

    // MARK: - Storable

    @available(*, deprecated)
    @Test func `Store restores through Storable`() {
        SelfStoringReducer.State(value: 42).save()

        let store = Store(reducer: SelfStoringReducer(), default: .init(value: 0))

        #expect(store.state.value == 42)
    }

    @available(*, deprecated)
    @Test func `Store saves default and every action through Storable`() async throws {
        let store = Store(reducer: SelfStoringReducer(), default: .init(value: 0))
        #expect(SelfStoringReducer.State.load()?.value == 0)

        store.send(.increment)
        store.send(.increment)

        try await waitForStateChange(timeout: 5.0) { SelfStoringReducer.State.load()?.value == 2 }
        #expect(SelfStoringReducer.State.load()?.value == 2)
    }

    // MARK: - Persistable

    @available(*, deprecated)
    @Test func `Persistable saves to standard defaults under type-derived key`() {
        let state = LegacyReducerA.State(value: "Hello, World!")

        state.save()

        #expect(LegacyReducerA.State.key == String(reflecting: LegacyReducerA.State.self))
        #expect(UserDefaults.standard.data(forKey: LegacyReducerA.State.key) != nil)
        #expect(LegacyReducerA.State.load() == state)
    }

    @available(*, deprecated)
    @Test func `Persistable load returns nil when nothing was saved`() {
        #expect(LegacyReducerA.State.load() == nil)
    }

    @available(*, deprecated)
    @Test func `Persistable states with same name do not overwrite each other`() {
        LegacyReducerA.State(value: "Reducer A Value").save()
        LegacyReducerB.State(value: "Reducer B Value").save()

        #expect(LegacyReducerA.State.load()?.value == "Reducer A Value")
        #expect(LegacyReducerB.State.load()?.value == "Reducer B Value")
    }

    @available(*, deprecated)
    @Test func `Store restores and saves Persistable state`() async throws {
        let first = Store(reducer: LegacyReducerA(), default: .init(value: "Initial"))
        first.send(.update("Updated"))
        try await waitForStateChange(timeout: 5.0) { LegacyReducerA.State.load()?.value == "Updated" }

        let second = Store(reducer: LegacyReducerA(), default: .init(value: "Initial"))

        #expect(second.state.value == "Updated")
    }

    // MARK: - Migration

    /// Data saved by `Persistable` stays readable after the state stops
    /// conforming to it: the store is given the key `Persistable` used.
    @available(*, deprecated)
    @Test func `Data saved by Persistable is restored through UserDefaultsPersistence`() {
        LegacyReducerA.State(value: "Saved before migration").save()
        let legacyKey = String(reflecting: LegacyReducerA.State.self)

        let store = Store(
            reducer: MigratedReducer(),
            default: .init(value: "Default"),
            persistence: .userDefaults(key: legacyKey)
        )

        #expect(store.state.value == "Saved before migration")
    }
}
