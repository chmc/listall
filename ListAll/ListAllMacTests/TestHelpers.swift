//
//  TestHelpers.swift
//  ListAllMacTests
//
//  Created for ListAllMac macOS unit tests.
//

import Foundation
import CoreData
import Combine
import SwiftUI
import CloudKit
#if os(macOS)
@preconcurrency import AppKit
#endif
@testable import ListAll

// Resolve ambiguity between SwiftUI.List and ListAll.List
typealias ListModel = ListAll.List

// MARK: - Helper to prevent compiler constant-folding warnings

/// Returns the value unchanged but prevents the compiler from treating it as a compile-time constant.
/// This avoids "will never be executed" warnings in tests that verify control-flow logic with known values.
@inline(never)
func runtime<T>(_ value: T) -> T { value }

/// Test helper for setting up isolated test environments
class TestHelpers {

    /// Creates an in-memory Core Data stack for testing
    static func createInMemoryCoreDataStack() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "ListAll")

        // Configure for in-memory storage
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }

    /// Creates a test DataManager with isolated Core Data
    static func createTestDataManager() -> TestDataManager {
        let coreDataStack = createInMemoryCoreDataStack()
        let testCoreDataManager = TestCoreDataManager(container: coreDataStack)
        return TestDataManager(coreDataManager: testCoreDataManager)
    }

    /// Creates an isolated test environment for MainViewModel
    static func createTestMainViewModel() -> TestMainViewModel {
        let testDataManager = createTestDataManager()
        return TestMainViewModel(dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ItemViewModel
    static func createTestItemViewModel(with item: Item) -> TestItemViewModel {
        let testDataManager = createTestDataManager()
        return TestItemViewModel(item: item, dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ListViewModel
    static func createTestListViewModel(with list: ListModel) -> TestListViewModel {
        let testDataManager = createTestDataManager()
        return TestListViewModel(list: list, dataManager: testDataManager)
    }

    /// Creates an isolated test environment for ExportViewModel
    /// CRITICAL: Never instantiate ExportViewModel() directly in tests!
    /// Direct instantiation triggers App Groups access on unsigned builds, causing crashes.
    static func createTestExportViewModel() -> ExportViewModel {
        let testDataManager = createTestDataManager()
        let testDataRepository = TestDataRepository(dataManager: testDataManager)
        let testExportService = ExportService(dataRepository: testDataRepository)
        return ExportViewModel(exportService: testExportService)
    }

    /// Resets UserDefaults for test isolation
    static func resetUserDefaults() {
        // Clear UserDefaults keys that might affect tests
        UserDefaults.standard.removeObject(forKey: "saved_lists")

        // Clear any other UserDefaults keys used by the app
        let keys = ["showCrossedOutItems", "exportFormat", "lastSyncDate"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Unsigned Build Detection

    /// Returns true if the test build is unsigned (would trigger App Groups permission dialogs)
    /// Use this to skip tests that require signed entitlements
    static var isUnsignedTestBuild: Bool {
        // Check if code signing is valid
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-v", "--deep", Bundle.main.bundlePath]

        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus != 0
        } catch {
            // If we can't check, assume unsigned
            return true
        }
    }

    /// Skip test if running on unsigned build (would trigger permission dialog)
    /// Returns true if test should be skipped
    static func shouldSkipAppGroupsTest() -> Bool {
        if isUnsignedTestBuild {
            print("⚠️ Skipping test: unsigned build would trigger App Groups permission dialog")
            return true
        }
        return false
    }

    #if os(macOS)
    /// macOS-specific helper to create test images
    static func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: NSColor = .blue) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    /// macOS-specific helper to convert NSImage to Data
    static func imageToData(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    #endif
}
