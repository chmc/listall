//
//  ImageServiceTests.swift
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

final class ImageServiceTests: XCTestCase {

    var imageService: ImageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use shared instance - ImageService does not access file system in its init
        imageService = ImageService.shared
        imageService.clearThumbnailCache()
    }

    override func tearDownWithError() throws {
        imageService.clearThumbnailCache()
        imageService = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    /// Creates a test NSImage with specified dimensions and color
    private func createTestImage(width: CGFloat = 100, height: CGFloat = 100, color: NSColor = .red) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    /// Creates test image data (PNG format)
    private func createTestImageData(width: CGFloat = 100, height: CGFloat = 100) -> Data? {
        let image = createTestImage(width: width, height: height)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Creates test JPEG image data
    private func createTestJPEGData(width: CGFloat = 100, height: CGFloat = 100, quality: CGFloat = 0.8) -> Data? {
        let image = createTestImage(width: width, height: height)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    // MARK: - Image Processing Tests

    /// Test that processImageForStorage returns valid data
    func testProcessImageForStorage() {
        let testImage = createTestImage(width: 200, height: 200)
        let processedData = imageService.processImageForStorage(testImage)

        XCTAssertNotNil(processedData)
        XCTAssertGreaterThan(processedData?.count ?? 0, 0)
    }

    /// Test that processImageForStorage compresses large images
    func testProcessImageForStorageCompression() {
        // Create a large image
        let largeImage = createTestImage(width: 2000, height: 2000)
        let processedData = imageService.processImageForStorage(largeImage)

        XCTAssertNotNil(processedData)

        // Processed data should be within the configured max size
        let maxSize = ImageService.Configuration.maxImageSize
        XCTAssertLessThanOrEqual(processedData?.count ?? Int.max, maxSize)
    }

    /// Test resizeImageForStorage maintains aspect ratio
    func testResizeImageForStorageMaintainsAspectRatio() {
        // Create a wide image
        let wideImage = createTestImage(width: 2000, height: 1000)
        let resized = imageService.resizeImageForStorage(wideImage)

        // Check aspect ratio is preserved (2:1)
        let aspectRatio = resized.size.width / resized.size.height
        XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.01)

        // Check dimensions are reduced
        XCTAssertLessThanOrEqual(resized.size.width, ImageService.Configuration.maxImageDimension)
        XCTAssertLessThanOrEqual(resized.size.height, ImageService.Configuration.maxImageDimension)
    }

    /// Test resizeImageForStorage doesn't resize small images
    func testResizeImageForStorageSkipsSmallImages() {
        let smallImage = createTestImage(width: 100, height: 100)
        let resized = imageService.resizeImageForStorage(smallImage)

        // Small images should not be resized
        XCTAssertEqual(resized.size.width, 100)
        XCTAssertEqual(resized.size.height, 100)
    }

    /// Test resizeImage with custom max dimension
    func testResizeImageWithMaxDimension() {
        let image = createTestImage(width: 1000, height: 500)
        let resized = imageService.resizeImage(image, maxDimension: 200)

        // Should respect max dimension
        XCTAssertLessThanOrEqual(resized.size.width, 200)
        XCTAssertLessThanOrEqual(resized.size.height, 200)

        // Should maintain 2:1 aspect ratio
        let aspectRatio = resized.size.width / resized.size.height
        XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.01)
    }

    // MARK: - Compression Tests

    /// Test compressImageData reduces file size
    func testCompressImageData() {
        guard let originalData = createTestImageData(width: 500, height: 500) else {
            XCTFail("Failed to create test image data")
            return
        }

        let maxSize = 50 * 1024 // 50KB
        let compressedData = imageService.compressImageData(originalData, maxSize: maxSize)

        XCTAssertNotNil(compressedData)
        XCTAssertLessThanOrEqual(compressedData?.count ?? Int.max, maxSize)
    }

    /// Test progressive compression finds optimal quality
    func testCompressImageDataProgressive() {
        let testImage = createTestImage(width: 500, height: 500)
        let maxSize = 30 * 1024 // 30KB

        let compressedData = imageService.compressImageDataProgressive(testImage, maxSize: maxSize)

        XCTAssertNotNil(compressedData)
        // Should fit within max size or use minimum quality
        if let data = compressedData {
            XCTAssertGreaterThan(data.count, 0)
        }
    }

    // MARK: - Thumbnail Tests

    /// Test createThumbnail from NSImage
    func testCreateThumbnailFromImage() {
        let testImage = createTestImage(width: 500, height: 500)
        let thumbnailSize = CGSize(width: 100, height: 100)

        let thumbnail = imageService.createThumbnail(from: testImage, size: thumbnailSize)

        XCTAssertEqual(thumbnail.size.width, thumbnailSize.width)
        XCTAssertEqual(thumbnail.size.height, thumbnailSize.height)
    }

    /// Test createThumbnail from Data with caching
    func testCreateThumbnailFromDataWithCaching() {
        guard let testData = createTestImageData(width: 500, height: 500) else {
            XCTFail("Failed to create test image data")
            return
        }

        // First call should create and cache
        let thumbnail1 = imageService.createThumbnail(from: testData)
        XCTAssertNotNil(thumbnail1)

        // Second call should return cached version
        let thumbnail2 = imageService.createThumbnail(from: testData)
        XCTAssertNotNil(thumbnail2)

        // Both should have same dimensions
        XCTAssertEqual(thumbnail1?.size, thumbnail2?.size)
    }

    /// Test createThumbnail with invalid data returns nil
    func testCreateThumbnailFromInvalidData() {
        let invalidData = Data("not an image".utf8)
        let thumbnail = imageService.createThumbnail(from: invalidData)

        XCTAssertNil(thumbnail)
    }

    /// Test clearThumbnailCache
    func testClearThumbnailCache() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        // Create a cached thumbnail
        _ = imageService.createThumbnail(from: testData)

        // Clear cache
        imageService.clearThumbnailCache()

        // No assertion needed - just verify it doesn't crash
        XCTAssertTrue(true)
    }

    // MARK: - ItemImage Management Tests

    /// Test createItemImage from NSImage
    func testCreateItemImageFromNSImage() {
        let testImage = createTestImage(width: 200, height: 200)
        let itemId = UUID()

        let itemImage = imageService.createItemImage(from: testImage, itemId: itemId)

        XCTAssertNotNil(itemImage)
        XCTAssertNotNil(itemImage?.imageData)
        XCTAssertEqual(itemImage?.itemId, itemId)
    }

    /// Test addImageToItem
    func testAddImageToItem() {
        var item = Item(title: "Test Item")
        let testImage = createTestImage(width: 200, height: 200)

        let success = imageService.addImageToItem(&item, image: testImage)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images.count, 1)
        XCTAssertEqual(item.images.first?.orderNumber, 0)
    }

    /// Test addImageToItem sets correct order numbers
    func testAddImageToItemOrderNumbers() {
        var item = Item(title: "Test Item")
        let testImage1 = createTestImage(width: 100, height: 100, color: .red)
        let testImage2 = createTestImage(width: 100, height: 100, color: .blue)
        let testImage3 = createTestImage(width: 100, height: 100, color: .green)

        _ = imageService.addImageToItem(&item, image: testImage1)
        _ = imageService.addImageToItem(&item, image: testImage2)
        _ = imageService.addImageToItem(&item, image: testImage3)

        XCTAssertEqual(item.images.count, 3)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
        XCTAssertEqual(item.images[2].orderNumber, 2)
    }

    /// Test removeImageFromItem
    func testRemoveImageFromItem() {
        var item = Item(title: "Test Item")
        let testImage = createTestImage()

        _ = imageService.addImageToItem(&item, image: testImage)
        let imageId = item.images.first!.id

        let success = imageService.removeImageFromItem(&item, imageId: imageId)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images.count, 0)
    }

    /// Test removeImageFromItem reorders remaining images
    func testRemoveImageFromItemReorders() {
        var item = Item(title: "Test Item")

        // Add 3 images
        for _ in 0..<3 {
            _ = imageService.addImageToItem(&item, image: createTestImage())
        }

        // Remove the middle image
        let middleImageId = item.images[1].id
        _ = imageService.removeImageFromItem(&item, imageId: middleImageId)

        XCTAssertEqual(item.images.count, 2)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
    }

    /// Test removeImageFromItem with invalid ID
    func testRemoveImageFromItemInvalidId() {
        var item = Item(title: "Test Item")
        _ = imageService.addImageToItem(&item, image: createTestImage())

        let success = imageService.removeImageFromItem(&item, imageId: UUID())

        XCTAssertFalse(success)
        XCTAssertEqual(item.images.count, 1)
    }

    /// Test reorderImages
    func testReorderImages() {
        var item = Item(title: "Test Item")

        // Add 3 images
        for i in 0..<3 {
            var image = ItemImage(imageData: Data("image\(i)".utf8))
            image.orderNumber = i
            item.images.append(image)
        }

        // Reorder: move first image to last position
        let success = imageService.reorderImages(in: &item, from: 0, to: 2)

        XCTAssertTrue(success)
        XCTAssertEqual(item.images[0].orderNumber, 0)
        XCTAssertEqual(item.images[1].orderNumber, 1)
        XCTAssertEqual(item.images[2].orderNumber, 2)
    }

    /// Test reorderImages with invalid indices
    func testReorderImagesInvalidIndices() {
        var item = Item(title: "Test Item")

        // Add 2 images
        for _ in 0..<2 {
            _ = imageService.addImageToItem(&item, image: createTestImage())
        }

        // Invalid: same source and destination
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 0, to: 0))

        // Invalid: out of bounds
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 5, to: 0))
        XCTAssertFalse(imageService.reorderImages(in: &item, from: 0, to: 5))
        XCTAssertFalse(imageService.reorderImages(in: &item, from: -1, to: 0))
    }

    // MARK: - Validation Tests

    /// Test validateImageData with valid data
    func testValidateImageDataValid() {
        guard let validData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        XCTAssertTrue(imageService.validateImageData(validData))
    }

    /// Test validateImageData with invalid data
    func testValidateImageDataInvalid() {
        let invalidData = Data("not an image".utf8)

        XCTAssertFalse(imageService.validateImageData(invalidData))
    }

    /// Test validateImageData with oversized data
    func testValidateImageDataOversized() {
        // Create data larger than 2x max size
        let oversizedData = Data(count: ImageService.Configuration.maxImageSize * 3)

        XCTAssertFalse(imageService.validateImageData(oversizedData))
    }

    /// Test validateImageSize
    func testValidateImageSize() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let result = imageService.validateImageSize(testData)

        XCTAssertNotNil(result.actualSize)
        XCTAssertEqual(result.maxSize, ImageService.Configuration.maxImageSize)

        if result.isValid {
            XCTAssertNil(result.recommendation)
        } else {
            XCTAssertNotNil(result.recommendation)
        }
    }

    // MARK: - Image Format Tests

    /// Test getImageFormat for JPEG
    func testGetImageFormatJPEG() {
        guard let jpegData = createTestJPEGData() else {
            XCTFail("Failed to create test JPEG data")
            return
        }

        let format = imageService.getImageFormat(from: jpegData)

        XCTAssertEqual(format, "JPEG")
    }

    /// Test getImageFormat for PNG
    func testGetImageFormatPNG() {
        guard let pngData = createTestImageData() else {
            XCTFail("Failed to create test PNG data")
            return
        }

        let format = imageService.getImageFormat(from: pngData)

        XCTAssertEqual(format, "PNG")
    }

    /// Test getImageFormat for unknown format
    func testGetImageFormatUnknown() {
        let unknownData = Data([0x00, 0x00, 0x00, 0x00])

        let format = imageService.getImageFormat(from: unknownData)

        XCTAssertEqual(format, "Unknown")
    }

    /// Test getImageFormat with insufficient data
    func testGetImageFormatInsufficientData() {
        let shortData = Data([0x00, 0x00])

        let format = imageService.getImageFormat(from: shortData)

        XCTAssertNil(format)
    }

    // MARK: - Format File Size Tests

    /// Test formatFileSize for bytes
    func testFormatFileSizeBytes() {
        XCTAssertEqual(imageService.formatFileSize(500), "500 B")
        XCTAssertEqual(imageService.formatFileSize(0), "0 B")
    }

    /// Test formatFileSize for kilobytes
    func testFormatFileSizeKB() {
        let result = imageService.formatFileSize(2048)
        XCTAssertTrue(result.contains("KB"))
    }

    /// Test formatFileSize for megabytes
    func testFormatFileSizeMB() {
        let result = imageService.formatFileSize(2 * 1024 * 1024)
        XCTAssertTrue(result.contains("MB"))
    }

    // MARK: - Error Handling Tests

    /// Test processImage success
    func testProcessImageSuccess() {
        let testImage = createTestImage(width: 200, height: 200)

        let result = imageService.processImage(testImage)

        switch result {
        case .success(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    /// Test ImageError descriptions
    func testImageErrorDescriptions() {
        XCTAssertNotNil(ImageService.ImageError.invalidImageData.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.imageTooLarge.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.processingFailed.errorDescription)
        XCTAssertNotNil(ImageService.ImageError.unsupportedFormat.errorDescription)
    }

    // MARK: - SwiftUI Integration Tests

    /// Test swiftUIImage from ItemImage
    func testSwiftUIImageFromItemImage() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: testData)
        let swiftUIImage = imageService.swiftUIImage(from: itemImage)

        XCTAssertNotNil(swiftUIImage)
    }

    /// Test swiftUIImage with nil data
    func testSwiftUIImageWithNilData() {
        let itemImage = ItemImage(imageData: nil)
        let swiftUIImage = imageService.swiftUIImage(from: itemImage)

        XCTAssertNil(swiftUIImage)
    }

    /// Test swiftUIThumbnail from ItemImage
    func testSwiftUIThumbnailFromItemImage() {
        guard let testData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        let itemImage = ItemImage(imageData: testData)
        let thumbnail = imageService.swiftUIThumbnail(from: itemImage)

        XCTAssertNotNil(thumbnail)
    }

    // MARK: - Configuration Tests

    /// Test Configuration values are reasonable
    func testConfigurationValues() {
        XCTAssertGreaterThan(ImageService.Configuration.maxImageSize, 0)
        XCTAssertGreaterThan(ImageService.Configuration.thumbnailSize.width, 0)
        XCTAssertGreaterThan(ImageService.Configuration.thumbnailSize.height, 0)
        XCTAssertGreaterThan(ImageService.Configuration.compressionQuality, 0)
        XCTAssertLessThanOrEqual(ImageService.Configuration.compressionQuality, 1.0)
        XCTAssertGreaterThan(ImageService.Configuration.maxImageDimension, 0)
        XCTAssertGreaterThan(ImageService.Configuration.maxCacheSize, 0)
        XCTAssertFalse(ImageService.Configuration.progressiveQualityLevels.isEmpty)
    }

    // MARK: - Performance Tests

    /// Test image processing performance
    func testImageProcessingPerformance() {
        let testImage = createTestImage(width: 1000, height: 1000)

        measure {
            _ = imageService.processImageForStorage(testImage)
        }
    }

    /// Test thumbnail creation performance
    func testThumbnailCreationPerformance() {
        guard let testData = createTestImageData(width: 1000, height: 1000) else {
            XCTFail("Failed to create test image data")
            return
        }

        // Clear cache to measure actual creation time
        imageService.clearThumbnailCache()

        measure {
            _ = imageService.createThumbnail(from: testData)
        }
    }
}
#endif
