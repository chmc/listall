//
//  WatchHapticManagerTests.swift
//  ListAllWatch Watch AppTests
//
//  Created by AI Assistant on 24.10.2025.
//

import XCTest
@testable import ListAllWatch_Watch_App

class WatchHapticManagerTests: XCTestCase {
    
    func testSingletonInstance() {
        // Test that WatchHapticManager is a singleton
        let instance1 = WatchHapticManager.shared
        let instance2 = WatchHapticManager.shared
        
        XCTAssertTrue(instance1 === instance2, "WatchHapticManager should be a singleton")
    }
    
    func testHapticMethodsExist() {
        let manager = WatchHapticManager.shared
        
        // Test that all haptic methods exist and can be called
        // Note: We can't test actual haptic feedback in simulator, but we can test method existence
        XCTAssertNoThrow(manager.playItemToggle(), "playItemToggle should not throw")
        XCTAssertNoThrow(manager.playFilterChange(), "playFilterChange should not throw")
        XCTAssertNoThrow(manager.playRefresh(), "playRefresh should not throw")
        XCTAssertNoThrow(manager.playNavigation(), "playNavigation should not throw")
        XCTAssertNoThrow(manager.playSuccess(), "playSuccess should not throw")
        XCTAssertNoThrow(manager.playError(), "playError should not throw")
        XCTAssertNoThrow(manager.playWarning(), "playWarning should not throw")
    }
}
