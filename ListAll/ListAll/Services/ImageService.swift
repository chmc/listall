import Foundation
#if os(iOS)
import UIKit
import SwiftUI
import PhotosUI

// MARK: - Image Processing Service (iOS)
// Note: This service is iOS-only due to UIKit and PhotosUI dependencies
// watchOS does not support image capture, picking, or complex image processing
class ImageService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ImageService()
    
    // MARK: - Configuration
    struct Configuration {
        // Industry-standard image compression settings
        static let maxImageSize: Int = 512 * 1024 // 512KB - reduced from 2MB for better performance
        static let thumbnailSize: CGSize = CGSize(width: 150, height: 150) // Reduced from 200x200
        static let compressionQuality: CGFloat = 0.75 // Reduced from 0.8 for better compression
        static let maxImageDimension: CGFloat = 1200 // Reduced from 2048 for mobile optimization
        static let maxCacheSize: Int = 50 // Reduced cache size for memory efficiency
        
        // Progressive compression settings
        static let progressiveQualityLevels: [CGFloat] = [0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
        static let minCompressionQuality: CGFloat = 0.1
        static let maxThumbnailSize: Int = 50 * 1024 // 50KB for thumbnails
        
        // Format-specific settings
        static let webpQuality: CGFloat = 0.8
        static let pngCompressionLevel: CGFloat = 0.6
        
        // Mobile-optimized dimensions
        static let mobileMaxDimension: CGFloat = 800
        static let tabletMaxDimension: CGFloat = 1200
    }
    
    // MARK: - Thumbnail Cache
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache
        thumbnailCache.countLimit = Configuration.maxCacheSize
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Image Processing
    
    /// Processes a UIImage for storage - resizes and compresses with industry standards
    func processImageForStorage(_ image: UIImage) -> Data? {
        // Resize image based on device type and content
        let resizedImage = resizeImageForStorage(image)
        
        // Try WebP first for better compression, fallback to JPEG
        if let webpData = createWebPData(from: resizedImage) {
            return compressImageData(webpData, maxSize: Configuration.maxImageSize)
        }
        
        // Fallback to JPEG with progressive compression
        return compressImageDataProgressive(resizedImage, maxSize: Configuration.maxImageSize)
    }
    
    /// Resizes an image for storage based on device type and content
    func resizeImageForStorage(_ image: UIImage) -> UIImage {
        let size = image.size
        let maxDimension = getOptimalMaxDimension(for: image)
        
        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create resized image with high quality
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Resizes an image to fit within maximum dimensions while maintaining aspect ratio
    func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Determines optimal max dimension based on image content and device
    private func getOptimalMaxDimension(for image: UIImage) -> CGFloat {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        // For very wide or very tall images, use smaller dimensions
        if aspectRatio > 3.0 || aspectRatio < 0.33 {
            return Configuration.mobileMaxDimension
        }
        
        // For square or near-square images, use standard dimensions
        return Configuration.maxImageDimension
    }
    
    /// Compresses image data to fit within size limit
    func compressImageData(_ data: Data, maxSize: Int) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        
        var compressionQuality: CGFloat = Configuration.compressionQuality
        var compressedData = image.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality until size is acceptable
        while let currentData = compressedData,
              currentData.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        return compressedData ?? data
    }
    
    /// Progressive compression with multiple quality levels
    func compressImageDataProgressive(_ image: UIImage, maxSize: Int) -> Data? {
        // Try each quality level until we find one that fits
        for quality in Configuration.progressiveQualityLevels {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= maxSize {
                return data
            }
        }
        
        // If no quality level works, use the minimum
        return image.jpegData(compressionQuality: Configuration.minCompressionQuality)
    }
    
    /// Creates WebP data if available (iOS 14+)
    @available(iOS 14.0, *)
    func createWebPData(from image: UIImage) -> Data? {
        // WebP support requires iOS 14+
        guard let data = image.jpegData(compressionQuality: Configuration.webpQuality) else {
            return nil
        }
        
        // For now, return JPEG data as WebP conversion requires additional libraries
        // In a production app, you would use a WebP library like SDWebImageWebPCoder
        return data
    }
    
    
    /// Creates a thumbnail from an image with caching and optimization
    func createThumbnail(from image: UIImage, size: CGSize = Configuration.thumbnailSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .medium
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Creates an optimized thumbnail with size validation
    func createOptimizedThumbnail(from image: UIImage, size: CGSize = Configuration.thumbnailSize) -> UIImage? {
        let thumbnail = createThumbnail(from: image, size: size)
        
        // Validate thumbnail size
        guard let data = thumbnail.jpegData(compressionQuality: 0.8),
              data.count <= Configuration.maxThumbnailSize else {
            // If thumbnail is too large, create a smaller one
            let smallerSize = CGSize(width: size.width * 0.8, height: size.height * 0.8)
            return createThumbnail(from: image, size: smallerSize)
        }
        
        return thumbnail
    }
    
    /// Creates a thumbnail from image data with caching and optimization
    func createThumbnail(from data: Data, size: CGSize = Configuration.thumbnailSize) -> UIImage? {
        // Create cache key from data hash and size
        let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Generate thumbnail if not cached
        guard let image = UIImage(data: data) else { return nil }
        guard let thumbnail = createOptimizedThumbnail(from: image, size: size) else { return nil }
        
        // Store in cache
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)
        
        return thumbnail
    }
    
    /// Clears the thumbnail cache
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }
    
    // MARK: - ItemImage Management
    
    /// Creates an ItemImage from a UIImage
    func createItemImage(from image: UIImage, itemId: UUID? = nil) -> ItemImage? {
        guard let processedData = processImageForStorage(image) else {
            return nil
        }
        
        let itemImage = ItemImage(imageData: processedData, itemId: itemId)
        return itemImage
    }
    
    /// Adds an image to an item
    func addImageToItem(_ item: inout Item, image: UIImage) -> Bool {
        guard let itemImage = createItemImage(from: image, itemId: item.id) else {
            return false
        }
        
        // Set order number
        var newItemImage = itemImage
        newItemImage.orderNumber = item.images.count
        
        // Add to item
        item.images.append(newItemImage)
        item.updateModifiedDate()
        
        return true
    }
    
    /// Removes an image from an item by ID
    func removeImageFromItem(_ item: inout Item, imageId: UUID) -> Bool {
        guard let index = item.images.firstIndex(where: { $0.id == imageId }) else {
            return false
        }
        
        item.images.remove(at: index)
        
        // Reorder remaining images
        for i in 0..<item.images.count {
            item.images[i].orderNumber = i
        }
        
        item.updateModifiedDate()
        return true
    }
    
    /// Reorders images within an item
    func reorderImages(in item: inout Item, from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        guard sourceIndex >= 0 && sourceIndex < item.images.count &&
              destinationIndex >= 0 && destinationIndex < item.images.count &&
              sourceIndex != destinationIndex else {
            return false
        }
        
        let movedImage = item.images.remove(at: sourceIndex)
        item.images.insert(movedImage, at: destinationIndex)
        
        // Update order numbers
        for i in 0..<item.images.count {
            item.images[i].orderNumber = i
        }
        
        item.updateModifiedDate()
        return true
    }
    
    // MARK: - Image Validation
    
    /// Validates image data with comprehensive checks
    func validateImageData(_ data: Data) -> Bool {
        // Check if data can be converted to UIImage
        guard UIImage(data: data) != nil else { return false }
        
        // Check size limits
        guard data.count <= Configuration.maxImageSize * 2 else { return false } // Allow 2x for raw images
        
        // Check format validity
        guard getImageFormat(from: data) != nil else { return false }
        
        return true
    }
    
    /// Validates image file size with detailed information
    func validateImageSize(_ data: Data) -> (isValid: Bool, actualSize: Int, maxSize: Int, recommendation: String?) {
        let actualSize = data.count
        let maxSize = Configuration.maxImageSize
        let isValid = actualSize <= maxSize
        
        var recommendation: String? = nil
        if !isValid {
            let reductionPercent = Int((1.0 - Double(maxSize) / Double(actualSize)) * 100)
            recommendation = "Image is \(formatFileSize(actualSize)). Reduce size by \(reductionPercent)% to meet \(formatFileSize(maxSize)) limit."
        }
        
        return (isValid, actualSize, maxSize, recommendation)
    }
    
    /// Validates image dimensions
    func validateImageDimensions(_ image: UIImage) -> (isValid: Bool, actualSize: CGSize, maxDimension: CGFloat, recommendation: String?) {
        let size = image.size
        let maxDimension = Configuration.maxImageDimension
        let isValid = size.width <= maxDimension && size.height <= maxDimension
        
        var recommendation: String? = nil
        if !isValid {
            let largerDimension = max(size.width, size.height)
            let reductionPercent = Int((1.0 - maxDimension / largerDimension) * 100)
            recommendation = "Image is \(Int(largerDimension))px. Reduce by \(reductionPercent)% to meet \(Int(maxDimension))px limit."
        }
        
        return (isValid, size, maxDimension, recommendation)
    }
    
    /// Comprehensive image validation
    func validateImage(_ image: UIImage) -> (isValid: Bool, issues: [String], recommendations: [String]) {
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check dimensions
        let dimensionValidation = validateImageDimensions(image)
        if !dimensionValidation.isValid {
            issues.append("Image dimensions exceed maximum allowed size")
            if let rec = dimensionValidation.recommendation {
                recommendations.append(rec)
            }
        }
        
        // Check file size
        if let data = image.jpegData(compressionQuality: 0.8) {
            let sizeValidation = validateImageSize(data)
            if !sizeValidation.isValid {
                issues.append("Image file size exceeds maximum allowed size")
                if let rec = sizeValidation.recommendation {
                    recommendations.append(rec)
                }
            }
        }
        
        // Check aspect ratio
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio > 5.0 || aspectRatio < 0.2 {
            issues.append("Image has extreme aspect ratio")
            recommendations.append("Consider cropping to a more standard aspect ratio")
        }
        
        return (issues.isEmpty, issues, recommendations)
    }
    
    // MARK: - Image Format Utilities
    
    /// Gets the image format from data
    func getImageFormat(from data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        
        let bytes = data.prefix(4).map { $0 }
        
        // Check for common image formats
        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "JPEG"
        } else if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG"
        } else if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "GIF"
        } else if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "WebP"
        }
        
        return "Unknown"
    }
    
    /// Formats file size for display
    func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    // MARK: - Error Handling
    
    enum ImageError: Error, LocalizedError {
        case invalidImageData
        case imageTooLarge
        case processingFailed
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid image data"
            case .imageTooLarge:
                return "Image is too large"
            case .processingFailed:
                return "Failed to process image"
            case .unsupportedFormat:
                return "Unsupported image format"
            }
        }
    }
    
    /// Processes image with error handling and ensures no original size storage
    func processImage(_ image: UIImage) -> Result<Data, ImageError> {
        // Always process image for storage - never store original size
        guard let processedData = processImageForStorage(image) else {
            return .failure(.processingFailed)
        }
        
        let validation = validateImageSize(processedData)
        guard validation.isValid else {
            return .failure(.imageTooLarge)
        }
        
        return .success(processedData)
    }
    
    /// Ensures image is properly compressed and resized before storage
    func ensureOptimizedImage(_ image: UIImage) -> UIImage {
        // Always resize and compress - never store original
        return resizeImageForStorage(image)
    }
    
    /// Gets compression statistics for an image
    func getCompressionStats(for image: UIImage) -> (originalSize: Int, compressedSize: Int, compressionRatio: Double, savings: Int) {
        let originalData = image.jpegData(compressionQuality: 1.0) ?? Data()
        let compressedData = processImageForStorage(image) ?? Data()
        
        let originalSize = originalData.count
        let compressedSize = compressedData.count
        let compressionRatio = Double(compressedSize) / Double(originalSize)
        let savings = originalSize - compressedSize
        
        return (originalSize, compressedSize, compressionRatio, savings)
    }
}

