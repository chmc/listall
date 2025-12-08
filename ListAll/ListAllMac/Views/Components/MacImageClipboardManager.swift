//
//  MacImageClipboardManager.swift
//  ListAllMac
//
//  Manages clipboard operations for images in the macOS app.
//  Handles copying and pasting images via NSPasteboard.
//

import AppKit

/// Manager for clipboard operations involving images on macOS
/// Handles copying and pasting images via NSPasteboard
class MacImageClipboardManager {

    // MARK: - Singleton

    static let shared = MacImageClipboardManager()

    // MARK: - Properties

    private let pasteboard = NSPasteboard.general

    // MARK: - Initialization

    private init() {}

    // MARK: - Copy Operations

    /// Copies multiple ItemImage objects to the pasteboard
    /// - Parameter images: Array of ItemImage objects to copy
    /// - Returns: True if at least one image was successfully copied
    @discardableResult
    func copyImages(_ images: [ItemImage]) -> Bool {
        guard !images.isEmpty else { return false }

        // Convert ItemImage objects to NSImage objects
        let nsImages = images.compactMap { $0.nsImage }

        guard !nsImages.isEmpty else {
            print("[MacImageClipboardManager] No valid images to copy")
            return false
        }

        return writeImagesToPasteboard(nsImages)
    }

    /// Copies a single NSImage to the pasteboard
    /// - Parameter image: NSImage to copy
    /// - Returns: True if image was successfully copied
    @discardableResult
    func copyImage(_ image: NSImage) -> Bool {
        return writeImagesToPasteboard([image])
    }

    /// Copies image data directly to the pasteboard
    /// - Parameters:
    ///   - data: Image data to copy
    ///   - type: Pasteboard type (e.g., .png, .tiff)
    /// - Returns: True if successfully copied
    @discardableResult
    func copyImageData(_ data: Data, type: NSPasteboard.PasteboardType) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: type)
    }

    // MARK: - Paste Operations

    /// Pastes images from the pasteboard
    /// - Returns: Array of NSImage objects from pasteboard, empty if none available
    func pasteImages() -> [NSImage] {
        // Try to read NSImage objects directly
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            return images
        }

        // Fallback: Try to read from different data types
        var images: [NSImage] = []

        // Check for TIFF data
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            images.append(image)
        }

        // Check for PNG data
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            images.append(image)
        }

        // Check for file URLs (dragged image files)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if isImageFile(url), let image = NSImage(contentsOf: url) {
                    images.append(image)
                }
            }
        }

        return images
    }

    /// Pastes a single image from the pasteboard
    /// - Returns: First available NSImage, or nil if none
    func pasteImage() -> NSImage? {
        return pasteImages().first
    }

    // MARK: - Query Operations

    /// Checks if the pasteboard contains images
    /// - Returns: True if pasteboard has image content
    func hasImages() -> Bool {
        // Check if pasteboard can read NSImage objects
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }

        // Check for TIFF data
        if pasteboard.data(forType: .tiff) != nil {
            return true
        }

        // Check for PNG data
        if pasteboard.data(forType: .png) != nil {
            return true
        }

        // Check for file URLs that might be images
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if isImageFile(url) {
                    return true
                }
            }
        }

        return false
    }

    /// Gets the count of images on the pasteboard
    /// - Returns: Number of images available on pasteboard
    func imageCount() -> Int {
        // Try to read NSImage objects directly
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            return images.count
        }

        // Fallback: Count available data types
        var count = 0

        if pasteboard.data(forType: .tiff) != nil {
            count += 1
        }

        if pasteboard.data(forType: .png) != nil {
            count += 1
        }

        // Check for file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            count += urls.filter { isImageFile($0) }.count
        }

        return count
    }

    /// Gets available pasteboard types
    /// - Returns: Array of pasteboard types currently available
    func availableTypes() -> [NSPasteboard.PasteboardType] {
        return pasteboard.types ?? []
    }

    /// Clears all content from the pasteboard
    func clearPasteboard() {
        pasteboard.clearContents()
        print("[MacImageClipboardManager] Pasteboard cleared")
    }

    // MARK: - Private Helper Methods

    /// Writes an array of NSImage objects to the pasteboard
    private func writeImagesToPasteboard(_ images: [NSImage]) -> Bool {
        guard !images.isEmpty else { return false }

        // Clear existing pasteboard contents
        pasteboard.clearContents()

        // Write images to pasteboard
        let success = pasteboard.writeObjects(images)

        if success {
            print("[MacImageClipboardManager] Copied \(images.count) image(s) to pasteboard")
        } else {
            print("[MacImageClipboardManager] Failed to write images to pasteboard")
        }

        return success
    }

    /// Checks if a URL points to an image file
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "tif", "bmp", "heic", "heif", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
}

// MARK: - Pasteboard Type Extensions

extension NSPasteboard.PasteboardType {
    /// PNG image type
    static let png = NSPasteboard.PasteboardType("public.png")

    /// JPEG image type
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
}
