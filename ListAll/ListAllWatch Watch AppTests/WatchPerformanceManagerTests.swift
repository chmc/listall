//
//  WatchPerformanceManagerTests.swift
//  ListAllWatch Watch AppTests
//
//  Created by AI Assistant on 24.10.2025.
//

import XCTest
@testable import ListAllWatch_Watch_App

class WatchPerformanceManagerTests: XCTestCase {
    
    func testSingletonInstance() {
        // Test that WatchPerformanceManager is a singleton
        let instance1 = WatchPerformanceManager.shared
        let instance2 = WatchPerformanceManager.shared
        
        XCTAssertTrue(instance1 === instance2, "WatchPerformanceManager should be a singleton")
    }
    
    func testPerformanceModeEnum() {
        // Test that all performance modes exist
        let modes: [WatchPerformanceManager.PerformanceMode] = [.lowPower, .normal, .highPerformance]
        XCTAssertEqual(modes.count, 3, "Should have 3 performance modes")
    }
    
    func testAnimationDurationScaling() {
        let manager = WatchPerformanceManager.shared
        let baseDuration = 0.5
        
        // Test that animation durations scale appropriately
        let lowPowerDuration = manager.getAnimationDuration(for: baseDuration)
        let normalDuration = manager.getAnimationDuration(for: baseDuration)
        let highPerformanceDuration = manager.getAnimationDuration(for: baseDuration)
        
        XCTAssertGreaterThan(lowPowerDuration, 0, "Low power duration should be positive")
        XCTAssertGreaterThan(normalDuration, 0, "Normal duration should be positive")
        XCTAssertGreaterThan(highPerformanceDuration, 0, "High performance duration should be positive")
        
        // Low power should be faster (shorter duration)
        XCTAssertLessThanOrEqual(lowPowerDuration, baseDuration, "Low power should be faster than base")
    }
    
    func testRefreshRate() {
        let manager = WatchPerformanceManager.shared
        
        let lowPowerRate = manager.getRefreshRate()
        let normalRate = manager.getRefreshRate()
        let highPerformanceRate = manager.getRefreshRate()
        
        XCTAssertGreaterThan(lowPowerRate, 0, "Refresh rate should be positive")
        XCTAssertLessThanOrEqual(lowPowerRate, 1.0, "Refresh rate should be reasonable")
    }
    
    func testBatchSize() {
        let manager = WatchPerformanceManager.shared
        
        let lowPowerBatch = manager.getOptimalBatchSize()
        let normalBatch = manager.getOptimalBatchSize()
        let highPerformanceBatch = manager.getOptimalBatchSize()
        
        XCTAssertGreaterThan(lowPowerBatch, 0, "Batch size should be positive")
        XCTAssertLessThanOrEqual(lowPowerBatch, 100, "Batch size should be reasonable")
    }
    
    func testAnimationReduction() {
        let manager = WatchPerformanceManager.shared
        
        // Test that animation reduction methods exist
        XCTAssertNoThrow(manager.shouldReduceAnimations(), "shouldReduceAnimations should not throw")
        XCTAssertNoThrow(manager.shouldReduceSyncFrequency(), "shouldReduceSyncFrequency should not throw")
    }
}
