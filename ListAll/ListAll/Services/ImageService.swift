import Foundation
#if os(iOS)
import UIKit
import SwiftUI
import PhotosUI

// MARK: - Image Processing Service
// Note: This service is iOS-only due to UIKit and PhotosUI dependencies
// watchOS does not support image capture, picking, or complex image processing
class ImageService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ImageService()
    
    // MARK: - Configuration
    struct Configuration {
        static let maxImageSize: Int = 2 * 1024 * 1024 // 2MB
        static let thumbnailSize: CGSize = CGSize(width: 200, height: 200)
        static let compressionQuality: CGFloat = 0.8
        static let maxImageDimension: CGFloat = 2048
        static let maxCacheSize: Int = 100 // Maximum number of thumbnails to cache
    }
    
    // MARK: - Thumbnail Cache
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache
        thumbnailCache.countLimit = Configuration.maxCacheSize
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Image Processing
    
    /// Processes a UIImage for storage - resizes and compresses
    func processImageForStorage(_ image: UIImage) -> Data? {
        // Resize image if too large
        let resizedImage = resizeImage(image, maxDimension: Configuration.maxImageDimension)
        
        // Convert to JPEG with compression
        guard let imageData = resizedImage.jpegData(compressionQuality: Configuration.compressionQuality) else {
            return nil
        }
        
        // Further compress if still too large
        return compressImageData(imageData, maxSize: Configuration.maxImageSize)
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
    
    /// Creates a thumbnail from an image with caching
    func createThumbnail(from image: UIImage, size: CGSize = Configuration.thumbnailSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Creates a thumbnail from image data with caching
    func createThumbnail(from data: Data, size: CGSize = Configuration.thumbnailSize) -> UIImage? {
        // Create cache key from data hash and size
        let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Generate thumbnail if not cached
        guard let image = UIImage(data: data) else { return nil }
        let thumbnail = createThumbnail(from: image, size: size)
        
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
    
    /// Validates image data
    func validateImageData(_ data: Data) -> Bool {
        // Check if data can be converted to UIImage
        guard UIImage(data: data) != nil else { return false }
        
        // Check size limits
        guard data.count <= Configuration.maxImageSize * 2 else { return false } // Allow 2x for raw images
        
        return true
    }
    
    /// Validates image file size
    func validateImageSize(_ data: Data) -> (isValid: Bool, actualSize: Int, maxSize: Int) {
        let actualSize = data.count
        let maxSize = Configuration.maxImageSize
        return (actualSize <= maxSize, actualSize, maxSize)
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
    
    /// Processes image with error handling
    func processImage(_ image: UIImage) -> Result<Data, ImageError> {
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
#endif // os(iOS)
