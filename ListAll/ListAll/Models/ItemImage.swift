import Foundation
import UIKit

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
    
    /// Returns the UIImage from the stored data
    var uiImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Sets the image data from a UIImage with industry-standard compression
    mutating func setImage(_ image: UIImage, quality: CGFloat = 0.75) {
        #if os(iOS)
        // Use ImageService for proper compression on iOS
        if let data = ImageService.shared.processImageForStorage(image) {
            self.imageData = data
        }
        #else
        // Fallback compression for watchOS
        if let data = image.jpegData(compressionQuality: quality) {
            self.imageData = data
        }
        #endif
    }
    
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
    
    /// Compresses the image data to reduce size using industry standards
    mutating func compressImage(maxSize: Int = 512 * 1024) { // 512KB - industry standard
        guard let imageData = imageData,
              let image = UIImage(data: imageData) else { return }
        
        #if os(iOS)
        // Use ImageService for proper compression on iOS
        if let compressedData = ImageService.shared.compressImageData(imageData, maxSize: maxSize) {
            self.imageData = compressedData
        }
        #else
        // Fallback compression for watchOS
        var compressionQuality: CGFloat = 0.75
        var compressedData = image.jpegData(compressionQuality: compressionQuality)
        
        while let data = compressedData, data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        if let finalData = compressedData {
            self.imageData = finalData
        }
        #endif
    }
}