// MARK: - SwiftUI Integration
extension ImageService {
    
    /// Creates a SwiftUI Image from ItemImage
    func swiftUIImage(from itemImage: ItemImage) -> Image? {
        guard let uiImage = itemImage.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
    
    /// Creates a SwiftUI Image thumbnail from ItemImage
    func swiftUIThumbnail(from itemImage: ItemImage, size: CGSize = Configuration.thumbnailSize) -> Image? {
        guard let imageData = itemImage.imageData,
              let thumbnail = createThumbnail(from: imageData, size: size) else {
            return nil
        }
        return Image(uiImage: thumbnail)
    }
}
#elseif os(macOS)
import AppKit
import SwiftUI
import Combine

// MARK: - Image Processing Service (macOS)
// macOS-specific implementation using NSImage instead of UIImage
class ImageService: ObservableObject {

    // MARK: - Singleton
    static let shared = ImageService()

    // MARK: - Configuration
    struct Configuration {
        // Industry-standard image compression settings
        static let maxImageSize: Int = 512 * 1024 // 512KB
        static let thumbnailSize: CGSize = CGSize(width: 150, height: 150)
        static let compressionQuality: CGFloat = 0.75
        static let maxImageDimension: CGFloat = 1200
        static let maxCacheSize: Int = 50

