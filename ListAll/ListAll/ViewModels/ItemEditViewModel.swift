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

    let list: List
    let editingItem: Item?
    let dataRepository: DataRepository
    var originalItem: Item?

    // Track suggested item for duplicate detection
    var suggestedItem: Item?
    var suggestedItemTitle: String?
    var suggestedItemDescription: String?
    var suggestedItemQuantity: Int?
    var suggestedItemImages: [ItemImage]?

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
}
