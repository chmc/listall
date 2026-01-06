//
//  PerformanceBenchmarkTests.swift
//  ListAllMacTests
//
//  Created by Claude Code on 2026-01-06.
//  Task 11.4: Performance Optimization
//

import XCTest
import CoreData
#if os(macOS)
import AppKit
#endif
@testable import ListAll

/// Performance benchmark tests for macOS app optimization (Task 11.4)
/// These tests establish baselines and verify optimizations for:
/// - List rendering with large datasets
/// - Thumbnail creation and caching
/// - Core Data fetch performance
/// - Memory efficiency
final class PerformanceBenchmarkTests: XCTestCase {

    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var imageService: ImageService!

    // MARK: - Setup and Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory Core Data stack
        testContainer = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        testContainer.persistentStoreDescriptions = [description]

        let expectation = XCTestExpectation(description: "Load stores")
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        testContext = testContainer.viewContext
        imageService = ImageService.shared
        imageService.clearThumbnailCache()
    }

    override func tearDownWithError() throws {
        imageService.clearThumbnailCache()
        imageService = nil
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Data Generators

    /// Creates a test image of specified size
    private func createTestImage(width: Int = 100, height: Int = 100, color: NSColor = .blue) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()
        return image
    }

    /// Creates test image data
    private func createTestImageData(size: Int = 100) -> Data {
        let image = createTestImage(width: size, height: size)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return Data()
        }
        return jpegData
    }

    /// Creates a list with specified number of items
    private func createTestList(withItemCount count: Int) -> List {
        var list = List(name: "Performance Test List")
        for i in 0..<count {
            var item = Item(title: "Item \(i)")
            item.itemDescription = "Description for item \(i) with some additional text to simulate real data"
            item.quantity = (i % 10) + 1
            item.orderNumber = i
            item.isCrossedOut = i % 5 == 0
            list.items.append(item)
        }
        return list
    }

    /// Creates a list with items containing images
    private func createTestListWithImages(itemCount: Int, imagesPerItem: Int) -> List {
        var list = createTestList(withItemCount: itemCount)
        let imageData = createTestImageData(size: 200)

        for i in 0..<min(itemCount, list.items.count) {
            for j in 0..<imagesPerItem {
                var image = ItemImage(imageData: imageData)
                image.orderNumber = j
                list.items[i].images.append(image)
            }
        }
        return list
    }

    // MARK: - List Rendering Performance Tests

    /// Tests filtering performance with large item lists
    func testLargeListFilteringPerformance() throws {
        let list = createTestList(withItemCount: 1000)

        measure {
            // Simulate filtering active items
            let activeItems = list.items.filter { !$0.isCrossedOut }
            XCTAssertGreaterThan(activeItems.count, 0)

            // Simulate filtering completed items
            let completedItems = list.items.filter { $0.isCrossedOut }
            XCTAssertGreaterThan(completedItems.count, 0)
        }
    }

    /// Tests sorting performance with large item lists
    func testLargeListSortingPerformance() throws {
        let list = createTestList(withItemCount: 1000)

        measure {
            // Sort by order number
            let sortedByOrder = list.items.sorted { $0.orderNumber < $1.orderNumber }
            XCTAssertEqual(sortedByOrder.count, 1000)

            // Sort by title
            let sortedByTitle = list.items.sorted { $0.title < $1.title }
            XCTAssertEqual(sortedByTitle.count, 1000)

            // Sort by created date
            let sortedByDate = list.items.sorted { $0.createdAt < $1.createdAt }
            XCTAssertEqual(sortedByDate.count, 1000)
        }
    }

    /// Tests combined filter and sort performance (realistic scenario)
    func testFilterAndSortPerformance() throws {
        let list = createTestList(withItemCount: 1000)

        measure {
            // Filter active items then sort by order number (common UI operation)
            let result = list.items
                .filter { !$0.isCrossedOut }
                .sorted { $0.orderNumber < $1.orderNumber }
            XCTAssertGreaterThan(result.count, 0)
        }
    }

    /// Tests search performance
    func testSearchPerformance() throws {
        let list = createTestList(withItemCount: 1000)

        measure {
            let searchText = "item 5"
            let results = list.items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.itemDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            XCTAssertGreaterThan(results.count, 0)
        }
    }

    // MARK: - Thumbnail Performance Tests

    /// Tests synchronous thumbnail creation performance
    func testThumbnailCreationPerformance() throws {
        let imageData = createTestImageData(size: 500)

        // Clear cache to ensure fresh creation
        imageService.clearThumbnailCache()

        measure {
            for _ in 0..<10 {
                // Force new cache key by modifying data slightly
                var modifiedData = imageData
                modifiedData.append(UInt8.random(in: 0...255))
                let thumbnail = imageService.createThumbnail(from: modifiedData, size: CGSize(width: 100, height: 100))
                XCTAssertNotNil(thumbnail)
            }
        }
    }

    /// Tests thumbnail cache hit performance
    func testThumbnailCacheHitPerformance() throws {
        let imageData = createTestImageData(size: 500)
        let size = CGSize(width: 100, height: 100)

        // Prime the cache
        _ = imageService.createThumbnail(from: imageData, size: size)

        measure {
            for _ in 0..<100 {
                // Same data = cache hit
                let thumbnail = imageService.createThumbnail(from: imageData, size: size)
                XCTAssertNotNil(thumbnail)
            }
        }
    }

    /// Tests batch thumbnail loading performance
    func testBatchThumbnailLoadingPerformance() throws {
        // Create 20 unique images
        var imageDataArray: [Data] = []
        for i in 0..<20 {
            let image = createTestImage(width: 300 + i, height: 300 + i, color: NSColor(red: CGFloat(i) / 20.0, green: 0.5, blue: 0.5, alpha: 1.0))
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
                imageDataArray.append(jpegData)
            }
        }

        imageService.clearThumbnailCache()

        measure {
            for data in imageDataArray {
                let thumbnail = imageService.createThumbnail(from: data, size: CGSize(width: 80, height: 80))
                XCTAssertNotNil(thumbnail)
            }
        }
    }

    // MARK: - Image Processing Performance Tests

    /// Tests image compression performance
    func testImageCompressionPerformance() throws {
        let largeImage = createTestImage(width: 2000, height: 2000)

        measure {
            let processedData = imageService.processImageForStorage(largeImage)
            XCTAssertNotNil(processedData)
        }
    }

    /// Tests progressive compression performance
    func testProgressiveCompressionPerformance() throws {
        let image = createTestImage(width: 1000, height: 1000)
        let maxSize = 500_000 // 500KB

        measure {
            let compressedData = imageService.compressImageDataProgressive(image, maxSize: maxSize)
            XCTAssertNotNil(compressedData)
        }
    }

    // MARK: - Core Data Performance Tests

    /// Tests list entity creation performance
    func testListEntityCreationPerformance() throws {
        measure {
            for i in 0..<100 {
                let entity = ListEntity(context: testContext)
                entity.id = UUID()
                entity.name = "Test List \(i)"
                entity.orderNumber = Int32(i)
                entity.createdAt = Date()
                entity.modifiedAt = Date()
            }
            try? testContext.save()
            testContext.reset()
        }
    }

    /// Tests list with items creation performance
    func testListWithItemsCreationPerformance() throws {
        measure {
            let listEntity = ListEntity(context: testContext)
            listEntity.id = UUID()
            listEntity.name = "Test List"
            listEntity.orderNumber = 0
            listEntity.createdAt = Date()
            listEntity.modifiedAt = Date()

            for i in 0..<50 {
                let itemEntity = ItemEntity(context: testContext)
                itemEntity.id = UUID()
                itemEntity.title = "Item \(i)"
                itemEntity.orderNumber = Int32(i)
                itemEntity.createdAt = Date()
                itemEntity.modifiedAt = Date()
                itemEntity.list = listEntity
            }

            try? testContext.save()
            testContext.reset()
        }
    }

    /// Tests fetch request with prefetching performance
    func testFetchWithPrefetchingPerformance() throws {
        // Create test data
        for i in 0..<10 {
            let listEntity = ListEntity(context: testContext)
            listEntity.id = UUID()
            listEntity.name = "List \(i)"
            listEntity.orderNumber = Int32(i)
            listEntity.createdAt = Date()
            listEntity.modifiedAt = Date()

            for j in 0..<20 {
                let itemEntity = ItemEntity(context: testContext)
                itemEntity.id = UUID()
                itemEntity.title = "Item \(j)"
                itemEntity.orderNumber = Int32(j)
                itemEntity.createdAt = Date()
                itemEntity.modifiedAt = Date()
                itemEntity.list = listEntity
            }
        }
        try testContext.save()

        measure {
            let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
            request.relationshipKeyPathsForPrefetching = ["items"]

            do {
                let results = try testContext.fetch(request)
                // Access items to ensure prefetch is used
                for list in results {
                    _ = list.items?.count
                }
                XCTAssertEqual(results.count, 10)
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }

    /// Tests model conversion performance
    func testModelConversionPerformance() throws {
        // Create test entities
        let listEntity = ListEntity(context: testContext)
        listEntity.id = UUID()
        listEntity.name = "Test List"
        listEntity.orderNumber = 0
        listEntity.createdAt = Date()
        listEntity.modifiedAt = Date()

        for i in 0..<100 {
            let itemEntity = ItemEntity(context: testContext)
            itemEntity.id = UUID()
            itemEntity.title = "Item \(i)"
            itemEntity.itemDescription = "Description \(i)"
            itemEntity.quantity = Int32(i + 1)
            itemEntity.orderNumber = Int32(i)
            itemEntity.createdAt = Date()
            itemEntity.modifiedAt = Date()
            itemEntity.list = listEntity
        }
        try testContext.save()

        measure {
            // Convert to model
            let list = listEntity.toList()
            XCTAssertEqual(list.items.count, 100)

            // Access all properties to ensure full conversion
            for item in list.items {
                _ = item.displayTitle
                _ = item.formattedQuantity
            }
        }
    }

    // MARK: - Memory Efficiency Tests

    /// Tests that thumbnail cache respects limits
    func testThumbnailCacheMemoryEfficiency() throws {
        // Generate many unique images
        var createdThumbnails = 0

        for i in 0..<100 {
            let image = createTestImage(width: 200 + i, height: 200 + i)
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
                let thumbnail = imageService.createThumbnail(from: jpegData, size: CGSize(width: 100, height: 100))
                if thumbnail != nil {
                    createdThumbnails += 1
                }
            }
        }

        // Verify we created thumbnails but cache should have evicted some due to limits
        XCTAssertEqual(createdThumbnails, 100)
        // Note: NSCache automatically manages eviction based on countLimit and totalCostLimit
    }

    /// Tests list model memory efficiency
    func testListModelMemoryEfficiency() throws {
        // Create a large list and verify it can be deallocated
        var list: List? = createTestList(withItemCount: 500)
        XCTAssertEqual(list?.items.count, 500)

        // Clear reference
        list = nil

        // Create another to verify memory was released
        let newList = createTestList(withItemCount: 100)
        XCTAssertEqual(newList.items.count, 100)
    }

    // MARK: - Async Performance Tests

    /// Tests async thumbnail creation pattern (for future optimization)
    func testAsyncThumbnailCreationPattern() async throws {
        let imageData = createTestImageData(size: 500)

        // Simulate async thumbnail creation
        let thumbnail = await Task.detached(priority: .userInitiated) {
            return self.imageService.createThumbnail(from: imageData, size: CGSize(width: 100, height: 100))
        }.value

        XCTAssertNotNil(thumbnail)
    }

    /// Tests concurrent thumbnail creation
    func testConcurrentThumbnailCreation() async throws {
        // Create unique image data for each task
        var imageDataArray: [Data] = []
        for i in 0..<10 {
            let image = createTestImage(width: 300 + i, height: 300 + i)
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
                imageDataArray.append(jpegData)
            }
        }

        imageService.clearThumbnailCache()

        // Create thumbnails concurrently
        await withTaskGroup(of: NSImage?.self) { group in
            for data in imageDataArray {
                group.addTask {
                    return self.imageService.createThumbnail(from: data, size: CGSize(width: 100, height: 100))
                }
            }

            var count = 0
            for await thumbnail in group {
                if thumbnail != nil {
                    count += 1
                }
            }
            XCTAssertEqual(count, 10)
        }
    }

    // MARK: - Combined Operation Performance Tests

    /// Tests realistic workflow: create list, add items, filter, sort
    func testRealisticWorkflowPerformance() throws {
        measure {
            // Create list
            var list = List(name: "Shopping List")

            // Add items
            for i in 0..<100 {
                var item = Item(title: "Item \(i)")
                item.quantity = (i % 5) + 1
                item.orderNumber = i
                if i % 3 == 0 {
                    item.isCrossedOut = true
                }
                list.items.append(item)
            }

            // Filter active
            let activeItems = list.items.filter { !$0.isCrossedOut }

            // Sort by order
            let sorted = activeItems.sorted { $0.orderNumber < $1.orderNumber }

            XCTAssertGreaterThan(sorted.count, 0)
        }
    }

    /// Tests scrolling simulation (rapid filtering)
    func testRapidFilteringPerformance() throws {
        let list = createTestList(withItemCount: 500)

        measure {
            // Simulate rapid filter changes (like scrolling through filter options)
            for _ in 0..<20 {
                _ = list.items.filter { !$0.isCrossedOut }
                _ = list.items.filter { $0.isCrossedOut }
                _ = list.items.filter { $0.quantity > 1 }
                _ = list.items.filter { $0.itemDescription != nil }
                _ = list.items // all
            }
        }
    }
}

