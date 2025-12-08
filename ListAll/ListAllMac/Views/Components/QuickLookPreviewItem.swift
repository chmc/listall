//
//  QuickLookPreviewItem.swift
//  ListAllMac
//
//  Quick Look preview item that wraps ItemImage data for QLPreviewPanel.
//  Handles both in-memory images and temporary file-based previews.
//

import Foundation
import AppKit
import Quartz

/// A preview item that wraps ItemImage data for Quick Look preview.
/// Implements QLPreviewItem protocol for use with QLPreviewPanel.
final class QuickLookPreviewItem: NSObject, QLPreviewItem {

    // MARK: - Properties

    /// The item image being previewed
    let itemImage: ItemImage

    /// The display title for the preview
    let displayTitle: String

    /// The index in the collection (for multi-image preview)
    let index: Int

    /// Temporary file URL for the image (created lazily)
    private var _previewItemURL: URL?

    // MARK: - Initialization

    init(itemImage: ItemImage, displayTitle: String, index: Int = 0) {
        self.itemImage = itemImage
        self.displayTitle = displayTitle
        self.index = index
        super.init()
    }

    // MARK: - QLPreviewItem Protocol

    /// The URL to the preview item.
    /// Quick Look requires a file URL, so we write the image data to a temporary file.
    var previewItemURL: URL? {
        if let url = _previewItemURL {
            return url
        }

        guard let imageData = itemImage.imageData else {
            return nil
        }

        // Create temporary file with appropriate extension
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "quicklook_\(itemImage.id.uuidString)_\(index).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            // Write image data to temporary file
            try imageData.write(to: fileURL)
            _previewItemURL = fileURL
            return fileURL
        } catch {
            print("⚠️ QuickLookPreviewItem: Failed to write temporary file: \(error)")
            return nil
        }
    }

    /// The display title for the preview item
    var previewItemTitle: String? {
        if displayTitle.isEmpty {
            return "Image \(index + 1)"
        }
        return "\(displayTitle) - Image \(index + 1)"
    }

    // MARK: - Cleanup

    /// Remove the temporary file when the preview item is deallocated
    deinit {
        cleanupTemporaryFile()
    }

    /// Explicitly clean up the temporary file
    func cleanupTemporaryFile() {
        guard let url = _previewItemURL else { return }

        do {
            try FileManager.default.removeItem(at: url)
            _previewItemURL = nil
        } catch {
            // Ignore cleanup errors - system will clean temp directory eventually
        }
    }
}

// MARK: - QuickLookPreviewCollection

/// Manages a collection of preview items for multi-image Quick Look preview.
/// Implements both QLPreviewPanelDataSource and QLPreviewPanelDelegate.
final class QuickLookPreviewCollection: NSObject {

    // MARK: - Properties

    /// The preview items in this collection
    private(set) var previewItems: [QuickLookPreviewItem] = []

    /// The current preview index
    var currentIndex: Int = 0

    /// Callback when preview panel closes
    var onClose: (() -> Void)?

    // MARK: - Initialization

    /// Creates a collection from an Item's images
    convenience init(item: Item) {
        self.init()

        self.previewItems = item.sortedImages.enumerated().compactMap { index, itemImage in
            guard itemImage.hasImageData else { return nil }
            return QuickLookPreviewItem(
                itemImage: itemImage,
                displayTitle: item.displayTitle,
                index: index
            )
        }
    }

    /// Creates a collection from a single ItemImage
    convenience init(itemImage: ItemImage, title: String = "") {
        self.init()

        if itemImage.hasImageData {
            self.previewItems = [
                QuickLookPreviewItem(itemImage: itemImage, displayTitle: title, index: 0)
            ]
        }
    }

    // MARK: - Public Methods

    /// Returns true if there are items to preview
    var hasPreviewItems: Bool {
        return !previewItems.isEmpty
    }

    /// Number of preview items
    var count: Int {
        return previewItems.count
    }

    /// Clean up all temporary files
    func cleanup() {
        previewItems.forEach { $0.cleanupTemporaryFile() }
    }
}

// MARK: - QLPreviewPanelDataSource

