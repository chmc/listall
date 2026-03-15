import XCTest
@testable import ListAll

class StatusBadgeTests: XCTestCase {

    // MARK: - StatusBadgeConfiguration Tests

    func testActiveBadgeConfiguration() {
        let config = StatusBadgeConfiguration(isCrossedOut: false)

        XCTAssertEqual(config.text, "Active")
        XCTAssertEqual(config.iconName, "circle.fill")
        XCTAssertFalse(config.isCrossedOut)
    }

    func testCompletedBadgeConfiguration() {
        let config = StatusBadgeConfiguration(isCrossedOut: true)

        XCTAssertEqual(config.text, "Completed")
        XCTAssertEqual(config.iconName, "checkmark")
        XCTAssertTrue(config.isCrossedOut)
    }
}
