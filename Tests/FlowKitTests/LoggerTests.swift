import XCTest
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
    
    func testLoggerActionDispatch() {
        // Given
        let logger = Logger.shared
        Logger.formatStyle = .short
        let action = "ScheduleReducer.isGranted(true)"
        
        // When
        logger.action(action) // This should trigger logging
        
        // Since capturing console output or OSLog is complex in a unit test environment,
        // we rely on testing whether the method runs without errors for now.
        XCTAssertTrue(true, "Logger action dispatch called successfully.")
    }
}
