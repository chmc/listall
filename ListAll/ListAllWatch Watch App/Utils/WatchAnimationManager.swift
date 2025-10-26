import SwiftUI

/// Manager for watchOS-specific animationschAnimationManager.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI

/// Animation manager for watchOS with optimized animations
class WatchAnimationManager {
    static let shared = WatchAnimationManager()
    
    private init() {}
    
    /// Quick animation for item toggle
    static let itemToggle = Animation.easeInOut(duration: 0.15)
    
    /// Smooth animation for filter changes
    static let filterChange = Animation.easeInOut(duration: 0.2)
    
    /// Animation for sync indicator
    static let syncIndicator = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    /// Animation for loading states
    static let loading = Animation.easeInOut(duration: 0.3)
    
    /// Animation for navigation transitions
    static let navigation = Animation.easeInOut(duration: 0.25)
    
    /// Animation for list updates
    static let listUpdate = Animation.easeInOut(duration: 0.2)
    
    /// Animation for error states
    static let error = Animation.easeInOut(duration: 0.3)
    
    /// Animation for success states
    static let success = Animation.spring(response: 0.4, dampingFraction: 0.7)
}

/// Extension to add watchOS-optimized animations to View
extension View {
    /// Apply item toggle animation
    func itemToggleAnimation() -> some View {
        self.animation(WatchAnimationManager.itemToggle, value: UUID())
    }
    
    /// Apply filter change animation
    func filterChangeAnimation() -> some View {
        self.animation(WatchAnimationManager.filterChange, value: UUID())
    }
    
    /// Apply sync indicator animation
    func syncIndicatorAnimation() -> some View {
        self.animation(WatchAnimationManager.syncIndicator, value: UUID())
    }
    
    /// Apply loading animation
    func loadingAnimation() -> some View {
        self.animation(WatchAnimationManager.loading, value: UUID())
    }
    
    /// Apply navigation animation
    func navigationAnimation() -> some View {
        self.animation(WatchAnimationManager.navigation, value: UUID())
    }
    
    /// Apply list update animation
    func listUpdateAnimation() -> some View {
        self.animation(WatchAnimationManager.listUpdate, value: UUID())
    }
    
    /// Apply error animation
    func errorAnimation() -> some View {
        self.animation(WatchAnimationManager.error, value: UUID())
    }
    
    /// Apply success animation
    func successAnimation() -> some View {
        self.animation(WatchAnimationManager.success, value: UUID())
    }
}
