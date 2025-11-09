import XCTest

final class ListAllUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        // Always false to prevent 8x execution during snapshot runs
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        // Skip during snapshot runs to avoid timeouts
        if ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] == "YES" {
            throw XCTSkip("Launch test disabled during fastlane snapshot")
        }
        
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
