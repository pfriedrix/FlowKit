import Testing
@testable import FlowKit

@MainActor
struct EffectEquatableTests {
    enum TestAction: Equatable, Sendable {
        case a
        case b
        case payload(Int)
    }

    // MARK: - isNone

    @Test func `isNone true for none`() {
        let effect: Effect<TestAction> = .none
        #expect(effect.isNone)
    }

    @Test func `isNone false for send`() {
        let effect: Effect<TestAction> = .send(.a)
        #expect(!effect.isNone)
    }

    @Test func `isNone false for merge`() {
        let effect: Effect<TestAction> = .merge(.a, .b)
        #expect(!effect.isNone)
    }

    @Test func `isNone false for run`() {
        let effect: Effect<TestAction> = .run { _ in }
        #expect(!effect.isNone)
    }

    // MARK: - Equatable

    @Test func `None equals none`() {
        let lhs: Effect<TestAction> = .none
        let rhs: Effect<TestAction> = .none
        #expect(lhs == rhs)
    }

    @Test func `Send equal when actions match`() {
        let lhs: Effect<TestAction> = .send(.payload(7))
        let rhs: Effect<TestAction> = .send(.payload(7))
        #expect(lhs == rhs)
    }

    @Test func `Send unequal when actions differ`() {
        let lhs: Effect<TestAction> = .send(.payload(1))
        let rhs: Effect<TestAction> = .send(.payload(2))
        #expect(lhs != rhs)
    }

    @Test func `Merge equal when actions match`() {
        let lhs: Effect<TestAction> = .merge(.a, .b)
        let rhs: Effect<TestAction> = .merge(.a, .b)
        #expect(lhs == rhs)
    }

    @Test func `Merge unequal when actions differ`() {
        let lhs: Effect<TestAction> = .merge(.a, .b)
        let rhs: Effect<TestAction> = .merge(.a)
        #expect(lhs != rhs)
    }

    @Test func `Run equal when priorities match`() {
        let lhs: Effect<TestAction> = .run(priority: .high) { _ in }
        let rhs: Effect<TestAction> = .run(priority: .high) { _ in }
        #expect(lhs == rhs)
    }

    @Test func `Run unequal when priorities differ`() {
        let lhs: Effect<TestAction> = .run(priority: .high) { _ in }
        let rhs: Effect<TestAction> = .run(priority: .low) { _ in }
        #expect(lhs != rhs)
    }

    @Test func `Cancel equal when ids match`() {
        let lhs: Effect<TestAction> = .cancel(id: "same")
        let rhs: Effect<TestAction> = .cancel(id: "same")
        #expect(lhs == rhs)
    }

    @Test func `Cancel unequal when ids differ`() {
        let lhs: Effect<TestAction> = .cancel(id: "one")
        let rhs: Effect<TestAction> = .cancel(id: "two")
        #expect(lhs != rhs)
    }

    @Test func `Different cases are unequal`() {
        let none: Effect<TestAction> = .none
        let send: Effect<TestAction> = .send(.a)
        let merge: Effect<TestAction> = .merge(.a)
        let run: Effect<TestAction> = .run { _ in }

        #expect(none != send)
        #expect(none != merge)
        #expect(none != run)
        #expect(send != merge)
        #expect(send != run)
        #expect(merge != run)
    }
}