        // Progressive compression settings
        static let progressiveQualityLevels: [CGFloat] = [0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
        static let minCompressionQuality: CGFloat = 0.1
        static let maxThumbnailSize: Int = 50 * 1024 // 50KB for thumbnails
    }

    // MARK: - Thumbnail Cache
    private var thumbnailCache = NSCache<NSString, NSImage>()

    private init() {
        // Configure cache
        thumbnailCache.countLimit = Configuration.maxCacheSize
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    // MARK: - Image Processing

    /// Processes an NSImage for storage - resizes and compresses
    func processImageForStorage(_ image: NSImage) -> Data? {
        // Resize image
        let resizedImage = resizeImageForStorage(image)

        // Compress as JPEG
        return compressImageDataProgressive(resizedImage, maxSize: Configuration.maxImageSize)
    }

    /// Resizes an image for storage
    func resizeImageForStorage(_ image: NSImage) -> NSImage {
        let size = image.size
        let maxDimension = Configuration.maxImageDimension

        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Create resized image
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }

    /// Resizes an image to fit within maximum dimensions while maintaining aspect ratio
    func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size

        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Create resized image
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }

    /// Compresses image data to fit within size limit
    func compressImageData(_ data: Data, maxSize: Int) -> Data? {
        guard let image = NSImage(data: data) else { return data }

        var compressionQuality: CGFloat = Configuration.compressionQuality
        var compressedData = jpegData(from: image, compressionQuality: compressionQuality)

        // Reduce quality until size is acceptable
        while let currentData = compressedData,
              currentData.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = jpegData(from: image, compressionQuality: compressionQuality)
        }

