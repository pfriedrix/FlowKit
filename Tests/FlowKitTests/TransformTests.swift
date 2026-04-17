import XCTest
@testable import FlowKit

final class Collector<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [T] = []

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    func append(_ value: T) {
        lock.lock()
        _values.append(value)
        lock.unlock()
    }
}

@MainActor
final class TransformTests: XCTestCase {

    func testIdentityTransformReturnsOriginalSend() {
        let identity = Transform<String>.identity
        let received = Collector<String>()
        let original = Send<String>(send: { received.append($0) })

        let result = identity.apply(to: original)
        result("hello")

        XCTAssertEqual(received.values, ["hello"])
        XCTAssertTrue(identity._isIdentity)
    }

    func testCustomTransformWrapsActions() {
        let received = Collector<String>()
        let transform = Transform<String> { send in
            Send { action in
                send("wrapped(\(action))")
            }
        }

        let original = Send<String>(send: { received.append($0) })
        let wrapped = transform.apply(to: original)
        wrapped("test")

        XCTAssertEqual(received.values, ["wrapped(test)"])
        XCTAssertFalse(transform._isIdentity)
    }

    func testTransformOnNoneReturnsNone() {
        let effect = Effect<String>.none
        let transform = Transform<String> { send in
            Send { action in send("wrapped(\(action))") }
        }

        let result = effect.transform(transform)
        XCTAssertTrue(result.isNone)
    }

    func testIdentityTransformOnEffectReturnsSameEffect() {
        let effect = Effect<String>.send("action")
        let result = effect.transform(.identity)

        if case .send(let action) = result.operation {
            XCTAssertEqual(action, "action")
        } else {
            XCTFail("Expected .send operation")
        }
    }

    func testTransformOnSendProducesRunEffect() async throws {
        let received = Collector<String>()
        let transform = Transform<String> { send in
            Send { action in send("T:\(action)") }
        }

        let effect = Effect<String>.send("hello").transform(transform)

        if case .run(_, let operation) = effect.operation {
            await operation(Send { received.append($0) })
            XCTAssertEqual(received.values, ["T:hello"])
        } else {
            XCTFail("Expected .run operation after transform on .send")
        }
    }

    func testTransformOnMergeProducesRunEffect() async throws {
        let received = Collector<String>()
        let transform = Transform<String> { send in
            Send { action in send("M:\(action)") }
        }

        let effect = Effect<String>.merge("a", "b").transform(transform)

        if case .run(_, let operation) = effect.operation {
            await operation(Send { received.append($0) })
            XCTAssertEqual(received.values, ["M:a", "M:b"])
        } else {
            XCTFail("Expected .run operation after transform on .merge")
        }
    }

    func testTransformOnRunPreservesPriority() async throws {
        let received = Collector<String>()
        let transform = Transform<String> { send in
            Send { action in send("R:\(action)") }
        }

        let effect = Effect<String>.run(priority: .high) { send in
            send("original")
        }.transform(transform)

        if case .run(let priority, let operation) = effect.operation {
            XCTAssertEqual(priority, .high)
            await operation(Send { received.append($0) })
            XCTAssertEqual(received.values, ["R:original"])
        } else {
            XCTFail("Expected .run operation")
        }
    }
}
