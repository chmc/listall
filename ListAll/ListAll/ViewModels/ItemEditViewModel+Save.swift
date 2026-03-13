import SwiftUI

// MARK: - Save
extension ItemEditViewModel {
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
