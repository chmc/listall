import SwiftUI

@MainActor
class ItemEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var quantity: Int = 1
    @Published var images: [ItemImage] = []
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false

    // Validation state
    @Published var showTitleError = false
    @Published var showDescriptionError = false
    @Published var showQuantityError = false

    private let list: List
    private let editingItem: Item?
    private let dataRepository: DataRepository
    private var originalItem: Item?

    // Track suggested item for duplicate detection
    private var suggestedItem: Item?
    private var suggestedItemTitle: String?
    private var suggestedItemDescription: String?
    private var suggestedItemQuantity: Int?
    private var suggestedItemImages: [ItemImage]?

    var isEditing: Bool {
        editingItem != nil
    }

    var titleErrorMessage: String {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Item title is required"
        } else if title.count > 200 {
            return "Title must be 200 characters or less"
        }
        return ""
    }

    var descriptionErrorMessage: String {
        if description.count > 50000 {
            return "Description must be 50,000 characters or less"
        }
        return ""
    }

    var quantityErrorMessage: String {
        if quantity < 1 {
            return "Quantity must be at least 1"
        }
        return ""
    }

    var isValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200
        let descriptionValid = description.count <= 50000
        let quantityValid = quantity >= 1

        return titleValid && descriptionValid && quantityValid
    }

    var hasValidationErrors: Bool {
        showTitleError || showDescriptionError || showQuantityError
    }

    var hasUnsavedChanges: Bool {
        guard let original = originalItem else {
            // For new items, check if any fields have been modified from defaults
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   quantity != 1
        }

        // For editing, compare with original values
        return title != original.title ||
               description != (original.itemDescription ?? "") ||
               quantity != original.quantity
    }

    init(list: List, item: Item? = nil, dataRepository: DataRepository = DataRepository()) {
        self.list = list
        self.editingItem = item
        self.originalItem = item
        self.dataRepository = dataRepository
    }

    func setupForEditing() {
        if let item = editingItem {
            title = item.title
            description = item.itemDescription ?? ""
            quantity = item.quantity
            images = item.images
            originalItem = item
        }
    }

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
    private func hasChangesFromSuggestion() -> Bool {
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

    func incrementQuantity() {
        guard quantity < 9999 else { return }
        quantity += 1
    }

    func decrementQuantity() {
        guard quantity > 1 else { return }
        quantity -= 1
    }

    func validateFields() {
        showTitleError = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200
        showDescriptionError = description.count > 50000
        showQuantityError = quantity < 1
    }

    // MARK: - Image Management

    func addImage(_ itemImage: ItemImage) {
        var newImage = itemImage
        newImage.orderNumber = images.count
        images.append(newImage)
    }

    func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)

        // Reorder remaining images
        for i in 0..<images.count {
            images[i].orderNumber = i
        }
    }

    func moveImage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < images.count &&
              destinationIndex >= 0 && destinationIndex < images.count &&
              sourceIndex != destinationIndex else { return }

        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: destinationIndex)

        // Update order numbers
        for i in 0..<images.count {
            images[i].orderNumber = i
        }
    }

    func save() async {
        validateFields()

        guard isValid && !hasValidationErrors else {
            return
        }

        isSaving = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingItem = editingItem {
            // Update existing item
            var updatedItem = existingItem
            updatedItem.title = trimmedTitle
            updatedItem.itemDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
            updatedItem.quantity = quantity
            updatedItem.images = images
            updatedItem.updateModifiedDate()

            // Use the method that preserves all properties including images
            dataRepository.updateItem(updatedItem)
        } else {
            // Check if user selected a suggestion without making changes
            if let suggested = suggestedItem, !hasChangesFromSuggestion() {
                // User selected existing item without changes
                // Check if this item is already in the current list
                let currentListItems = dataRepository.getItems(for: list)

                if let existingItem = currentListItems.first(where: { $0.id == suggested.id }) {
                    // Item already in this list - uncross it (mark as active)
                    // This is an intentional action to "reactivate" a completed item
                    if existingItem.isCrossedOut {
                        var uncrossedItem = existingItem
                        uncrossedItem.isCrossedOut = false
                        uncrossedItem.updateModifiedDate()
                        dataRepository.updateItem(uncrossedItem)
                    }
                    // If item is already active (not crossed out), do nothing - user gets visual feedback that item exists
                } else {
                    // Add existing item to current list by creating a reference
                    // We create a new item with the same properties but assign to current list
                    var itemForCurrentList = suggested
                    itemForCurrentList.listId = list.id
                    itemForCurrentList.orderNumber = currentListItems.count
                    itemForCurrentList.updateModifiedDate()

                    // CRITICAL FIX: Use the deep-copied images from the view model
                    // to avoid Core Data conflicts with image IDs
                    itemForCurrentList.images = images

                    // Add to current list
                    dataRepository.addExistingItemToList(itemForCurrentList, listId: list.id)
                }
            } else {
                // User either didn't use suggestion OR made changes - create new item
                var newItem = dataRepository.createItem(
                    in: list,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    quantity: quantity
                )

                // Add images to the new item
                newItem.images = images
                newItem.updateModifiedDate()

                // Update the item with images using the method that preserves all properties
                dataRepository.updateItem(newItem)
            }
        }

        isSaving = false
    }
}
