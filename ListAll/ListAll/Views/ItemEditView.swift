import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ItemEditViewModel
    @StateObject var suggestionService = SuggestionService()
    @StateObject var imageService = ImageService.shared
    @StateObject var tooltipManager = TooltipManager.shared
    @State private var showingDiscardAlert = false
    @State var showingSuggestions = false
    @State var showAllSuggestions = false
    @State var showingImageSourceSelection = false
    @State private var selectedImage: UIImage?
    @FocusState var isTitleFieldFocused: Bool
    @FocusState var isDescriptionFieldFocused: Bool
    @State var localQuantity: Int = 1

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
                titleSection
                descriptionSection
                quantitySection
                imagesSection
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
}

#Preview("New Item") {
    ItemEditView(list: List(name: "Sample List"))
}

#Preview("Edit Item") {
    let sampleItem = Item(title: "Sample Item")
    return ItemEditView(list: List(name: "Sample List"), item: sampleItem)
}
