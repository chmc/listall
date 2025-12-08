//
//  MacImageDropHandler.swift
//  ListAllMac
//
//  Handles drag-and-drop operations for images in macOS.
//  Supports multiple image formats and security-scoped resource access.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Handles drag-and-drop operations for images in macOS
/// Supports multiple image formats and handles security-scoped resource access
@MainActor
class MacImageDropHandler {

    // MARK: - Singleton

    static let shared = MacImageDropHandler()

    // MARK: - Configuration

    struct Configuration {
        /// Maximum number of images to load in a single drop operation
        static let maxImagesPerDrop: Int = 10

        /// Whether to log detailed debug information
        static let enableDebugLogging: Bool = false
    }

    // MARK: - Supported Types

    /// All supported image UTTypes for drag-and-drop
    static let supportedImageTypes: [UTType] = [
        .image,         // General image type
        .jpeg,          // JPEG format
        .png,           // PNG format
        .heic,          // HEIC format (iOS photos)
        .tiff,          // TIFF format
        .gif,           // GIF format
        .webP,          // WebP format
        .bmp,           // Bitmap format
        .ico            // Icon format
    ]

    /// File URL type for Finder drops
    static let fileURLType: UTType = .fileURL

    // MARK: - Initialization

    private init() {}

    // MARK: - Drop Validation

    /// Checks if the provided NSItemProviders contain images
    func containsImages(_ providers: [NSItemProvider]) -> Bool {
        return providers.contains { provider in
            containsImage(provider)
        }
    }

    /// Checks if a single NSItemProvider contains an image
    func containsImage(_ provider: NSItemProvider) -> Bool {
        // Check for file URL (Finder drag)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return true
        }

