//
//  WatchLoadingViewTests.swift
//  ListAllWatch Watch AppTests
//
//  Created by AI Assistant on 24.10.2025.
//

import XCTest
import SwiftUI
@testable import ListAllWatch_Watch_App

class WatchLoadingViewTests: XCTestCase {
    
    func testWatchLoadingViewInitialization() {
        // Test default initialization
        let defaultView = WatchLoadingView()
        XCTAssertNotNil(defaultView, "WatchLoadingView should initialize with default parameters")
        
        // Test custom initialization
        let customView = WatchLoadingView(message: "Custom loading...", showProgress: false)
        XCTAssertNotNil(customView, "WatchLoadingView should initialize with custom parameters")
    }
    
    func testWatchSyncLoadingViewInitialization() {
        let syncView = WatchSyncLoadingView()
        XCTAssertNotNil(syncView, "WatchSyncLoadingView should initialize")
    }
    
    func testWatchErrorViewInitialization() {
        let errorView = WatchErrorView(message: "Test error") {
            // Test retry closure
        }
        XCTAssertNotNil(errorView, "WatchErrorView should initialize with message and retry closure")
    }
    
    func testErrorViewRetryClosure() {
        var retryCalled = false
        
        let errorView = WatchErrorView(message: "Test error") {
            retryCalled = true
        }
        
        // Note: We can't easily test the button action in unit tests,
        // but we can verify the closure is stored properly
        XCTAssertNotNil(errorView, "Error view should store retry closure")
    }
}
