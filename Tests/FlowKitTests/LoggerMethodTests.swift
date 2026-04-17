import XCTest
import os
@testable import FlowKit

final class LoggerMethodTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Logger.logLevel = .debug
        Logger.formatStyle = .full
    }

    func testDebugDoesNotCrash() {
        Logger.shared.debug("debug message")
    }

    func testInfoDoesNotCrash() {
        Logger.shared.info("info message")
    }

    func testErrorDoesNotCrash() {
        Logger.shared.error("error message")
    }

    func testFaultDoesNotCrash() {
        Logger.shared.fault("fault message")
    }

    func testActionWithAllFormatStyles() {
        for style in [ActionFormatter.FormatStyle.full, .short, .abbreviated] {
            Logger.formatStyle = style
            Logger.shared.action("TestReducer.someAction(value: 42)")
        }
    }

    func testLogLevelFiltering() {
        Logger.logLevel = .error

        Logger.shared.debug("should be filtered")
        Logger.shared.info("should be filtered")
        Logger.shared.error("should pass")
        Logger.shared.fault("should pass")
    }

    func testLogLevelThreadSafety() {
        let group = DispatchGroup()

        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    Logger.logLevel = .debug
                } else {
                    Logger.logLevel = .error
                }
                group.leave()
            }
        }

        group.wait()

        let level = Logger.logLevel
        XCTAssertTrue(level == .debug || level == .error)
    }

    func testFormatStyleThreadSafety() {
        let group = DispatchGroup()

        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    Logger.formatStyle = .full
                } else {
                    Logger.formatStyle = .abbreviated
                }
                group.leave()
            }
        }

        group.wait()

        let style = Logger.formatStyle
        XCTAssertTrue(style == .full || style == .abbreviated)
    }
}
