import XCTest
@testable import FlowKit

// Tests for `UserDefaultsStorage`. Every test gets its own defaults suite, so
// nothing is written to `UserDefaults.standard` and tests can't see each
// other's data.

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
final class UserDefaultsStorageTests: XCTestCase {

    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "flowkit.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    // MARK: - Storage on its own

    func testLoadReturnsWhatWasSaved() {
        let storage = UserDefaultsStorage<CounterState>(defaults, key: "counter")

        storage.save(CounterState(value: 7))

        XCTAssertEqual(storage.load(), CounterState(value: 7))
    }

    func testLoadReturnsNilWhenNothingWasSaved() {
        let storage = UserDefaultsStorage<CounterState>(defaults, key: "counter")

        XCTAssertNil(storage.load())
    }

    /// `load()` must return nil on decode failure, but must NOT delete the saved
    /// data: decode failure is a normal consequence of type evolution, and
    /// silently wiping the data would make migration impossible.
    func testLoadReturnsNilButKeepsDataThatFailsToDecode() {
        let corrupted = Data("This is not JSON".utf8)
        defaults.set(corrupted, forKey: "counter")
        let storage = UserDefaultsStorage<CounterState>(defaults, key: "counter")

        XCTAssertNil(storage.load())

        XCTAssertEqual(defaults.data(forKey: "counter"), corrupted)
    }

    /// `save(_:)` must handle encoder failures without crashing, and must NOT
    /// clobber previously saved, valid data when encoding throws.
    func testSaveKeepsPreviousDataWhenEncodingFails() {
        let previous = Data("previous valid blob".utf8)
        defaults.set(previous, forKey: "failing")
        let storage = UserDefaultsStorage<FailingToEncodeState>(defaults, key: "failing")

        storage.save(FailingToEncodeState())

        XCTAssertEqual(defaults.data(forKey: "failing"), previous)
    }

    func testStoragesUnderDifferentKeysDoNotSeeEachOther() {
        let first = UserDefaultsStorage<CounterState>(defaults, key: "first")
        let second = UserDefaultsStorage<CounterState>(defaults, key: "second")

        first.save(CounterState(value: 1))
        second.save(CounterState(value: 2))

        XCTAssertEqual(first.load(), CounterState(value: 1))
        XCTAssertEqual(second.load(), CounterState(value: 2))
    }

    // MARK: - Storage behind a store

    func testStoreRestoresStateSavedByPreviousStore() async throws {
        let storage = UserDefaultsStorage<CounterState>(defaults, key: "counter")
        let first = Store(reducer: DefaultsCounterReducer(), default: CounterState(), storage: storage)
        first.send(.increment)
        first.send(.increment)
        try await waitForStateChange(timeout: 2.0) { storage.load()?.value == 2 }

        let second = Store(
            reducer: DefaultsCounterReducer(),
            default: CounterState(),
            storage: .userDefaults(defaults, key: "counter")
        )

        XCTAssertEqual(second.state.value, 2)
    }

    func testStoreStartsFromDefaultWhenSavedDataIsCorrupted() {
        defaults.set(Data("This is not JSON".utf8), forKey: "counter")

        let store = Store(
            reducer: DefaultsCounterReducer(),
            default: CounterState(value: 10),
            storage: .userDefaults(defaults, key: "counter")
        )

        XCTAssertEqual(store.state.value, 10)
    }

    func testStoresWithSameStateTypeUnderDifferentKeysPersistIndependently() async throws {
        let firstStorage = UserDefaultsStorage<CounterState>(defaults, key: "first")
        let secondStorage = UserDefaultsStorage<CounterState>(defaults, key: "second")
        let first = Store(reducer: DefaultsCounterReducer(), default: CounterState(), storage: firstStorage)
        let second = Store(reducer: DefaultsCounterReducer(), default: CounterState(value: 100), storage: secondStorage)

        first.send(.increment)
        second.send(.increment)
        second.send(.increment)

        try await waitForStateChange(timeout: 2.0) {
            firstStorage.load()?.value == 1 && secondStorage.load()?.value == 102
        }
        XCTAssertEqual(firstStorage.load()?.value, 1)
        XCTAssertEqual(secondStorage.load()?.value, 102)
    }

    /// The key is chosen by whoever creates the store, so a state type can be
    /// renamed or moved without losing what was saved under that key.
    func testSavedStateSurvivesRenamingTheStateType() async throws {
        let storage = UserDefaultsStorage<CounterState>(defaults, key: "counter")
        let original = Store(reducer: DefaultsCounterReducer(), default: CounterState(), storage: storage)
        original.send(.increment)
        try await waitForStateChange(timeout: 2.0) { storage.load()?.value == 1 }

        let renamed = Store(
            reducer: RenamedCounterReducer(),
            default: RenamedCounterState(),
            storage: .userDefaults(defaults, key: "counter")
        )

        XCTAssertEqual(renamed.state.value, 1)
    }

    func testNothingIsWrittenToStandardDefaults() async throws {
        let key = "flowkit.tests.standard-probe.\(UUID().uuidString)"
        let storage = UserDefaultsStorage<CounterState>(defaults, key: key)
        let store = Store(reducer: DefaultsCounterReducer(), default: CounterState(), storage: storage)

        store.send(.increment)
        try await waitForStateChange(timeout: 2.0) { storage.load()?.value == 1 }

        XCTAssertNil(UserDefaults.standard.object(forKey: key))
    }
}