        // Check for direct image types
        for imageType in Self.supportedImageTypes {
            if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                return true
            }
        }

        return false
    }

    // MARK: - Image Loading (Multiple)

    /// Loads images from an array of NSItemProviders
    func loadImages(from providers: [NSItemProvider]) async -> [NSImage] {
        debugLog("Loading images from \(providers.count) provider(s)")

        // Limit number of providers to prevent memory issues
        let limitedProviders = Array(providers.prefix(Configuration.maxImagesPerDrop))

        // Load images concurrently
        var loadedImages: [NSImage] = []

        await withTaskGroup(of: NSImage?.self) { group in
            for (index, provider) in limitedProviders.enumerated() {
                group.addTask {
                    return await self.loadImage(from: provider, index: index)
                }
            }

            for await image in group {
                if let image = image {
                    loadedImages.append(image)
                }
            }
        }

        debugLog("Successfully loaded \(loadedImages.count) image(s)")
        return loadedImages
    }

    // MARK: - Image Loading (Single)

    /// Loads a single image from an NSItemProvider
    func loadImage(from provider: NSItemProvider, index: Int = 0) async -> NSImage? {
        debugLog("Loading image from provider \(index)")

        // Strategy 1: Try loading from file URL (Finder drag)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let image = await loadImageFromFileURL(provider, index: index) {
                return image
            }
        }

        // Strategy 2: Try loading direct image data
        for imageType in Self.supportedImageTypes {
            if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                if let image = await loadImageDirectly(from: provider, type: imageType, index: index) {
                    return image
                }
            }
        }

        debugLog("Failed to load image from provider \(index)")
        return nil
    }

    // MARK: - Loading Strategies

    /// Loads an image from a file URL (Finder drag)
    private func loadImageFromFileURL(_ provider: NSItemProvider, index: Int) async -> NSImage? {
        debugLog("Attempting to load from file URL (provider \(index))")

        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                Task { @MainActor in
                    guard let url = url else {
                        self.debugLog("Failed to get URL from provider \(index): \(error?.localizedDescription ?? "unknown")")
                        continuation.resume(returning: nil)
                        return
                    }

                    // Resolve file reference URL to path URL if needed
                    let resolvedURL = self.resolveFileURL(url)
                    self.debugLog("Loading image from file: \(resolvedURL.path)")

                    // Handle security-scoped resource access
                    let accessing = resolvedURL.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            resolvedURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    // Load image from file
                    if let image = NSImage(contentsOf: resolvedURL) {
                        self.debugLog("Successfully loaded image from file (provider \(index))")
                        continuation.resume(returning: image)
                    } else {
                        self.debugLog("Failed to load image from file (provider \(index))")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    /// Loads an image directly from provider data
    private func loadImageDirectly(from provider: NSItemProvider, type: UTType, index: Int) async -> NSImage? {
        debugLog("Attempting to load directly as \(type.identifier) (provider \(index))")

        return await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                Task { @MainActor in
                    guard let data = data else {
                        self.debugLog("Failed to get data from provider \(index): \(error?.localizedDescription ?? "unknown")")
                        continuation.resume(returning: nil)
                        return
                    }

                    self.debugLog("Received \(data.count) bytes of image data (provider \(index))")

                    if let image = NSImage(data: data) {
                        self.debugLog("Successfully loaded image directly (provider \(index))")
                        continuation.resume(returning: image)
                    } else {
                        self.debugLog("Failed to create NSImage from data (provider \(index))")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    // MARK: - URL Resolution

    /// Resolves file reference URLs to path URLs
    func resolveFileURL(_ url: URL) -> URL {
        // Check if this is a file reference URL
        if url.path.hasPrefix("/.file/id=") {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withoutImplicitSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withoutUI,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if !isStale {
                    debugLog("Resolved file reference URL: \(url.path) -> \(resolvedURL.path)")
                    return resolvedURL
                }
            } catch {
                debugLog("Failed to resolve file reference URL: \(error.localizedDescription)")
            }
        }

        return url
    }

    // MARK: - Integration with ImageService

    /// Processes loaded images for storage using ImageService
    func processImagesForStorage(_ images: [NSImage]) async -> [Data] {
        debugLog("Processing \(images.count) image(s) for storage")

        return await withTaskGroup(of: Data?.self) { group in
            var processedData: [Data] = []

            for image in images {
                group.addTask {
                    return ImageService.shared.processImageForStorage(image)
                }
            }

            for await data in group {
                if let data = data {
                    processedData.append(data)
                }
            }

            return processedData
        }
    }

    /// Creates ItemImages from loaded images
    func createItemImages(from images: [NSImage], itemId: UUID? = nil) async -> [ItemImage] {
        debugLog("Creating ItemImages from \(images.count) image(s)")

        return await withTaskGroup(of: ItemImage?.self) { group in
            var itemImages: [ItemImage] = []

            for image in images {
                group.addTask {
                    return ImageService.shared.createItemImage(from: image, itemId: itemId)
                }
            }

            for await itemImage in group {
                if let itemImage = itemImage {
                    itemImages.append(itemImage)
                }
            }

            return itemImages
        }
    }

    // MARK: - Debug Logging

    private func debugLog(_ message: String) {
        if Configuration.enableDebugLogging {
            print("[MacImageDropHandler] \(message)")
        }
    }
}

// MARK: - Error Handling

extension MacImageDropHandler {

    /// Errors that can occur during image drop operations
    enum DropError: LocalizedError {
        case noImageProviders
        case loadingFailed
        case processingFailed
        case invalidImageData
        case tooManyImages(max: Int)
        case fileAccessDenied(path: String)

        var errorDescription: String? {
            switch self {
            case .noImageProviders:
                return "No image data found in drop operation"
            case .loadingFailed:
                return "Failed to load image from drop"
            case .processingFailed:
                return "Failed to process dropped image"
            case .invalidImageData:
                return "Dropped data is not a valid image"
            case .tooManyImages(let max):
                return "Too many images dropped (maximum: \(max))"
            case .fileAccessDenied(let path):
                return "Cannot access file at path: \(path)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noImageProviders:
                return "Try dragging an image file from Finder"
            case .loadingFailed:
                return "Ensure the file is a valid image and you have permission to access it"
            case .processingFailed:
                return "The image may be corrupted or in an unsupported format"
            case .invalidImageData:
                return "Only JPEG, PNG, HEIC, GIF, TIFF, and WebP formats are supported"
            case .tooManyImages(let max):
                return "Please drop \(max) or fewer images at a time"
            case .fileAccessDenied:
                return "Check file permissions or app sandbox settings"
            }
        }
    }
}
