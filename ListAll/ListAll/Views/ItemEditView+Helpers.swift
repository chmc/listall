import SwiftUI

// MARK: - Helper Methods
extension ItemEditView {
    func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.count >= 2 {
            // Phase 50: Exclude current item from suggestions when editing
            suggestionService.getSuggestions(for: trimmedValue, in: list, excludeItemId: editingItem?.id)
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = false
            }
            suggestionService.clearSuggestions()
        }
    }

    func applySuggestion(_ suggestion: ItemSuggestion) {
        // Ensure we're on the main thread for UI updates
        Task { @MainActor in
            // Apply ALL details from the suggestion (title, description, quantity, images)
            viewModel.applySuggestion(suggestion)

            // Update local quantity to reflect the suggested value
            localQuantity = suggestion.quantity

            // Hide suggestions after applying
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = false
                showAllSuggestions = false // Reset to collapsed state
            }
            suggestionService.clearSuggestions()

            // Focus on description field to let user review/edit the applied suggestion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // User can tap to edit any field they want to modify
            }
        }
    }

    // MARK: - Image Handling

    func handleImageSelection(_ image: UIImage) {
        // Process and add image using ImageService
        switch imageService.processImage(image) {
        case .success(let imageData):
            let itemImage = ItemImage(imageData: imageData, itemId: editingItem?.id)
            viewModel.addImage(itemImage)

        case .failure(let error):
            // Show error alert
            viewModel.errorMessage = error.localizedDescription
            viewModel.showingErrorAlert = true
        }
    }
}