        return compressedData ?? data
    }

    /// Progressive compression with multiple quality levels
    func compressImageDataProgressive(_ image: NSImage, maxSize: Int) -> Data? {
        // Try each quality level until we find one that fits
        for quality in Configuration.progressiveQualityLevels {
            if let data = jpegData(from: image, compressionQuality: quality),
               data.count <= maxSize {
                return data
            }
        }

        // If no quality level works, use the minimum
        return jpegData(from: image, compressionQuality: Configuration.minCompressionQuality)
    }

    /// Creates JPEG data from NSImage
    private func jpegData(from image: NSImage, compressionQuality: CGFloat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    /// Creates a thumbnail from an image
    func createThumbnail(from image: NSImage, size: CGSize = Configuration.thumbnailSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .medium
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    /// Creates a thumbnail from image data with caching
    func createThumbnail(from data: Data, size: CGSize = Configuration.thumbnailSize) -> NSImage? {
        // Create cache key from data hash and size
        let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString

        // Check cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }

        // Generate thumbnail if not cached
        guard let image = NSImage(data: data) else { return nil }
        let thumbnail = createThumbnail(from: image, size: size)

        // Store in cache
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)

        return thumbnail
    }

    /// Creates a thumbnail asynchronously from image data with caching
    /// Use this when loading multiple images to avoid blocking the main thread
    func createThumbnailAsync(from data: Data, size: CGSize = Configuration.thumbnailSize) async -> NSImage? {
        let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString

        // Check cache on current thread first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }

        // Generate thumbnail on background thread
        return await Task.detached(priority: .userInitiated) { [self] in
            guard let image = NSImage(data: data) else { return nil }
            let thumbnail = createThumbnail(from: image, size: size)

            // Store in cache (NSCache is thread-safe)
            thumbnailCache.setObject(thumbnail, forKey: cacheKey)

            return thumbnail
        }.value
    }

    /// Clears the thumbnail cache
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }

    // MARK: - ItemImage Management

    /// Creates an ItemImage from an NSImage
    func createItemImage(from image: NSImage, itemId: UUID? = nil) -> ItemImage? {
        guard let processedData = processImageForStorage(image) else {
            return nil
        }

        let itemImage = ItemImage(imageData: processedData, itemId: itemId)
        return itemImage
    }

