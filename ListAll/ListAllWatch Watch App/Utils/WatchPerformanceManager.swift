//
//  WatchPerformanceManager.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 20.10.2025.
//

import Foundation
import SwiftUI
import Combine

/// Performance manager for watchOS optimizations
class WatchPerformanceManager: ObservableObject {
    static let shared = WatchPerformanceManager()
    
    @Published var isLowPowerMode = false
    @Published var memoryWarning = false
    @Published var performanceMode: PerformanceMode = .normal
    
    private var memoryWarningObserver: NSObjectProtocol?
    
    enum PerformanceMode {
        case lowPower
        case normal
        case highPerformance
    }
    
    private init() {
        setupMemoryWarningObserver()
        updatePerformanceMode()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Setup memory warning observer
    private func setupMemoryWarningObserver() {
        // Note: UIApplication.didReceiveMemoryWarningNotification is not available on watchOS
        // We'll use a different approach for memory monitoring on watchOS
        // This could be implemented using ProcessInfo or other watchOS-compatible methods
        #if os(watchOS)
        // For now, we'll skip memory warning monitoring on watchOS
        // In a real implementation, you might use ProcessInfo or other watchOS-compatible APIs
        #else
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() {
        memoryWarning = true
        performanceMode = .lowPower
        
        // Clear caches and reduce memory usage
        clearCaches()
        
        // Reset memory warning after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.memoryWarning = false
        }
    }
    
    /// Update performance mode based on system conditions
    private func updatePerformanceMode() {
        // Check for low power mode (if available on watchOS)
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            performanceMode = .lowPower
        } else {
            performanceMode = .normal
        }
    }
    
    /// Clear caches to free memory
    private func clearCaches() {
        // Clear any cached data
        URLCache.shared.removeAllCachedResponses()
        
        // Force garbage collection
        autoreleasepool {
            // Any cleanup operations
        }
    }
    
    /// Get optimal animation duration based on performance mode
    func getAnimationDuration(for baseDuration: Double) -> Double {
        switch performanceMode {
        case .lowPower:
            return baseDuration * 0.5 // Faster animations
        case .normal:
            return baseDuration
        case .highPerformance:
            return baseDuration * 1.2 // Smoother animations
        }
    }
    
    /// Get optimal refresh rate based on performance mode
    func getRefreshRate() -> Double {
        switch performanceMode {
        case .lowPower:
            return 0.5 // Refresh every 0.5 seconds
        case .normal:
            return 1.0 // Refresh every second
        case .highPerformance:
            return 0.1 // Refresh every 0.1 seconds
        }
    }
    
    /// Check if animations should be reduced
    func shouldReduceAnimations() -> Bool {
        return performanceMode == .lowPower || memoryWarning
    }
    
    /// Check if sync frequency should be reduced
    func shouldReduceSyncFrequency() -> Bool {
        return performanceMode == .lowPower || memoryWarning
    }
    
    /// Get optimal batch size for data operations
    func getOptimalBatchSize() -> Int {
        switch performanceMode {
        case .lowPower:
            return 10 // Smaller batches
        case .normal:
            return 25 // Normal batches
        case .highPerformance:
            return 50 // Larger batches
        }
    }
}

/// Extension to add performance-aware animations to View
extension View {
    /// Apply performance-aware animation
    func performanceAnimation<T: Equatable>(_ value: T, duration: Double = 0.3) -> some View {
        let manager = WatchPerformanceManager.shared
        let actualDuration = manager.getAnimationDuration(for: duration)
        
        if manager.shouldReduceAnimations() {
            return self.animation(.easeInOut(duration: actualDuration), value: value)
        } else {
            return self.animation(.spring(response: actualDuration, dampingFraction: 0.8), value: value)
        }
    }
    
    /// Apply performance-aware transition
    func performanceTransition(_ transition: AnyTransition) -> some View {
        let manager = WatchPerformanceManager.shared
        
        if manager.shouldReduceAnimations() {
            return self.transition(transition)
        } else {
            return self.transition(transition)
        }
    }
}