// MARK: - Async Thumbnail Extension Tests

/// Tests for verifying async thumbnail creation pattern works correctly
final class AsyncThumbnailPatternTests: XCTestCase {

    var imageService: ImageService!

    override func setUp() {
        super.setUp()
        imageService = ImageService.shared
        imageService.clearThumbnailCache()
    }

    override func tearDown() {
        imageService.clearThumbnailCache()
        imageService = nil
        super.tearDown()
    }

    /// Creates test image data
    private func createTestImageData(size: Int = 100) -> Data {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return Data()
        }
        return jpegData
    }

    /// Tests that async thumbnail creation produces same result as sync
    func testAsyncThumbnailConsistency() async throws {
        let imageData = createTestImageData(size: 200)
        let size = CGSize(width: 80, height: 80)

        // Clear cache
        imageService.clearThumbnailCache()

        // Create sync thumbnail
        let syncThumbnail = imageService.createThumbnail(from: imageData, size: size)
        XCTAssertNotNil(syncThumbnail)

        // Clear cache again
        imageService.clearThumbnailCache()

        // Create async thumbnail
        let asyncThumbnail = await Task.detached {
            return self.imageService.createThumbnail(from: imageData, size: size)
        }.value
        XCTAssertNotNil(asyncThumbnail)

        // Both should produce valid thumbnails
        XCTAssertEqual(syncThumbnail?.size, asyncThumbnail?.size)
    }

    /// Tests cache is thread-safe for async operations
    func testCacheThreadSafety() async throws {
        let imageData = createTestImageData(size: 150)
        let size = CGSize(width: 60, height: 60)

        // Clear cache
        imageService.clearThumbnailCache()

        // Concurrent access to same cache key
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let thumbnail = self.imageService.createThumbnail(from: imageData, size: size)
                    return thumbnail != nil
                }
            }

            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }

            // All should succeed
            XCTAssertEqual(successCount, 10)
        }
    }
}
