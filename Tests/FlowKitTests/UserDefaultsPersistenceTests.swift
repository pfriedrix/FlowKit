import Foundation
import Testing
@testable import FlowKit

// Tests for `UserDefaultsPersistence` against a real `UserDefaults` suite of their
// own: nothing is written to `UserDefaults.standard`.

private struct CounterState: Codable, Equatable, Sendable {
    var value: Int = 0
}

private enum CounterAction {
    case increment
}

private struct DefaultsCounterReducer: Reducer {
    typealias State = CounterState

    func reduce(into state: inout State, action: CounterAction) -> Effect<CounterAction> {
        state.value += 1
        return .none
    }
}

/// Same stored shape as `CounterState` under another type name: what the state
/// type looks like after a rename or a move to another module.
private struct RenamedCounterState: Codable, Equatable, Sendable {
    var value: Int = 0
}

private struct RenamedCounterReducer: Reducer {
    typealias State = RenamedCounterState

    func reduce(into state: inout State, action: CounterAction) -> Effect<CounterAction> {
        state.value += 1
        return .none
    }
}

private struct FailingToEncodeState: Codable, Sendable {
    var value: String = "test"

    func encode(to encoder: any Encoder) throws {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated encoding failure"])
    }
}

@MainActor
final class UserDefaultsPersistenceTests {

    /// One suite for the whole class. A suite per test would leave one plist
    /// file per test behind: emptying a suite doesn't delete its file.
    /// `nonisolated` so the nonisolated `deinit` can read it.
    nonisolated private static let suiteName = "flowkit.tests.UserDefaultsPersistenceTests"

    // `UserDefaults` is documented as thread-safe but isn't annotated `Sendable`;
    // `deinit` is nonisolated and reads it.
    nonisolated(unsafe) private let defaults: UserDefaults

    /// Prefix of every key this test uses, so tests sharing the suite can't see
    /// each other's data, even when run in parallel. Fresh for every test:
    /// Swift Testing creates one suite instance per test.
    private let testID = UUID().uuidString

    private func key(_ name: String) -> String {
        "\(testID).\(name)"
    }

    init() throws {
        defaults = try #require(UserDefaults(suiteName: Self.suiteName))
    }

    deinit {
        let ownKeys = defaults.persistentDomain(forName: Self.suiteName)?.keys.filter { $0.hasPrefix(testID) } ?? []
        for key in ownKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Persistence on its own

    @Test func `Load returns what was saved`() {
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))

        persistence.save(CounterState(value: 7))

        #expect(persistence.load() == CounterState(value: 7))
    }

    @Test func `Load returns nil when nothing was saved`() {
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))

        #expect(persistence.load() == nil)
    }

    /// `load()` must return nil on decode failure, but must NOT delete the saved
    /// data: decode failure is a normal consequence of type evolution, and
    /// silently wiping the data would make migration impossible.
    @Test func `Load returns nil but keeps data that fails to decode`() {
        let corrupted = Data("This is not JSON".utf8)
        defaults.set(corrupted, forKey: key("counter"))
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))

        #expect(persistence.load() == nil)

        #expect(defaults.data(forKey: key("counter")) == corrupted)
    }

    /// `save(_:)` must handle encoder failures without crashing, and must NOT
    /// clobber previously saved, valid data when encoding throws.
    @Test func `Save keeps previous data when encoding fails`() {
        let previous = Data("previous valid blob".utf8)
        defaults.set(previous, forKey: key("failing"))
        let persistence = UserDefaultsPersistence<FailingToEncodeState>(defaults, key: key("failing"))

        persistence.save(FailingToEncodeState())

        #expect(defaults.data(forKey: key("failing")) == previous)
    }

    @Test func `Different keys do not see each other`() {
        let first = UserDefaultsPersistence<CounterState>(defaults, key: key("first"))
        let second = UserDefaultsPersistence<CounterState>(defaults, key: key("second"))

        first.save(CounterState(value: 1))
        second.save(CounterState(value: 2))

        #expect(first.load() == CounterState(value: 1))
        #expect(second.load() == CounterState(value: 2))
    }

    // MARK: - Persistence behind a store

    @Test func `Store restores state saved by previous store`() async throws {
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))
        let first = Store(reducer: DefaultsCounterReducer(), default: CounterState(), persistence: persistence)
        first.send(.increment)
        first.send(.increment)
        try await waitForStateChange(timeout: 2.0) { persistence.load()?.value == 2 }

        let second = Store(
            reducer: DefaultsCounterReducer(),
            default: CounterState(),
            persistence: .userDefaults(defaults, key: key("counter"))
        )

        #expect(second.state.value == 2)
    }

    @Test func `Store starts from default when saved data is corrupted`() {
        defaults.set(Data("This is not JSON".utf8), forKey: key("counter"))

        let store = Store(
            reducer: DefaultsCounterReducer(),
            default: CounterState(value: 10),
            persistence: .userDefaults(defaults, key: key("counter"))
        )

        #expect(store.state.value == 10)
    }

    @Test func `Stores with same state type under different keys persist independently`() async throws {
        let firstPersistence = UserDefaultsPersistence<CounterState>(defaults, key: key("first"))
        let secondPersistence = UserDefaultsPersistence<CounterState>(defaults, key: key("second"))
        let first = Store(reducer: DefaultsCounterReducer(), default: CounterState(), persistence: firstPersistence)
        let second = Store(reducer: DefaultsCounterReducer(), default: CounterState(value: 100), persistence: secondPersistence)

        first.send(.increment)
        second.send(.increment)
        second.send(.increment)

        try await waitForStateChange(timeout: 2.0) {
            firstPersistence.load()?.value == 1 && secondPersistence.load()?.value == 102
        }
        #expect(firstPersistence.load()?.value == 1)
        #expect(secondPersistence.load()?.value == 102)
    }

    /// The key is chosen by whoever creates the store, so a state type can be
    /// renamed or moved without losing what was saved under that key.
    @Test func `Saved state survives renaming the state type`() async throws {
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))
        let original = Store(reducer: DefaultsCounterReducer(), default: CounterState(), persistence: persistence)
        original.send(.increment)
        try await waitForStateChange(timeout: 2.0) { persistence.load()?.value == 1 }

        let renamed = Store(
            reducer: RenamedCounterReducer(),
            default: RenamedCounterState(),
            persistence: .userDefaults(defaults, key: key("counter"))
        )

        #expect(renamed.state.value == 1)
    }

    @Test func `Nothing is written to standard defaults`() async throws {
        let persistence = UserDefaultsPersistence<CounterState>(defaults, key: key("counter"))
        let store = Store(reducer: DefaultsCounterReducer(), default: CounterState(), persistence: persistence)

        store.send(.increment)
        try await waitForStateChange(timeout: 2.0) { persistence.load()?.value == 1 }

        #expect(UserDefaults.standard.object(forKey: key("counter")) == nil)
    }
}
