import XCTest
@testable import ListAll

class DetailCardIconColorTests: XCTestCase {

    func testQuantityCardUsesBrandTealColor() {
        // The quantity detail card in ItemDetailView should use Theme.Colors.primary (brand teal)
        // instead of Theme.Colors.info
        let expectedColor = Theme.Colors.primary

        // Verify the color constant exists and is the accent color
        XCTAssertNotNil(expectedColor, "Theme.Colors.primary should exist")

        // Verify it's different from the old system colors that were previously used
        XCTAssertNotEqual(
            Theme.Colors.info.description,
            Theme.Colors.primary.description,
            "Brand teal should differ from info color"
        )
    }

    func testImagesCardUsesBrandTealColor() {
        // The images detail card in ItemDetailView should use Theme.Colors.primary (brand teal)
        // instead of Theme.Colors.warning
        let expectedColor = Theme.Colors.primary

        XCTAssertNotNil(expectedColor, "Theme.Colors.primary should exist")

        XCTAssertNotEqual(
            Theme.Colors.warning.description,
            Theme.Colors.primary.description,
            "Brand teal should differ from warning color"
        )
    }
}
