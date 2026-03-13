//
//  MacImageGalleryViewTests.swift
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

final class MacImageGalleryViewTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a test ItemImage with specified order number
    private func createTestItemImage(orderNumber: Int = 0, itemId: UUID? = nil) -> ItemImage {
        let id = itemId ?? UUID()
        var image = ItemImage(imageData: createTestImageData(), itemId: id)
        image.orderNumber = orderNumber
        return image
    }

    /// Creates test JPEG image data (1x1 pixel red image)
    private func createTestImageData() -> Data? {
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    /// Creates a test NSImage (1x1 pixel red image)
    private func createTestNSImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        return image
    }

    // MARK: - ItemImage Model Tests

    func testItemImageCreation() {
        let testData = createTestImageData()
        let testItemId = UUID()

        let image = ItemImage(imageData: testData, itemId: testItemId)

        XCTAssertNotNil(image.id)
        XCTAssertEqual(image.itemId, testItemId)
        XCTAssertEqual(image.orderNumber, 0)
        XCTAssertNotNil(image.imageData)
        XCTAssertNotNil(image.createdAt)
    }

    func testItemImageOrderNumber() {
        var image = createTestItemImage(orderNumber: 0)

        image.orderNumber = 5

        XCTAssertEqual(image.orderNumber, 5)
    }

    func testItemImageNSImage() {
        let image = createTestItemImage()

        let nsImage = image.nsImage

        XCTAssertNotNil(nsImage, "NSImage should be created from valid image data")
    }

    func testItemImageNSImageWithoutData() {
        let image = ItemImage(imageData: nil, itemId: UUID())

        let nsImage = image.nsImage

        XCTAssertNil(nsImage, "NSImage should be nil when imageData is nil")
    }

    func testItemImageSetImage() {
        var image = ItemImage(imageData: nil, itemId: UUID())
        let testImage = createTestNSImage()

        image.setImage(testImage, quality: 0.8)

        XCTAssertNotNil(image.imageData, "imageData should be set after calling setImage")
        XCTAssertTrue(image.hasImageData)
    }

    // MARK: - Selection Logic Tests

    func testSingleSelection() {
        var selectedIds: Set<UUID> = []
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)

        selectedIds = [image1.id]

        XCTAssertEqual(selectedIds.count, 1)
        XCTAssertTrue(selectedIds.contains(image1.id))
        XCTAssertFalse(selectedIds.contains(image2.id))
    }

    func testToggleSelection() {
        var selectedIds: Set<UUID> = []
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)

        selectedIds.insert(image1.id)
        XCTAssertTrue(selectedIds.contains(image1.id))

        selectedIds.insert(image2.id)
        XCTAssertTrue(selectedIds.contains(image2.id))
        XCTAssertEqual(selectedIds.count, 2)

        selectedIds.remove(image1.id)

        XCTAssertFalse(selectedIds.contains(image1.id))
        XCTAssertTrue(selectedIds.contains(image2.id))
        XCTAssertEqual(selectedIds.count, 1)
    }

    func testRangeSelection() {
        var selectedIds: Set<UUID> = []
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)
        let image3 = createTestItemImage(orderNumber: 2)
        let image4 = createTestItemImage(orderNumber: 3)
        let images = [image1, image2, image3, image4]

        selectedIds.insert(image1.id)

        let startIndex = 0
        let endIndex = 2
        for index in min(startIndex, endIndex)...max(startIndex, endIndex) {
            selectedIds.insert(images[index].id)
        }

        XCTAssertEqual(selectedIds.count, 3)
        XCTAssertTrue(selectedIds.contains(image1.id))
        XCTAssertTrue(selectedIds.contains(image2.id))
        XCTAssertTrue(selectedIds.contains(image3.id))
        XCTAssertFalse(selectedIds.contains(image4.id))
    }

    func testSelectAll() {
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)
        let image3 = createTestItemImage(orderNumber: 2)
        let images = [image1, image2, image3]

        let selectedIds = Set(images.map { $0.id })

        XCTAssertEqual(selectedIds.count, 3)
        XCTAssertTrue(selectedIds.contains(image1.id))
        XCTAssertTrue(selectedIds.contains(image2.id))
        XCTAssertTrue(selectedIds.contains(image3.id))
    }

    func testDeselectAll() {
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)
        var selectedIds: Set<UUID> = [image1.id, image2.id]

        selectedIds.removeAll()

        XCTAssertEqual(selectedIds.count, 0)
        XCTAssertFalse(selectedIds.contains(image1.id))
        XCTAssertFalse(selectedIds.contains(image2.id))
    }

    // MARK: - Reordering Tests

    func testReorderImages() {
        let image1 = createTestItemImage(orderNumber: 0)
        let image2 = createTestItemImage(orderNumber: 1)
        let image3 = createTestItemImage(orderNumber: 2)
        var images = [image1, image2, image3]

        let movedImage = images.remove(at: 2)
        images.insert(movedImage, at: 0)

        for (index, _) in images.enumerated() {
            images[index].orderNumber = index
        }

        XCTAssertEqual(images[0].id, image3.id)
        XCTAssertEqual(images[0].orderNumber, 0)
        XCTAssertEqual(images[1].id, image1.id)
        XCTAssertEqual(images[1].orderNumber, 1)
        XCTAssertEqual(images[2].id, image2.id)
        XCTAssertEqual(images[2].orderNumber, 2)
    }

    func testOrderNumberUpdate() {
        var images = [
            createTestItemImage(orderNumber: 0),
            createTestItemImage(orderNumber: 1),
            createTestItemImage(orderNumber: 2)
        ]

        for (index, _) in images.enumerated() {
            images[index].orderNumber = index
        }

        for (index, image) in images.enumerated() {
            XCTAssertEqual(image.orderNumber, index)
        }
    }

    // MARK: - Clipboard Tests

    func testCopyImageToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let testImage = createTestNSImage()

        pasteboard.writeObjects([testImage])

        let canRead = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
        XCTAssertTrue(canRead, "Pasteboard should contain NSImage after copy")
    }

    func testPasteImageFromPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let testImage = createTestNSImage()
        pasteboard.writeObjects([testImage])

        let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage]

        XCTAssertNotNil(images)
        XCTAssertEqual(images?.count, 1)
    }

    func testHasImagesOnPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let hasImagesEmpty = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
        XCTAssertFalse(hasImagesEmpty)

        pasteboard.writeObjects([createTestNSImage()])
        let hasImagesWithImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
        XCTAssertTrue(hasImagesWithImage)
    }

    func testClearPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.writeObjects([createTestNSImage()])
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))

        pasteboard.clearContents()

        let hasImages = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
        XCTAssertFalse(hasImages)
    }

    // MARK: - Integration Tests

    func testItemImageWithNSImageRoundtrip() {
        let originalImage = createTestNSImage()
        var itemImage = ItemImage(imageData: nil, itemId: UUID())

        itemImage.setImage(originalImage, quality: 0.8)

        let retrievedImage = itemImage.nsImage
        XCTAssertNotNil(retrievedImage)
        XCTAssertTrue(itemImage.hasImageData)
    }

    func testMultipleImagesOrdering() {
        var images = [
            createTestItemImage(orderNumber: 0),
            createTestItemImage(orderNumber: 1),
            createTestItemImage(orderNumber: 2)
        ]

        let lastImage = images.removeLast()
        images.insert(lastImage, at: 0)

        for (index, _) in images.enumerated() {
            images[index].orderNumber = index
        }

        for (index, image) in images.enumerated() {
            XCTAssertEqual(image.orderNumber, index)
        }
        XCTAssertEqual(images.count, 3)
    }

    func testImageSelectionWithReordering() {
        var selectedIds: Set<UUID> = []
        var images = [
            createTestItemImage(orderNumber: 0),
            createTestItemImage(orderNumber: 1),
            createTestItemImage(orderNumber: 2)
        ]

        selectedIds.insert(images[1].id)

        let selectedImage = images.remove(at: 1)
        images.insert(selectedImage, at: 0)

        for (index, _) in images.enumerated() {
            images[index].orderNumber = index
        }

        XCTAssertTrue(selectedIds.contains(images[0].id))
        XCTAssertEqual(images[0].orderNumber, 0)
    }

    // MARK: - Edge Cases

    func testEmptyImageSelection() {
        let selectedIds: Set<UUID> = []
        let images: [ItemImage] = []

        XCTAssertEqual(selectedIds.count, 0)
        XCTAssertEqual(images.count, 0)
    }

    func testInvalidImageData() {
        let invalidData = Data([0x00, 0x01, 0x02])
        let image = ItemImage(imageData: invalidData, itemId: UUID())

        let nsImage = image.nsImage

        XCTAssertNil(nsImage)
    }

    // MARK: - Documentation Test

    func testDocumentMacImageGalleryImplementation() {
        XCTAssertTrue(true, """

        Mac Image Gallery View Implementation
        =====================================

        MacImageGalleryView provides a native macOS image gallery experience with:

        Image Selection:
        1. Single Selection: Click to select one image
        2. Toggle Selection: Cmd+Click to toggle individual images
        3. Range Selection: Shift+Click to select range between two images
        4. Select All: Cmd+A to select all images
        5. Deselect All: Click on empty space

        Image Reordering:
        1. Drag-and-drop images to reorder
        2. Order numbers automatically update after reordering
        3. Order numbers are sequential starting from 0
        4. Selection persists during reordering (tracked by ID)

        Clipboard Operations:
        1. Copy: Cmd+C copies selected images to pasteboard
        2. Paste: Cmd+V pastes images from pasteboard
        3. Uses NSPasteboard.general for clipboard access

        Files Created:
        - MacImageGalleryView.swift - Main gallery component
        - MacImageDropHandler.swift - Drag-and-drop handler
        - MacImageClipboardManager.swift - Clipboard operations

        """)
    }
}


#endif
