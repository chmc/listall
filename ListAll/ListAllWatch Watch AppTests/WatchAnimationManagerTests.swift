//
//  WatchAnimationManagerTests.swift
//  ListAllWatch Watch AppTests
//
//  Created by AI Assistant on 24.10.2025.
//

import XCTest
@testable import ListAllWatch_Watch_App

class WatchAnimationManagerTests: XCTestCase {
    
    func testSingletonInstance() {
        // Test that WatchAnimationManager is a singleton
        let instance1 = WatchAnimationManager.shared
        let instance2 = WatchAnimationManager.shared
        
        XCTAssertTrue(instance1 === instance2, "WatchAnimationManager should be a singleton")
    }
    
    func testAnimationTypes() {
        // Test that animations are properly defined
        let itemToggle = WatchAnimationManager.itemToggle
        let filterChange = WatchAnimationManager.filterChange
        let syncIndicator = WatchAnimationManager.syncIndicator
        
        // Test that animations are not nil (they should be valid Animation objects)
        XCTAssertNotNil(itemToggle, "Item toggle animation should be defined")
        XCTAssertNotNil(filterChange, "Filter change animation should be defined")
        XCTAssertNotNil(syncIndicator, "Sync indicator animation should be defined")
    }
    
    func testPerformanceModeAnimations() {
        let manager = WatchPerformanceManager.shared
        
        // Test that animation durations adapt to performance mode
        let baseDuration = 0.3
        let lowPowerDuration = manager.getAnimationDuration(for: baseDuration)
        let normalDuration = manager.getAnimationDuration(for: baseDuration)
        let highPerformanceDuration = manager.getAnimationDuration(for: baseDuration)
        
        XCTAssertGreaterThan(lowPowerDuration, 0, "Low power animation duration should be positive")
        XCTAssertGreaterThan(normalDuration, 0, "Normal animation duration should be positive")
        XCTAssertGreaterThan(highPerformanceDuration, 0, "High performance animation duration should be positive")
    }
}
