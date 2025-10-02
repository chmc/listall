import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemEditViewModel
    @StateObject private var suggestionService = SuggestionService()
    @StateObject private var imageService = ImageService.shared
    @State private var showingDiscardAlert = false
    @State private var showingSuggestions = false
    @State private var showAllSuggestions = false
    @State private var showingImageSourceSelection = false
    @State private var selectedImage: UIImage?
    @FocusState private var isTitleFieldFocused: Bool
    @FocusState private var isDescriptionFieldFocused: Bool
    @State private var localQuantity: Int = 1
    
    let list: List
    let editingItem: Item?
    
    init(list: List, item: Item? = nil) {
        self.list = list
        self.editingItem = item
        self._viewModel = StateObject(wrappedValue: ItemEditViewModel(list: list, item: item))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section("Item Title") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        TextField("Enter item name", text: $viewModel.title)
                            .textFieldStyle(.plain)
                            .autocapitalization(.sentences)
                            .disableAutocorrection(false)
                            .focused($isTitleFieldFocused)
                            .onChange(of: viewModel.title) { newValue in
                                handleTitleChange(newValue)
                            }
                        
                        // Suggestions with enhanced Phase 14 functionality
                        if showingSuggestions && !suggestionService.suggestions.isEmpty {
                            SuggestionListView(
                                suggestions: suggestionService.suggestions,
                                onSuggestionTapped: { suggestion in
                                    applySuggestion(suggestion)
                                },
                                showAllSuggestions: showAllSuggestions,
                                onShowAllToggled: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showAllSuggestions.toggle()
                                    }
                                }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                        }
                        
                        if viewModel.showTitleError {
                            Text(viewModel.titleErrorMessage)
                                .foregroundColor(Theme.Colors.error)
                                .font(Theme.Typography.caption)
                        }
                    }
                }
                
                // Description Section
                Section("Description (Optional)") {
                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 80, maxHeight: 200)
                        .focused($isDescriptionFieldFocused)
                    
                    Text("\(viewModel.description.count)/50,000 characters")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    if viewModel.showDescriptionError {
                        Text(viewModel.descriptionErrorMessage)
                            .foregroundColor(Theme.Colors.error)
                            .font(Theme.Typography.caption)
                    }
                }
                
                // Quantity Section
                Section("Quantity") {
                    VStack(spacing: Theme.Spacing.md) {
                        // Option 1: SwiftUI Stepper (Recommended)
                        HStack {
                            Text("Quantity")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Stepper(
                                value: $localQuantity,
                                in: 1...9999,
                                step: 1
                            ) {
                                Text("\(localQuantity)")
                                    .font(.title2)
                                    .fontWeight(.medium)
                            }
                            .onChange(of: localQuantity) { newValue in
                                viewModel.quantity = newValue
                            }
                        }
                        
                        // Option 2: Simplified Custom Buttons (Fallback)
                        // Uncomment if Stepper doesn't work:
                        /*
                        HStack {
                            Text("Quantity: \(localQuantity)")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button("-") {
                                    if localQuantity > 1 {
                                        localQuantity -= 1
                                        viewModel.quantity = localQuantity
                                    }
                                }
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                
                                Button("+") {
                                    if localQuantity < 9999 {
                                        localQuantity += 1
                                        viewModel.quantity = localQuantity
                                    }
                                }
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        */
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    
                    if viewModel.showQuantityError {
                        Text(viewModel.quantityErrorMessage)
                            .foregroundColor(Theme.Colors.error)
                            .font(Theme.Typography.caption)
                    }
                }
                
                // Images Section
                Section("Images") {
                    VStack(spacing: Theme.Spacing.md) {
                        // Add Image Button
                        Button(action: {
                            showingImageSourceSelection = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Theme.Colors.primary)
                                    .font(.title2)
                                
                                Text("Add Photo")
                                    .foregroundColor(Theme.Colors.primary)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: "camera.fill")
                                    .foregroundColor(Theme.Colors.secondary)
                                Image(systemName: "photo.fill")
                                    .foregroundColor(Theme.Colors.secondary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.groupedBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Display existing images
                        if !viewModel.images.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: Theme.Spacing.sm) {
                                ForEach(viewModel.images.indices, id: \.self) { index in
                                    ImageThumbnailView(
                                        itemImage: viewModel.images[index],
                                        onDelete: {
                                            viewModel.removeImage(at: index)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Image count and size info
                        if !viewModel.images.isEmpty {
                            HStack {
                                Image(systemName: "photo.stack")
                                    .foregroundColor(Theme.Colors.secondary)
                                Text("\(viewModel.images.count) image\(viewModel.images.count == 1 ? "" : "s")")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondary)
                                
                                Spacer()
                                
                                let totalSize = viewModel.images.compactMap { $0.imageData?.count }.reduce(0, +)
                                Text(imageService.formatFileSize(totalSize))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.hasUnsavedChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.isEditing ? "Save" : "Create") {
                        Task {
                            await viewModel.save()
                            if !viewModel.hasValidationErrors {
                                // Invalidate suggestion cache since we've added/modified an item
                                suggestionService.invalidateCacheForDataChanges()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields (both single and multi-line)
            isTitleFieldFocused = false
            isDescriptionFieldFocused = false
        }
        .onAppear {
            viewModel.setupForEditing()
            
            // Initialize local quantity from ViewModel
            localQuantity = viewModel.quantity
            
            // Focus the title field for all item edit screens (new and existing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFieldFocused = true
            }
        }
        .sheet(isPresented: $showingImageSourceSelection) {
            ImageSourceSelectionView(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                // Dismiss the image source selection sheet first
                showingImageSourceSelection = false
                
                // Then handle the image selection
                handleImageSelection(image)
                selectedImage = nil // Reset for next selection
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedValue.count >= 2 {
            suggestionService.getSuggestions(for: trimmedValue, in: list)
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
    
    private func applySuggestion(_ suggestion: ItemSuggestion) {
        // Phase 14 enhancement: Apply all available details from suggestion
        viewModel.title = suggestion.title
        
        // Apply description if available (user can overwrite if needed)
        if let suggestionDescription = suggestion.description,
           !suggestionDescription.isEmpty {
            // Only auto-fill if current description is empty, otherwise preserve user's work
            if viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.description = suggestionDescription
            }
        }
        
        // For Phase 14: We could add quantity suggestions here in the future
        // Currently quantity defaults to 1, which is reasonable
        
        // Hide suggestions after applying
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
            showAllSuggestions = false // Reset to collapsed state
        }
        suggestionService.clearSuggestions()
        
        // Focus on description field to let user review/edit the applied suggestion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // We could focus on description field here, but let's keep it simple for now
            // The user can tap to edit any field they want to modify
        }
    }
    
    // MARK: - Image Handling
    
    private func handleImageSelection(_ image: UIImage) {
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

// MARK: - ItemEditViewModel

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
    private let dataRepository = DataRepository()
    private var originalItem: Item?
    
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
    
    init(list: List, item: Item? = nil) {
        self.list = list
        self.editingItem = item
        self.originalItem = item
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
            // Create new item
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
        
        isSaving = false
    }
}

#Preview("New Item") {
    ItemEditView(list: List(name: "Sample List"))
}

#Preview("Edit Item") {
    let sampleItem = Item(title: "Sample Item")
    return ItemEditView(list: List(name: "Sample List"), item: sampleItem)
}
