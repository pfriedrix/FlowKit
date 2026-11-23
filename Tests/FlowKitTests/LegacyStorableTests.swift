import XCTest
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

@available(*, deprecated)
@MainActor
final class LegacyStorableTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        clearSavedState()
    }

    override func tearDown() async throws {
        clearSavedState()
        try await super.tearDown()
    }

    private func clearSavedState() {
        SelfStoringReducer.State.saved.withLock { $0 = nil }
        UserDefaults.standard.removeObject(forKey: LegacyReducerA.State.key)
        UserDefaults.standard.removeObject(forKey: LegacyReducerB.State.key)
    }

    // MARK: - Storable

    func testStoreRestoresThroughStorable() {
        SelfStoringReducer.State(value: 42).save()

        let store = Store(reducer: SelfStoringReducer(), default: .init(value: 0))

        XCTAssertEqual(store.state.value, 42)
    }

    func testStoreSavesDefaultAndEveryActionThroughStorable() async throws {
        let store = Store(reducer: SelfStoringReducer(), default: .init(value: 0))
        XCTAssertEqual(SelfStoringReducer.State.load()?.value, 0)

        store.send(.increment)
        store.send(.increment)

        try await waitForStateChange(timeout: 2.0) { SelfStoringReducer.State.load()?.value == 2 }
        XCTAssertEqual(SelfStoringReducer.State.load()?.value, 2)
    }

    // MARK: - Persistable

    func testPersistableSavesToStandardDefaultsUnderTypeDerivedKey() {
        let state = LegacyReducerA.State(value: "Hello, World!")

        state.save()

        XCTAssertEqual(LegacyReducerA.State.key, String(reflecting: LegacyReducerA.State.self))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: LegacyReducerA.State.key))
        XCTAssertEqual(LegacyReducerA.State.load(), state)
    }

    func testPersistableLoadReturnsNilWhenNothingWasSaved() {
        XCTAssertNil(LegacyReducerA.State.load())
    }

    func testPersistableStatesWithSameNameDoNotOverwriteEachOther() {
        LegacyReducerA.State(value: "Reducer A Value").save()
        LegacyReducerB.State(value: "Reducer B Value").save()

        XCTAssertEqual(LegacyReducerA.State.load()?.value, "Reducer A Value")
        XCTAssertEqual(LegacyReducerB.State.load()?.value, "Reducer B Value")
    }

    func testStoreRestoresAndSavesPersistableState() async throws {
        let first = Store(reducer: LegacyReducerA(), default: .init(value: "Initial"))
        first.send(.update("Updated"))
        try await waitForStateChange(timeout: 2.0) { LegacyReducerA.State.load()?.value == "Updated" }

        let second = Store(reducer: LegacyReducerA(), default: .init(value: "Initial"))

        XCTAssertEqual(second.state.value, "Updated")
    }

    // MARK: - Migration

    /// Data saved by `Persistable` stays readable after the state stops
    /// conforming to it: the store is given the key `Persistable` used.
    func testDataSavedByPersistableIsRestoredThroughUserDefaultsPersistence() {
        LegacyReducerA.State(value: "Saved before migration").save()
        let legacyKey = String(reflecting: LegacyReducerA.State.self)

        let store = Store(
            reducer: MigratedReducer(),
            default: .init(value: "Default"),
            persistence: .userDefaults(key: legacyKey)
        )

        XCTAssertEqual(store.state.value, "Saved before migration")
    }
}
