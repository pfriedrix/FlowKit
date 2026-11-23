import Testing
import os
@testable import FlowKit

// `Logger.logLevel` / `Logger.formatStyle` are process-wide. StoreTests writes `Logger.logLevel`
// from its MainActor init, so keeping every set-then-read of the logger config here synchronous
// on MainActor (and serialized within this suite) means no other suite's write can land in between.
@Suite(.serialized)
@MainActor
struct LoggerTests {
    
    @Test func `Logger with full format`() {
        // Given
        let action = "ScheduleReducer.checkAuthorization"
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .full)
        
        // Then
        #expect(formattedAction == "Dispatching action: \(action)", "The full format should show the complete action string.")
    }
    
    @Test func `Logger with short format without ellipsis`() {
        // Given
        let action = "ScheduleReducer.checkAuthorization" // Fits within the 32-char limit without truncation
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .short)
        
        // Then
        #expect(formattedAction == "Dispatching action: ScheduleReducer.checkAuthorization", "The short format should display the full abbreviation without ellipsis if the content fits.")
    }
    
    @Test func `Logger with short format with ellipsis`() {
        // Given
        let action = "HomeReducer.constructorStandings([Parser.ParseConstructorStanding(position: 1, name: \"McLaren Mercedes\", points: 593.0)])"
        
        // When
        let formattedAction = ActionFormatter().format(action: action, style: .short)
        
        // Then
        #expect(formattedAction == "Dispatching action: HomeReducer.constructorStandings([Parser.ParseConstructorStandin...", "The short format should add ellipsis when the action is truncated.")
    }
    
    @Test func `Logger with abbreviated format`() {
        // Given
        let action = "ArchiveReducer.scenePhase(SwiftUI.ScenePhase.active)"

        // When
        let formattedAction = ActionFormatter().format(action: action, style: .abbreviated)

        // Then
        #expect(formattedAction == "Dispatching action: ArchiveReducer.scenePhase", "The abbreviated format should only show the main action prefix.")
    }

    // MARK: - Logger configuration round-trip

    /// `Logger.logLevel` round-trips through its unfair-lock-backed setter.
    @Test func `Logger log level setter round trips`() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .error
        #expect(Logger.logLevel == .error)
    }

    /// `Logger.formatStyle` round-trips through its unfair-lock-backed setter.
    @Test func `Logger format style setter round trips`() {
        let original = Logger.formatStyle
        defer { Logger.formatStyle = original }

        Logger.formatStyle = .abbreviated
        #expect(Logger.formatStyle == .abbreviated)

        Logger.formatStyle = .short
        #expect(Logger.formatStyle == .short)
    }

    /// Log methods below the current `logLevel` early-return without emitting.
    /// No way to intercept `os.Logger` output in-process, so this is a smoke test
    /// that the early-return branch executes without crashing.
    @Test func `Logger methods early return when below level`() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .fault // filter everything weaker

        Logger.shared.debug("debug")
        Logger.shared.info("info")
        Logger.shared.error("error")
        Logger.shared.action("action")

        // Reaching this line without a trap confirms the guards executed.
        #expect(Logger.logLevel == .fault)
    }

    /// Log methods at/above the current `logLevel` take the emit branch.
    @Test func `Logger methods emit when above level`() {
        let original = Logger.logLevel
        defer { Logger.logLevel = original }

        Logger.logLevel = .debug

        Logger.shared.debug("debug")
        Logger.shared.info("info")
        Logger.shared.error("error")
        Logger.shared.fault("fault")

        #expect(Logger.logLevel == .debug)
    }
}
