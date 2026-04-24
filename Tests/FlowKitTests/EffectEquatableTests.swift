import XCTest
@testable import FlowKit

@MainActor
final class EffectEquatableTests: XCTestCase {
    enum TestAction: Equatable, Sendable {
        case a
        case b
        case payload(Int)
    }

    // MARK: - isNone

    func testIsNoneTrueForNone() {
        let effect: Effect<TestAction> = .none
        XCTAssertTrue(effect.isNone)
    }

    func testIsNoneFalseForSend() {
        let effect: Effect<TestAction> = .send(.a)
        XCTAssertFalse(effect.isNone)
    }

    func testIsNoneFalseForMerge() {
        let effect: Effect<TestAction> = .merge(.a, .b)
        XCTAssertFalse(effect.isNone)
    }

    func testIsNoneFalseForRun() {
        let effect: Effect<TestAction> = .run { _ in }
        XCTAssertFalse(effect.isNone)
    }

    // MARK: - Equatable

    func testNoneEqualsNone() {
        let lhs: Effect<TestAction> = .none
        let rhs: Effect<TestAction> = .none
        XCTAssertEqual(lhs, rhs)
    }

    func testSendEqualWhenActionsMatch() {
        let lhs: Effect<TestAction> = .send(.payload(7))
        let rhs: Effect<TestAction> = .send(.payload(7))
        XCTAssertEqual(lhs, rhs)
    }

    func testSendUnequalWhenActionsDiffer() {
        let lhs: Effect<TestAction> = .send(.payload(1))
        let rhs: Effect<TestAction> = .send(.payload(2))
        XCTAssertNotEqual(lhs, rhs)
    }

    func testMergeEqualWhenActionsMatch() {
        let lhs: Effect<TestAction> = .merge(.a, .b)
        let rhs: Effect<TestAction> = .merge(.a, .b)
        XCTAssertEqual(lhs, rhs)
    }

    func testMergeUnequalWhenActionsDiffer() {
        let lhs: Effect<TestAction> = .merge(.a, .b)
        let rhs: Effect<TestAction> = .merge(.a)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testRunEqualWhenPrioritiesMatch() {
        let lhs: Effect<TestAction> = .run(priority: .high) { _ in }
        let rhs: Effect<TestAction> = .run(priority: .high) { _ in }
        XCTAssertEqual(lhs, rhs)
    }

    func testRunUnequalWhenPrioritiesDiffer() {
        let lhs: Effect<TestAction> = .run(priority: .high) { _ in }
        let rhs: Effect<TestAction> = .run(priority: .low) { _ in }
        XCTAssertNotEqual(lhs, rhs)
    }

    func testCancelEqualWhenIdsMatch() {
        let lhs: Effect<TestAction> = .cancel(id: "same")
        let rhs: Effect<TestAction> = .cancel(id: "same")
        XCTAssertEqual(lhs, rhs)
    }

    func testCancelUnequalWhenIdsDiffer() {
        let lhs: Effect<TestAction> = .cancel(id: "one")
        let rhs: Effect<TestAction> = .cancel(id: "two")
        XCTAssertNotEqual(lhs, rhs)
    }

    func testDifferentCasesAreUnequal() {
        let none: Effect<TestAction> = .none
        let send: Effect<TestAction> = .send(.a)
        let merge: Effect<TestAction> = .merge(.a)
        let run: Effect<TestAction> = .run { _ in }

        XCTAssertNotEqual(none, send)
        XCTAssertNotEqual(none, merge)
        XCTAssertNotEqual(none, run)
        XCTAssertNotEqual(send, merge)
        XCTAssertNotEqual(send, run)
        XCTAssertNotEqual(merge, run)
    }
}
