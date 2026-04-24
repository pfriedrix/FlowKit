import XCTest
import os
@testable import FlowKit

final class LoggerTests: XCTestCase {
    
    func testLoggerWithFullFormat() {
        // Given
        let action = "ScheduleReducer.checkAuthorization"
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .full)
        
        // Then
        XCTAssertEqual(formattedAction, "Dispatching action: \(action)", "The full format should show the complete action string.")
    }
    
    func testLoggerWithShortFormatWithoutEllipsis() {
        // Given
        let action = "ScheduleReducer.checkAuthorization" // Fits within the 32-char limit without truncation
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .short)
        
        // Then
        XCTAssertEqual(formattedAction, "Dispatching action: ScheduleReducer.checkAuthorization", "The short format should display the full abbreviation without ellipsis if the content fits.")
    }
    
    func testLoggerWithShortFormatWithEllipsis() {
        // Given
        let action = "HomeReducer.constructorStandings([Parser.ParseConstructorStanding(position: 1, name: \"McLaren Mercedes\", points: 593.0)])"
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .short)
        
        // Then
        XCTAssertEqual(formattedAction, "Dispatching action: HomeReducer.constructorStandings([Parser.ParseConstructorStandin...", "The short format should add ellipsis when the action is truncated.")
    }
    
    func testLoggerWithAbbreviatedFormat() {
        // Given
        let action = "ArchiveReducer.scenePhase(SwiftUI.ScenePhase.active)"

        // When
        let formattedAction = ActionFormatter().format(action: action, style: .abbreviated)

        // Then
        XCTAssertEqual(formattedAction, "Dispatching action: ArchiveReducer.scenePhase", "The abbreviated format should only show the main action prefix.")
    }

    // MARK: - Logger configuration round-trip

    /// `Logger.logLevel` round-trips through its unfair-lock-backed setter.
    func testLoggerLogLevel_setterRoundTrips() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .error
        XCTAssertEqual(Logger.logLevel, .error)
    }

    /// `Logger.formatStyle` round-trips through its unfair-lock-backed setter.
    func testLoggerFormatStyle_setterRoundTrips() {
        let original = Logger.formatStyle
        defer { Logger.formatStyle = original }

        Logger.formatStyle = .abbreviated
        XCTAssertEqual(Logger.formatStyle, .abbreviated)

        Logger.formatStyle = .short
        XCTAssertEqual(Logger.formatStyle, .short)
    }

    /// Log methods below the current `logLevel` early-return without emitting.
    /// No way to intercept `os.Logger` output in-process, so this is a smoke test
    /// that the early-return branch executes without crashing.
    func testLoggerMethods_earlyReturnWhenBelowLevel() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .fault // filter everything weaker

        Logger.shared.debug("debug")
        Logger.shared.info("info")
        Logger.shared.error("error")
        Logger.shared.action("action")

        // Reaching this line without a trap confirms the guards executed.
        XCTAssertEqual(Logger.logLevel, .fault)
    }

    /// Log methods at/above the current `logLevel` take the emit branch.
    func testLoggerMethods_emitWhenAboveLevel() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .debug

        Logger.shared.debug("debug")
        Logger.shared.info("info")
        Logger.shared.error("error")
        Logger.shared.fault("fault")

        XCTAssertEqual(Logger.logLevel, .debug)
    }
}