extension QuickLookPreviewCollection: QLPreviewPanelDataSource {

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0 && index < previewItems.count else {
            return nil
        }
        return previewItems[index]
    }
}

// MARK: - QLPreviewPanelDelegate

extension QuickLookPreviewCollection: QLPreviewPanelDelegate {

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard navigation within Quick Look
        if event.type == .keyDown {
            switch event.keyCode {
            case 123: // Left arrow
                if panel.currentPreviewItemIndex > 0 {
                    panel.currentPreviewItemIndex -= 1
                    return true
                }
            case 124: // Right arrow
                if panel.currentPreviewItemIndex < previewItems.count - 1 {
                    panel.currentPreviewItemIndex += 1
                    return true
                }
            default:
                break
            }
        }
        return false
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Return zero rect to use default animation
        return .zero
    }
}

// MARK: - QuickLookController

/// Singleton controller for managing Quick Look preview panel.
/// Handles panel presentation and coordinates with the active window.
final class QuickLookController: NSObject {

    // MARK: - Singleton

    static let shared = QuickLookController()

    // MARK: - Properties

    /// The current preview collection being displayed
    private var currentCollection: QuickLookPreviewCollection?

    /// Whether the panel is currently visible
    var isPanelVisible: Bool {
        return QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Show Quick Look preview for an item's images
    /// - Parameters:
    ///   - item: The item whose images to preview
    ///   - startIndex: The index of the image to start with (default 0)
    func preview(item: Item, startIndex: Int = 0) {
        let collection = QuickLookPreviewCollection(item: item)
        guard collection.hasPreviewItems else {
            print("⚠️ QuickLookController: No images to preview for item '\(item.displayTitle)'")
            return
        }

        showPreview(collection: collection, startIndex: startIndex)
    }

    /// Show Quick Look preview for a single image
    /// - Parameters:
    ///   - itemImage: The image to preview
    ///   - title: Optional title for the preview
    func preview(itemImage: ItemImage, title: String = "") {
        let collection = QuickLookPreviewCollection(itemImage: itemImage, title: title)
        guard collection.hasPreviewItems else {
            print("⚠️ QuickLookController: No image data to preview")
            return
        }

        showPreview(collection: collection, startIndex: 0)
    }

    /// Toggle Quick Look panel visibility
    /// - Parameters:
    ///   - item: The item to preview if showing
    ///   - startIndex: The index of the image to start with
    func togglePreview(item: Item, startIndex: Int = 0) {
        if isPanelVisible {
            hidePreview()
        } else {
            preview(item: item, startIndex: startIndex)
        }
    }

    /// Hide the Quick Look panel
    func hidePreview() {
        guard QLPreviewPanel.sharedPreviewPanelExists() else { return }

        QLPreviewPanel.shared().orderOut(nil)
        cleanupCurrentCollection()
    }

    // MARK: - Private Methods

    private func showPreview(collection: QuickLookPreviewCollection, startIndex: Int) {
        // Clean up any existing collection
        cleanupCurrentCollection()

        // Store the new collection
        currentCollection = collection

        // Get or create the preview panel
        guard let panel = QLPreviewPanel.shared() else {
            print("⚠️ QuickLookController: Failed to get QLPreviewPanel")
            return
        }

        // Set data source and delegate
        panel.dataSource = collection
        panel.delegate = collection

        // Set the starting index
        if startIndex > 0 && startIndex < collection.count {
            panel.currentPreviewItemIndex = startIndex
        }

        // Show the panel
        panel.makeKeyAndOrderFront(nil)

        print("📷 QuickLookController: Showing preview with \(collection.count) images")
    }

    private func cleanupCurrentCollection() {
        currentCollection?.cleanup()
        currentCollection = nil
    }
}

// MARK: - Notification for Quick Look

extension Notification.Name {
    /// Posted when Quick Look preview should be shown for an item
    static let showQuickLookPreview = Notification.Name("ShowQuickLookPreview")

    /// Posted when Quick Look preview should be hidden
    static let hideQuickLookPreview = Notification.Name("HideQuickLookPreview")
}