    /// Adds an image to an item
    func addImageToItem(_ item: inout Item, image: NSImage) -> Bool {
        guard let itemImage = createItemImage(from: image, itemId: item.id) else {
            return false
        }

        // Set order number
        var newItemImage = itemImage
        newItemImage.orderNumber = item.images.count

        // Add to item
        item.images.append(newItemImage)
        item.updateModifiedDate()

        return true
    }

    /// Removes an image from an item by ID
    func removeImageFromItem(_ item: inout Item, imageId: UUID) -> Bool {
        guard let index = item.images.firstIndex(where: { $0.id == imageId }) else {
            return false
        }

        item.images.remove(at: index)

        // Reorder remaining images
        for i in 0..<item.images.count {
            item.images[i].orderNumber = i
        }

        item.updateModifiedDate()
        return true
    }

    /// Reorders images within an item
    func reorderImages(in item: inout Item, from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        guard sourceIndex >= 0 && sourceIndex < item.images.count &&
              destinationIndex >= 0 && destinationIndex < item.images.count &&
              sourceIndex != destinationIndex else {
            return false
        }

        let movedImage = item.images.remove(at: sourceIndex)
        item.images.insert(movedImage, at: destinationIndex)

        // Update order numbers
        for i in 0..<item.images.count {
            item.images[i].orderNumber = i
        }

        item.updateModifiedDate()
        return true
    }

    // MARK: - Image Validation

    /// Validates image data
    func validateImageData(_ data: Data) -> Bool {
        guard NSImage(data: data) != nil else { return false }
        guard data.count <= Configuration.maxImageSize * 2 else { return false }
        guard getImageFormat(from: data) != nil else { return false }
        return true
    }

    /// Validates image file size
    func validateImageSize(_ data: Data) -> (isValid: Bool, actualSize: Int, maxSize: Int, recommendation: String?) {
        let actualSize = data.count
        let maxSize = Configuration.maxImageSize
        let isValid = actualSize <= maxSize

        var recommendation: String? = nil
        if !isValid {
            let reductionPercent = Int((1.0 - Double(maxSize) / Double(actualSize)) * 100)
            recommendation = "Image is \(formatFileSize(actualSize)). Reduce size by \(reductionPercent)% to meet \(formatFileSize(maxSize)) limit."
        }

        return (isValid, actualSize, maxSize, recommendation)
    }

    // MARK: - Image Format Utilities

    /// Gets the image format from data
    func getImageFormat(from data: Data) -> String? {
        guard data.count >= 4 else { return nil }

        let bytes = data.prefix(4).map { $0 }

        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "JPEG"
        } else if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG"
        } else if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "GIF"
        } else if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "WebP"
        }

        return "Unknown"
    }

    /// Formats file size for display
    func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    // MARK: - Error Handling

    enum ImageError: Error, LocalizedError {
        case invalidImageData
        case imageTooLarge
        case processingFailed
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid image data"
            case .imageTooLarge:
                return "Image is too large"
            case .processingFailed:
                return "Failed to process image"
            case .unsupportedFormat:
                return "Unsupported image format"
            }
        }
    }

    /// Processes image with error handling
    func processImage(_ image: NSImage) -> Result<Data, ImageError> {
        guard let processedData = processImageForStorage(image) else {
            return .failure(.processingFailed)
        }

        let validation = validateImageSize(processedData)
        guard validation.isValid else {
            return .failure(.imageTooLarge)
        }

        return .success(processedData)
    }
}

// MARK: - SwiftUI Integration
extension ImageService {

    /// Creates a SwiftUI Image from ItemImage
    func swiftUIImage(from itemImage: ItemImage) -> Image? {
        guard let imageData = itemImage.imageData,
              let nsImage = NSImage(data: imageData) else { return nil }
        return Image(nsImage: nsImage)
    }

    /// Creates a SwiftUI Image thumbnail from ItemImage
    func swiftUIThumbnail(from itemImage: ItemImage, size: CGSize = Configuration.thumbnailSize) -> Image? {
        guard let imageData = itemImage.imageData,
              let thumbnail = createThumbnail(from: imageData, size: size) else {
            return nil
        }
        return Image(nsImage: thumbnail)
    }
}
#endif // os(iOS) or os(macOS)
