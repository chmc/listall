//
//  WatchHapticManager.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import Foundation
#if os(watchOS)
import WatchKit
#endif

/// Haptic feedback manager for watchOS
class WatchHapticManager {
    static let shared = WatchHapticManager()
    
    private init() {}
    
    /// Play haptic feedback for item completion toggle
    func playItemToggle() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// Play haptic feedback for filter change
    func playFilterChange() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// Play haptic feedback for refresh/sync
    func playRefresh() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// Play haptic feedback for navigation
    func playNavigation() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// Play haptic feedback for success
    func playSuccess() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
    
    /// Play haptic feedback for error
    func playError() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
        #endif
    }
    
    /// Play haptic feedback for warning
    func playWarning() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
