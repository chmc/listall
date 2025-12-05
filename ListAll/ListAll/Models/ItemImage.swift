import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - ItemImage Model
struct ItemImage: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var imageData: Data?
    var orderNumber: Int
    var itemId: UUID?
    var createdAt: Date
    
    init(imageData: Data? = nil, itemId: UUID? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.orderNumber = 0
        self.itemId = itemId
        self.createdAt = Date()
    }
}

// MARK: - Convenience Methods
extension ItemImage {
    
    #if canImport(UIKit) && !os(watchOS)
    /// Returns the UIImage from the stored data
    var uiImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }

    /// Sets the image data from a UIImage with industry-standard compression
    mutating func setImage(_ image: UIImage, quality: CGFloat = 0.75) {
        // Basic JPEG compression for cross-platform compatibility
        if let data = image.jpegData(compressionQuality: quality) {
            self.imageData = data
        }
    }

    /// Compresses the image data to reduce size using industry standards
    mutating func compressImage(maxSize: Int = 512 * 1024) { // 512KB - industry standard
        guard let imageData = imageData,
              let image = UIImage(data: imageData) else { return }

        // Progressive compression
        var compressionQuality: CGFloat = 0.75
        var compressedData = image.jpegData(compressionQuality: compressionQuality)

        while let data = compressedData, data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }

        if let finalData = compressedData {
            self.imageData = finalData
        }
    }
    #elseif os(macOS)
    /// Returns the NSImage from the stored data
    var nsImage: NSImage? {
        guard let imageData = imageData else { return nil }
        return NSImage(data: imageData)
    }

    /// Sets the image data from an NSImage with industry-standard compression
    mutating func setImage(_ image: NSImage, quality: CGFloat = 0.75) {
        // Basic JPEG compression for cross-platform compatibility
        if let data = jpegData(from: image, compressionQuality: quality) {
            self.imageData = data
        }
    }

    /// Compresses the image data to reduce size using industry standards
    mutating func compressImage(maxSize: Int = 512 * 1024) { // 512KB - industry standard
        guard let imageData = imageData,
              let image = NSImage(data: imageData) else { return }

        // Progressive compression
        var compressionQuality: CGFloat = 0.75
        var compressedData = jpegData(from: image, compressionQuality: compressionQuality)

        while let data = compressedData, data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = jpegData(from: image, compressionQuality: compressionQuality)
        }

        if let finalData = compressedData {
            self.imageData = finalData
        }
    }

    /// Creates JPEG data from NSImage
    private func jpegData(from image: NSImage, compressionQuality: CGFloat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    #endif
    
    /// Returns true if the image has data
    var hasImageData: Bool {
        return imageData != nil && !imageData!.isEmpty
    }
    
    /// Returns the image size in bytes
    var imageSize: Int {
        return imageData?.count ?? 0
    }
    
    /// Returns a formatted size string
    var formattedSize: String {
        let bytes = imageSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    /// Validates the image data
    func validate() -> Bool {
        return hasImageData
    }
}