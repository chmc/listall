import XCTest
@testable import ListAll

@MainActor
final class HapticManagerTests: XCTestCase {
    
    var hapticManager: HapticManager!
    
    override func setUp() async throws {
        try await super.setUp()
        hapticManager = HapticManager.shared
    }
    
    override func tearDown() async throws {
        hapticManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testHapticManagerSingleton() {
        // Given/When
        let instance1 = HapticManager.shared
        let instance2 = HapticManager.shared
        
        // Then
        XCTAssertTrue(instance1 === instance2, "HapticManager should be a singleton")
    }
    
    func testHapticManagerDefaultEnabled() {
        // Given/When
        let isEnabled = hapticManager.isEnabled
        
        // Then
        XCTAssertTrue(isEnabled, "Haptics should be enabled by default")
    }
    
    // MARK: - Enable/Disable Tests
    
    func testToggleHapticsEnabled() {
        // Given
        let initialState = hapticManager.isEnabled
        
        // When
        hapticManager.isEnabled = false
        
        // Then
        XCTAssertFalse(hapticManager.isEnabled, "Haptics should be disabled")
        XCTAssertNotEqual(initialState && !hapticManager.isEnabled, false, "State should have changed")
        
        // Restore
        hapticManager.isEnabled = true
    }
    
    func testHapticsEnabledPersistence() {
        // Given
        hapticManager.isEnabled = false
        
        // When
        let storedValue = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hapticsEnabled)
        
        // Then
        XCTAssertFalse(storedValue, "Disabled state should persist to UserDefaults")
        
        // Restore
        hapticManager.isEnabled = true
    }
    
    // MARK: - Trigger Tests
    
    func testTriggerSuccess() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.trigger(.success)
    }
    
    func testTriggerWarning() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.trigger(.warning)
    }
    
    func testTriggerError() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.trigger(.error)
    }
    
    func testTriggerSelection() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.trigger(.selection)
    }
    
    func testTriggerImpact() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.trigger(.impact(.light))
        hapticManager.trigger(.impact(.medium))
        hapticManager.trigger(.impact(.heavy))
        hapticManager.trigger(.impact(.soft))
        hapticManager.trigger(.impact(.rigid))
    }
    
    func testTriggerWhenDisabled() {
        // Given
        hapticManager.isEnabled = false
        
        // When/Then - Should not crash and should be no-op
        hapticManager.trigger(.success)
        hapticManager.trigger(.selection)
        hapticManager.trigger(.impact(.medium))
    }
    
    // MARK: - Convenience Methods Tests
    
    func testItemCrossedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemCrossed()
    }
    
    func testItemUncrossedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemUncrossed()
    }
    
    func testItemCreatedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemCreated()
    }
    
    func testItemDeletedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemDeleted()
    }
    
    func testListCreatedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.listCreated()
    }
    
    func testListDeletedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.listDeleted()
    }
    
    func testListArchivedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.listArchived()
    }
    
    func testSelectionModeToggledHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.selectionModeToggled()
    }
    
    func testItemSelectedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemSelected()
    }
    
    func testDragStartedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.dragStarted()
    }
    
    func testDragDroppedHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.dragDropped()
    }
    
    // MARK: - Prepare Tests
    
    func testPrepareForHaptic() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.prepare(for: .success)
        hapticManager.prepare(for: .selection)
        hapticManager.prepare(for: .impact(.medium))
    }
    
    func testPrepareWhenDisabled() {
        // Given
        hapticManager.isEnabled = false
        
        // When/Then - Should not crash and should be no-op
        hapticManager.prepare(for: .success)
        hapticManager.prepare(for: .selection)
    }
    
    // MARK: - Integration Tests
    
    func testMultipleTriggersInSequence() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemCreated()
        hapticManager.itemCrossed()
        hapticManager.itemUncrossed()
        hapticManager.itemDeleted()
    }
    
    func testToggleEnabledBetweenTriggers() {
        // Given
        hapticManager.isEnabled = true
        
        // When/Then - Should not crash
        hapticManager.itemCreated()
        
        hapticManager.isEnabled = false
        hapticManager.itemCrossed()
        
        hapticManager.isEnabled = true
        hapticManager.itemDeleted()
    }
}

