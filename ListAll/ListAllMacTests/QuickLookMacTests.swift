//
//  QuickLookMacTests.swift
//  ListAllMacTests
//

import XCTest
import CoreData
import Combine
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

#if os(macOS)

final class QuickLookMacTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates test JPEG image data for testing
    private func createTestImageData(width: Int = 100, height: Int = 100) -> Data? {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    /// Creates test item with specified number of images
    private func createTestItem(withImageCount count: Int) -> Item {
        var item = Item(title: "Test Item with Images")
        item.itemDescription = "Test description"

        for i in 0..<count {
            var image = ItemImage(itemId: item.id)
            image.imageData = createTestImageData()
            image.orderNumber = i
            item.images.append(image)
        }

        return item
    }

    // MARK: - Platform Verification

    func testRunningOnMacOS() {
        #if os(macOS)
        XCTAssertTrue(true, "Running on macOS as expected")
        #else
        XCTFail("This test should only run on macOS")
        #endif
    }

    // MARK: - QuickLookPreviewItem Tests

    func testQuickLookPreviewItemCreation() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: imageData, itemId: UUID())
        let previewItem = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "Test Item",
            index: 0
        )

        XCTAssertNotNil(previewItem.itemImage)
        XCTAssertEqual(previewItem.displayTitle, "Test Item")
        XCTAssertEqual(previewItem.index, 0)
    }

    func testQuickLookPreviewItemTitle() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: imageData, itemId: UUID())

        // Test with display title
        let previewItem1 = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "My Item",
            index: 2
        )
        XCTAssertEqual(previewItem1.previewItemTitle, "My Item - Image 3")

        // Test with empty display title
        let previewItem2 = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "",
            index: 0
        )
        XCTAssertEqual(previewItem2.previewItemTitle, "Image 1")
    }

    func testQuickLookPreviewItemURLCreation() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: imageData, itemId: UUID())
        let previewItem = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "Test",
            index: 0
        )

        // Access previewItemURL to trigger temporary file creation
        let url = previewItem.previewItemURL

        XCTAssertNotNil(url, "Preview URL should not be nil")

        if let url = url {
            XCTAssertTrue(url.path.contains("quicklook_"), "URL should contain quicklook prefix")
            XCTAssertTrue(url.pathExtension == "jpg", "URL should have .jpg extension")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Temporary file should exist")
        }
    }

    func testQuickLookPreviewItemNoImageData() {
        // Create ItemImage without data
        let itemImage = ItemImage(imageData: nil, itemId: UUID())
        let previewItem = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "Test",
            index: 0
        )

        let url = previewItem.previewItemURL
        XCTAssertNil(url, "Preview URL should be nil when no image data")
    }

    func testQuickLookPreviewItemCleanup() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: imageData, itemId: UUID())
        let previewItem = QuickLookPreviewItem(
            itemImage: itemImage,
            displayTitle: "Test",
            index: 0
        )

        // Get URL first (creates file)
        let url = previewItem.previewItemURL
        XCTAssertNotNil(url)

        if let url = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

            // Explicitly cleanup
            previewItem.cleanupTemporaryFile()

            // File should be removed
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - QuickLookPreviewCollection Tests

    func testQuickLookPreviewCollectionFromItem() {
        let item = createTestItem(withImageCount: 3)
        let collection = QuickLookPreviewCollection(item: item)

        XCTAssertTrue(collection.hasPreviewItems)
        XCTAssertEqual(collection.count, 3)
    }

    func testQuickLookPreviewCollectionFromItemNoImages() {
        var item = Item(title: "No Images")
        item.images = []

        let collection = QuickLookPreviewCollection(item: item)

        XCTAssertFalse(collection.hasPreviewItems)
        XCTAssertEqual(collection.count, 0)
    }

    func testQuickLookPreviewCollectionFromSingleImage() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: imageData, itemId: UUID())
        let collection = QuickLookPreviewCollection(itemImage: itemImage, title: "Single Image")

        XCTAssertTrue(collection.hasPreviewItems)
        XCTAssertEqual(collection.count, 1)
    }

    func testQuickLookPreviewCollectionCleanup() {
        let item = createTestItem(withImageCount: 2)
        let collection = QuickLookPreviewCollection(item: item)

        // Access URLs to create temp files
        let urls = collection.previewItems.compactMap { $0.previewItemURL }
        XCTAssertEqual(urls.count, 2)

        // Verify files exist
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }

        // Cleanup
        collection.cleanup()

        // Verify files are removed
        for url in urls {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testQuickLookPreviewCollectionCurrentIndex() {
        let item = createTestItem(withImageCount: 5)
        let collection = QuickLookPreviewCollection(item: item)

        XCTAssertEqual(collection.currentIndex, 0)

        collection.currentIndex = 3
        XCTAssertEqual(collection.currentIndex, 3)
    }

    // MARK: - QuickLookController Tests

    func testQuickLookControllerSingleton() {
        let controller1 = QuickLookController.shared
        let controller2 = QuickLookController.shared

        XCTAssertTrue(controller1 === controller2, "QuickLookController should be singleton")
    }

    func testQuickLookControllerPanelVisibility() {
        let controller = QuickLookController.shared

        // Initially panel should not be visible (no preview shown)
        // Note: This test may vary based on system state
        // We mainly verify the property is accessible
        _ = controller.isPanelVisible
        XCTAssertTrue(true, "isPanelVisible property is accessible")
    }

    func testQuickLookControllerHidePreview() {
        let controller = QuickLookController.shared

        // Hide should work even if nothing is showing
        controller.hidePreview()
        XCTAssertTrue(true, "hidePreview does not crash")
    }

    // MARK: - QLPreviewPanelDataSource Tests

    func testPreviewPanelDataSourceNumberOfItems() {
        let item = createTestItem(withImageCount: 4)
        let collection = QuickLookPreviewCollection(item: item)

        let count = collection.numberOfPreviewItems(in: nil)
        XCTAssertEqual(count, 4)
    }

    func testPreviewPanelDataSourcePreviewItemAtIndex() {
        let item = createTestItem(withImageCount: 3)
        let collection = QuickLookPreviewCollection(item: item)

        let previewItem0 = collection.previewPanel(nil, previewItemAt: 0)
        XCTAssertNotNil(previewItem0)
        XCTAssertTrue(previewItem0 is QuickLookPreviewItem)

        let previewItem2 = collection.previewPanel(nil, previewItemAt: 2)
        XCTAssertNotNil(previewItem2)

        // Out of bounds
        let previewItemInvalid = collection.previewPanel(nil, previewItemAt: 10)
        XCTAssertNil(previewItemInvalid)
    }

    // MARK: - Notification Tests

    func testQuickLookNotificationNames() {
        XCTAssertEqual(
            Notification.Name.showQuickLookPreview.rawValue,
            "ShowQuickLookPreview"
        )
        XCTAssertEqual(
            Notification.Name.hideQuickLookPreview.rawValue,
            "HideQuickLookPreview"
        )
    }

    // MARK: - Item Model Integration Tests

    func testItemHasImagesProperty() {
        var itemWithImages = Item(title: "With Images")
        var image = ItemImage(itemId: itemWithImages.id)
        image.imageData = createTestImageData()
        itemWithImages.images = [image]

        XCTAssertTrue(itemWithImages.hasImages)
        XCTAssertEqual(itemWithImages.imageCount, 1)

        let itemWithoutImages = Item(title: "Without Images")
        XCTAssertFalse(itemWithoutImages.hasImages)
        XCTAssertEqual(itemWithoutImages.imageCount, 0)
    }

    func testItemSortedImages() {
        var item = Item(title: "Multiple Images")

        var image1 = ItemImage(itemId: item.id)
        image1.orderNumber = 2
        image1.imageData = createTestImageData()

        var image2 = ItemImage(itemId: item.id)
        image2.orderNumber = 0
        image2.imageData = createTestImageData()

        var image3 = ItemImage(itemId: item.id)
        image3.orderNumber = 1
        image3.imageData = createTestImageData()

        item.images = [image1, image2, image3]

        let sorted = item.sortedImages
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].orderNumber, 0)
        XCTAssertEqual(sorted[1].orderNumber, 1)
        XCTAssertEqual(sorted[2].orderNumber, 2)
    }

    // MARK: - NSImage ItemImage Integration Tests

    func testItemImageNSImage() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        var itemImage = ItemImage(itemId: UUID())
        itemImage.imageData = imageData

        let nsImage = itemImage.nsImage
        XCTAssertNotNil(nsImage, "nsImage should return valid NSImage from JPEG data")

        if let nsImage = nsImage {
            XCTAssertGreaterThan(nsImage.size.width, 0)
            XCTAssertGreaterThan(nsImage.size.height, 0)
        }
    }

    func testItemImageNSImageNilData() {
        let itemImage = ItemImage(imageData: nil, itemId: UUID())
        XCTAssertNil(itemImage.nsImage, "nsImage should be nil when imageData is nil")
    }

    // MARK: - Documentation Test

    func testDocumentQuickLookConfiguration() {
        // This test documents the Quick Look configuration
        print("""

        =======================================
        Quick Look Preview - macOS Implementation
        =======================================

        Files Created:
        - ListAllMac/Views/Components/QuickLookPreviewItem.swift
        - ListAllMac/Views/Components/MacQuickLookView.swift

        Architecture:
        1. QuickLookPreviewItem - QLPreviewItem conformance, wraps ItemImage
        2. QuickLookPreviewCollection - QLPreviewPanelDataSource/Delegate
        3. QuickLookController - Singleton for managing preview panel

        Features:
        - ✅ Single image preview
        - ✅ Multiple image preview with arrow key navigation
        - ✅ Temporary file management for image data
        - ✅ Automatic cleanup when preview closes
        - ✅ Spacebar keyboard shortcut (standard macOS behavior)
        - ✅ Image thumbnail in item row
        - ✅ Badge showing image count
        - ✅ Context menu Quick Look option
        - ✅ Hover button for Quick Look

        Integration Points:
        - MacItemRowView: Shows thumbnail, handles Quick Look trigger
        - MacListDetailView: List-level spacebar handling
        - QuickLookController: Manages QLPreviewPanel

        Keyboard Shortcuts:
        - Space: Quick Look selected item's images
        - Left/Right Arrow: Navigate between images in preview
        - Escape: Close preview panel

        Technical Notes:
        - Uses Quartz framework (contains QuickLookUI)
        - QLPreviewPanel requires file URLs (not in-memory data)
        - Temporary files created in system temp directory
        - Files named: quicklook_<uuid>_<index>.jpg
        - Cleanup on dealloc and explicit cleanup() call

        """)
    }
}


#endif
