import XCTest
import SwiftUI
@testable import FlowKit

struct MockReducer: Reducer {
    struct State: Equatable {
        var value: Int = 0
    }

    enum Action {
        case increment, decrement
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        }
        return .none
    }
}

struct MockReducerKey: EnvironmentKey {
    static let defaultValue: Store<MockReducer> = .init(initial: .init(), reducer: .init())
}

extension EnvironmentValues {
    var mockStore: Store<MockReducer> {
        get { self[MockReducerKey.self] }
        set { self[MockReducerKey.self] = newValue }
    }
}

final class EnvironmentStoreTests: XCTestCase {

    var store: Store<MockReducer>!

    override func setUp() {
        super.setUp()
        Task { @MainActor in
            Logger.logLevel = .info
        }
        store = Store(initial: .init(), reducer: .init())
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testEnvironmentStoreProvidesDefaultState() {
        // Given
        var environment = EnvironmentValues()
        environment.mockStore = store

        // When
        let initialState = environment.mockStore.state

        // Then
        XCTAssertEqual(initialState.value, 0, "The default state should be 0.")
    }

    @MainActor
    func testEnvironmentStoreStateUpdates() async throws {
        // Given
        var environment = EnvironmentValues()
        environment.mockStore = store

        // When
        environment.mockStore.send(.increment)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(environment.mockStore.state.value, 1, "The state should update after the increment action.")
    }

    @MainActor
    func testEnvironmentStoreHandlesMultipleActions() async throws {
        // Given
        var environment = EnvironmentValues()
        environment.mockStore = store

        // When
        environment.mockStore.send(.increment)
        environment.mockStore.send(.increment)
        environment.mockStore.send(.decrement)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertEqual(environment.mockStore.state.value, 1, "The state should correctly reflect multiple actions.")
    }

    @MainActor
    func testMultipleEnvironmentStoresOperateIndependently() async throws {
        // Given
        let firstStore = Store<MockReducer>(initial: .init(value: 10), reducer: .init())
        let secondStore = Store<MockReducer>(initial: .init(value: 20), reducer: .init())
        var firstEnvironment = EnvironmentValues()
        var secondEnvironment = EnvironmentValues()

        firstEnvironment.mockStore = firstStore
        secondEnvironment.mockStore = secondStore

        // When
        firstEnvironment.mockStore.send(.increment)
        secondEnvironment.mockStore.send(.decrement)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(firstEnvironment.mockStore.state.value, 11, "The first store should reflect the increment action.")
        XCTAssertEqual(secondEnvironment.mockStore.state.value, 19, "The second store should reflect the decrement action.")
    }

    @MainActor
    func testSwiftUIViewIntegration() async throws {
        @EnvironmentStore(\.mockStore) var store: Store<MockReducer>
        // Given
        struct TestView: View {
            @EnvironmentStore(\.mockStore) var store: Store<MockReducer>

            var body: some View {
                VStack {
                    Text("Value: \(store.state.value)")
                    Button("Increment") {
                        store.send(.increment)
                    }
                    Button("Decrement") {
                        store.send(.decrement)
                    }
                }
            }
        }

        let view = TestView()

        // When
        store.send(.increment)
        store.send(.increment)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(view.store.state.value, 2, "The state should reflect the increment action in the SwiftUI view.")
    }
    
    @MainActor
    func testDoubleStores() async throws {
        @EnvironmentStore(\.mockStore) var store: Store<MockReducer>
      
        store.send(.increment)
        
        @EnvironmentStore(\.mockStore) var store2: Store<MockReducer>
        
        store2.send(.increment)

        XCTAssertEqual(store2.state.value, 2, "The state should be synchronized")
        XCTAssertEqual(store.state.value, 2, "The state should be synchronized")
    }
}
