//
//  ListAllMacUITestsLaunchTests.swift
//  ListAllMacUITests
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import XCTest

final class ListAllMacUITestsLaunchTests: MacUITestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override class func setUp() {
        super.setUp()
        // Note: MacUITestCase.setUp() handles appearance saving
    }

    override class func tearDown() {
        // Note: MacUITestCase.tearDown() handles appearance restoration
        super.tearDown()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
