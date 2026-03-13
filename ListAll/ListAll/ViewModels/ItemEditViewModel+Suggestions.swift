import SwiftUI

extension ItemEditViewModel {
    // Apply suggestion from SuggestionService
    @MainActor
    func applySuggestion(_ suggestion: ItemSuggestion) {
        // Get the full item from repository
        suggestedItem = dataRepository.getItem(by: suggestion.id)

        // Store the suggested values for change detection
        suggestedItemTitle = suggestion.title
        suggestedItemDescription = suggestion.description
        suggestedItemQuantity = suggestion.quantity
        suggestedItemImages = suggestion.images

        // Apply all fields from suggestion
        title = suggestion.title
        description = suggestion.description ?? ""
        quantity = suggestion.quantity

        // Deep copy images to avoid Core Data conflicts
        // Create new ItemImage instances with new IDs to prevent crashes
        // when user modifies suggested item and creates new item
        images = suggestion.images.map { image in
            var newImage = ItemImage()
            newImage.id = UUID() // New ID for the copy
            newImage.imageData = image.imageData
            newImage.orderNumber = image.orderNumber
            newImage.createdAt = Date()
            newImage.itemId = nil // Will be set when item is saved
            return newImage
        }
    }

    // Check if user made any changes from the suggested item
    func hasChangesFromSuggestion() -> Bool {
        guard let suggestedTitle = suggestedItemTitle else {
            return true // No suggestion applied, so user is creating their own item
        }

        // Check if any field differs from the suggested values
        let titleChanged = title != suggestedTitle
        let descriptionChanged = description != (suggestedItemDescription ?? "")
        let quantityChanged = quantity != (suggestedItemQuantity ?? 1)

        // Check if images changed - compare by count and data, not IDs
        // (IDs are regenerated when copying images from suggestions)
        let imagesChanged: Bool
        if let suggestedImages = suggestedItemImages {
            if images.count != suggestedImages.count {
                imagesChanged = true
            } else {
                // Compare image data arrays to detect actual content changes
                imagesChanged = !images.enumerated().allSatisfy { index, currentImage in
                    guard index < suggestedImages.count else { return false }
                    let suggestedImage = suggestedImages[index]
                    return currentImage.imageData == suggestedImage.imageData
                }
            }
        } else {
            imagesChanged = !images.isEmpty
        }

        return titleChanged || descriptionChanged || quantityChanged || imagesChanged
    }
}
