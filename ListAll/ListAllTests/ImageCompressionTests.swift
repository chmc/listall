import XCTest
@testable import ListAll

class ImageCompressionTests: XCTestCase {
    
    var imageService: ImageService!
    
    override func setUp() {
        super.setUp()
        imageService = ImageService.shared
    }
    
    override func tearDown() {
        imageService = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testImageServiceConfiguration() {
        // Test that configuration values are set to industry standards
        XCTAssertEqual(ImageService.Configuration.maxImageSize, 512 * 1024) // 512KB
        XCTAssertEqual(ImageService.Configuration.thumbnailSize.width, 150)
        XCTAssertEqual(ImageService.Configuration.thumbnailSize.height, 150)
        XCTAssertEqual(ImageService.Configuration.compressionQuality, 0.75)
        XCTAssertEqual(ImageService.Configuration.maxImageDimension, 1200)
        XCTAssertEqual(ImageService.Configuration.maxCacheSize, 50)
    }
    
    // MARK: - Image Processing Tests
    
    func testProcessImageForStorage() {
        // Create a test image
        let testImage = createTestImage(size: CGSize(width: 2000, height: 1500))
        
        // Process the image
        let processedData = imageService.processImageForStorage(testImage)
        
        // Verify data is not nil
        XCTAssertNotNil(processedData)
        
        // Verify data is smaller than original
        if let data = processedData {
            XCTAssertLessThan(data.count, 512 * 1024) // Should be under 512KB
        }
    }
    
    func testResizeImageForStorage() {
        // Create a large test image
        let largeImage = createTestImage(size: CGSize(width: 3000, height: 2000))
        
        // Resize the image
        let resizedImage = imageService.resizeImageForStorage(largeImage)
        
        // Verify dimensions are within limits
        XCTAssertLessThanOrEqual(resizedImage.size.width, 1200)
        XCTAssertLessThanOrEqual(resizedImage.size.height, 1200)
    }
    
    func testProgressiveCompression() {
        // Create a test image
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // Test progressive compression with 512KB target
        let compressedData = imageService.compressImageDataProgressive(testImage, maxSize: 512 * 1024)
        
        // Verify data is not nil and reasonably sized
        XCTAssertNotNil(compressedData, "Compressed data should not be nil")
        if let data = compressedData {
            XCTAssertGreaterThan(data.count, 0, "Compressed data should have content")
            XCTAssertLessThanOrEqual(data.count, 512 * 1024, "Compressed data should be under 512KB")
        }
    }
    
    // MARK: - Thumbnail Tests
    
    func testCreateOptimizedThumbnail() {
        // Create a test image
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // Create optimized thumbnail
        let thumbnail = imageService.createOptimizedThumbnail(from: testImage)
        
        // Verify thumbnail is not nil
        XCTAssertNotNil(thumbnail)
        
        // Verify thumbnail size
        if let thumb = thumbnail {
            XCTAssertEqual(thumb.size.width, 150)
            XCTAssertEqual(thumb.size.height, 150)
        }
    }
    
    func testThumbnailCaching() {
        // Create a test image
        let testImage = createTestImage(size: CGSize(width: 500, height: 500))
        let testData = testImage.jpegData(compressionQuality: 0.8)!
        
        // Create thumbnail twice
        let thumbnail1 = imageService.createThumbnail(from: testData)
        let thumbnail2 = imageService.createThumbnail(from: testData)
        
        // Both should be the same (cached)
        XCTAssertNotNil(thumbnail1)
        XCTAssertNotNil(thumbnail2)
        XCTAssertEqual(thumbnail1?.size, thumbnail2?.size)
    }
    
    // MARK: - Validation Tests
    
    func testValidateImageData() {
        // Create valid test data
        let testImage = createTestImage(size: CGSize(width: 500, height: 500))
        let validData = testImage.jpegData(compressionQuality: 0.8)!
        
        // Test validation
        XCTAssertTrue(imageService.validateImageData(validData))
        
        // Test with invalid data
        let invalidData = Data([0, 1, 2, 3])
        XCTAssertFalse(imageService.validateImageData(invalidData))
    }
    
    func testValidateImageSize() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 500, height: 500))
        let testData = testImage.jpegData(compressionQuality: 0.8)!
        
        // Test size validation
        let validation = imageService.validateImageSize(testData)
        
        // Should be valid for small image
        XCTAssertTrue(validation.isValid)
        XCTAssertNotNil(validation.actualSize)
        XCTAssertNotNil(validation.maxSize)
    }
    
    func testValidateImageDimensions() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 500, height: 500))
        
        // Test dimension validation
        let validation = imageService.validateImageDimensions(testImage)
        
        // Should be valid for small image
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.actualSize, CGSize(width: 500, height: 500))
    }
    
    func testComprehensiveImageValidation() {
        // Create valid test image
        let validImage = createTestImage(size: CGSize(width: 500, height: 500))
        let validValidation = imageService.validateImage(validImage)
        
        XCTAssertTrue(validValidation.isValid)
        XCTAssertTrue(validValidation.issues.isEmpty)
        
        // Create invalid test image (too large)
        let invalidImage = createTestImage(size: CGSize(width: 3000, height: 2000))
        let invalidValidation = imageService.validateImage(invalidImage)
        
        XCTAssertFalse(invalidValidation.isValid)
        XCTAssertFalse(invalidValidation.issues.isEmpty)
        XCTAssertFalse(invalidValidation.recommendations.isEmpty)
    }
    
    // MARK: - Compression Statistics Tests
    
    func testGetCompressionStats() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // Get compression stats
        let stats = imageService.getCompressionStats(for: testImage)
        
        // Verify stats are reasonable
        XCTAssertGreaterThan(stats.originalSize, 0)
        XCTAssertGreaterThan(stats.compressedSize, 0)
        XCTAssertLessThan(stats.compressionRatio, 1.0) // Should be compressed
        XCTAssertGreaterThan(stats.savings, 0) // Should have savings
    }
    
    // MARK: - ItemImage Tests
    
    func testItemImageCompression() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // Create ItemImage
        var itemImage = ItemImage()
        itemImage.setImage(testImage)
        
        // Verify image was compressed
        XCTAssertTrue(itemImage.hasImageData)
        XCTAssertLessThan(itemImage.imageSize, 512 * 1024) // Should be under 512KB
    }
    
    func testItemImageCompressImage() {
        // Create test image
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // Create ItemImage with large data
        var itemImage = ItemImage()
        if let largeData = testImage.jpegData(compressionQuality: 1.0) {
            itemImage.imageData = largeData
        }
        
        let originalSize = itemImage.imageSize
        XCTAssertGreaterThan(originalSize, 0, "Original image should have data")
        
        // Compress the image to 512KB (default)
        itemImage.compressImage(maxSize: 512 * 1024)
        
        let compressedSize = itemImage.imageSize
        
        // Verify compression worked - compressed size should be smaller
        XCTAssertGreaterThan(compressedSize, 0, "Compressed image should have data")
        XCTAssertLessThanOrEqual(compressedSize, originalSize, "Compressed size should not exceed original")
        XCTAssertLessThanOrEqual(compressedSize, 512 * 1024, "Compressed size should be under 512KB")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a simple test pattern
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            
            context.cgContext.setFillColor(UIColor.blue.cgColor)
            context.cgContext.fill(CGRect(x: size.width/4, y: size.height/4, 
                                        width: size.width/2, height: size.height/2))
        }
    }
}
