import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemEditViewModel
    @StateObject private var suggestionService = SuggestionService()
    @StateObject private var imageService = ImageService.shared
    @StateObject private var tooltipManager = TooltipManager.shared
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
                            .onAppear {
                                // Show tooltip when suggestions first appear
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    tooltipManager.showIfNeeded(.itemSuggestions)
                                }
                            }
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
                // Task 16.13: Show explicit 10-image limit with visual feedback
                Section("Images") {
                    VStack(spacing: Theme.Spacing.md) {
                        // Add Image Button - disabled at 10 image limit
                        let isAtImageLimit = viewModel.images.count >= 10
                        Button(action: {
                            showingImageSourceSelection = true
                        }) {
                            HStack {
                                Image(systemName: isAtImageLimit ? "exclamationmark.circle.fill" : "plus.circle.fill")
                                    .foregroundColor(isAtImageLimit ? Theme.Colors.secondary : Theme.Colors.primary)
                                    .font(.title2)

                                Text(isAtImageLimit ? String(localized: "Image Limit Reached") : String(localized: "Add Photo"))
                                    .foregroundColor(isAtImageLimit ? Theme.Colors.secondary : Theme.Colors.primary)
                                    .font(.headline)

                                Spacer()

                                // Show count/limit indicator
                                Text("\(viewModel.images.count)/10")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(viewModel.images.count >= 8 ? .orange : Theme.Colors.secondary)
                                    .padding(.horizontal, Theme.Spacing.xs)

                                if !isAtImageLimit {
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(Theme.Colors.secondary)
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(Theme.Colors.secondary)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.groupedBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isAtImageLimit)
                        
                        // Display existing images with reordering arrows
                        if !viewModel.images.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Use arrows to reorder images")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: Theme.Spacing.sm) {
                                    ForEach(viewModel.images.indices, id: \.self) { index in
                                        DraggableImageThumbnailView(
                                            itemImage: viewModel.images[index],
                                            index: index,
                                            totalImages: viewModel.images.count,
                                            onDelete: {
                                                viewModel.removeImage(at: index)
                                            },
                                            onMove: { fromIndex, toIndex in
                                                viewModel.moveImage(from: fromIndex, to: toIndex)
                                            }
                                        )
                                    }
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
                    .foregroundColor(Theme.Colors.primary)
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .accessibilityIdentifier(viewModel.isEditing ? "SaveButton" : "CreateButton")
                }
            }
            .confirmationDialog("Discard Changes?", isPresented: $showingDiscardAlert, titleVisibility: .visible) {
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
        .onChange(of: isTitleFieldFocused) { isFocused in
            // Hide suggestions when title field loses focus (Phase 51)
            if !isFocused {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSuggestions = false
                    showAllSuggestions = false
                }
            }
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
    
    private func applySuggestion(_ suggestion: ItemSuggestion) {
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

#Preview("New Item") {
    ItemEditView(list: List(name: "Sample List"))
}

#Preview("Edit Item") {
    let sampleItem = Item(title: "Sample Item")
    return ItemEditView(list: List(name: "Sample List"), item: sampleItem)
}
