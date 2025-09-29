import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemEditViewModel
    @StateObject private var suggestionService = SuggestionService()
    @State private var showingDiscardAlert = false
    @State private var showingSuggestions = false
    
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
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.words)
                            .disableAutocorrection(false)
                            .onChange(of: viewModel.title) { newValue in
                                handleTitleChange(newValue)
                            }
                        
                        // Suggestions
                        if showingSuggestions && !suggestionService.suggestions.isEmpty {
                            SuggestionListView(suggestions: suggestionService.suggestions) { suggestion in
                                applySuggestion(suggestion)
                            }
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
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .stroke(Theme.Colors.secondary.opacity(0.3), lineWidth: 1)
                        )
                    
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
                    HStack {
                        Button(action: {
                            viewModel.decrementQuantity()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(viewModel.quantity > 1 ? Theme.Colors.primary : Theme.Colors.secondary)
                                .font(.title2)
                        }
                        .disabled(viewModel.quantity <= 1)
                        
                        Spacer()
                        
                        TextField("Quantity", value: $viewModel.quantity, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.incrementQuantity()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.primary)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                    
                    if viewModel.showQuantityError {
                        Text(viewModel.quantityErrorMessage)
                            .foregroundColor(Theme.Colors.error)
                            .font(Theme.Typography.caption)
                    }
                }
                
                // Images Section (Future Phase - placeholder for now)
                Section("Images") {
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(Theme.Colors.secondary)
                            Text("Image support coming soon")
                                .foregroundColor(Theme.Colors.secondary)
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.groupedBackground)
                        .cornerRadius(Theme.CornerRadius.md)
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
        .onAppear {
            viewModel.setupForEditing()
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
        viewModel.title = suggestion.title
        
        // If the suggestion has a description and the current description is empty, apply it
        if let suggestionDescription = suggestion.description,
           !suggestionDescription.isEmpty,
           viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.description = suggestionDescription
        }
        
        // Hide suggestions after applying
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
        }
        suggestionService.clearSuggestions()
    }
}

// MARK: - ItemEditViewModel

@MainActor
class ItemEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var quantity: Int = 1
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
        }
    }
    
    func incrementQuantity() {
        if quantity < Int.max {
            quantity += 1
        }
    }
    
    func decrementQuantity() {
        if quantity > 1 {
            quantity -= 1
        }
    }
    
    func validateFields() {
        showTitleError = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200
        showDescriptionError = description.count > 50000
        showQuantityError = quantity < 1
    }
    
    func save() async {
        validateFields()
        
        guard isValid && !hasValidationErrors else {
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let existingItem = editingItem {
                // Update existing item
                dataRepository.updateItem(
                    existingItem,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    quantity: quantity
                )
            } else {
                // Create new item
                let _ = dataRepository.createItem(
                    in: list,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    quantity: quantity
                )
            }
        } catch {
            errorMessage = "Failed to save item: \(error.localizedDescription)"
            showingErrorAlert = true
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
