import Foundation
import UIKit

// MARK: - ItemImage Model
struct ItemImage: Identifiable, Codable, Equatable {
    let id: UUID
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
    
    /// Sets the image data from a UIImage
    mutating func setImage(_ image: UIImage, quality: CGFloat = 0.8) {
        if let data = image.jpegData(compressionQuality: quality) {
            self.imageData = data
        }
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
    
    /// Compresses the image data to reduce size
    mutating func compressImage(maxSize: Int = 1024 * 1024) { // 1MB default
        guard let imageData = imageData,
              let image = UIImage(data: imageData) else { return }
        
        var compressionQuality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compressionQuality)
        
        while let data = compressedData, data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        if let finalData = compressedData {
            self.imageData = finalData
        }
    }
}