//
//  MacEditItemSheet.swift
//  ListAllMac
//
//  Sheet view for editing an existing item.
//

import SwiftUI

struct MacEditItemSheet: View {
    let item: Item
    let onSave: (String, Int, String?, [ItemImage]) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var dataManager: DataManager

    @State private var title: String
    @State private var quantity: Int
    @State private var description: String
    @State private var images: [ItemImage]

    // Defer gallery loading to allow sheet to appear faster
    // The gallery is the heaviest component - loading it after initial layout
    // significantly reduces perceived delay when opening the edit sheet
    @State private var isGalleryReady = false

    // Image section expansion state - collapsed by default, expanded when images exist
    @State private var isImageSectionExpanded = false

    // Suggestion state
    @StateObject private var suggestionService = SuggestionService()
    @State private var showingSuggestions = false

    /// Get the current list from DataManager for suggestions context
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == item.listId })
    }

    init(item: Item, onSave: @escaping (String, Int, String?, [ItemImage]) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: item.title)
        _quantity = State(initialValue: item.quantity)
        _description = State(initialValue: item.itemDescription ?? "")
        // CRITICAL: Initialize images as empty to defer heavy copy operation
        // The gallery will load them asynchronously after sheet appears
        _images = State(initialValue: [])
        // Defer the actual image loading to after sheet is visible
        _isGalleryReady = State(initialValue: false)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Item")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                // Title field with suggestions
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Item name")
                        .accessibilityIdentifier("ItemNameTextField")
                        .onChange(of: title) { _, newValue in
                            handleTitleChange(newValue)
                        }

                    // Suggestions
                    if showingSuggestions && !suggestionService.suggestions.isEmpty {
                        MacSuggestionListView(
                            suggestions: suggestionService.suggestions,
                            onSuggestionTapped: applySuggestion
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                HStack {
                    Text("\(String(localized: "Quantity")):")
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(width: 40)
                    }
                    .accessibilityIdentifier("ItemQuantityStepper")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(localized: "Notes")) (\(String(localized: "optional"))):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(minHeight: 80, idealHeight: 120, maxHeight: 200)
                        .border(Color.secondary.opacity(0.3))
                        .accessibilityIdentifier("ItemDescriptionEditor")
                }

                // Image Gallery Section - custom expandable with larger click target
                MacEditItemImageSection(
                    images: $images,
                    isExpanded: $isImageSectionExpanded,
                    isGalleryReady: isGalleryReady,
                    itemId: item.id,
                    itemTitle: item.title
                )
                .padding(.bottom, isImageSectionExpanded ? 12 : 0)
            }
            .frame(width: 450)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .accessibilityHint("Discards changes")
                .accessibilityIdentifier("CancelButton")

                Button("Save") {
                    onSave(title, quantity, description.isEmpty ? nil : description, images)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves changes")
                .accessibilityIdentifier("SaveButton")
            }
        }
        .padding(30)
        .frame(minWidth: 500)
        .accessibilityIdentifier("EditItemSheet")
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
        .onAppear {
            // Defer gallery loading until after sheet animation completes
            // This makes the sheet appear much faster by splitting the work:
            // 1. Sheet appears immediately with placeholder
            // 2. On next run loop cycle, load images
            // 3. Gallery renders progressively without blocking sheet presentation
            DispatchQueue.main.async {
                // Use withTransaction to disable implicit animations during load
                // This prevents animation conflicts that cause layout recursion
                withTransaction(Transaction(animation: nil)) {
                    // Load actual images from item
                    self.images = item.images
                    // Enable gallery rendering
                    isGalleryReady = true
                    // Keep image section collapsed by default
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isImageSectionExpanded)
    }

    // MARK: - Suggestion Handling

    private func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.count >= 2 {
            // Get suggestions, excluding the current item being edited
            suggestionService.getSuggestions(for: trimmedValue, in: currentList, excludeItemId: item.id)
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
        // Apply suggestion data
        title = suggestion.title
        quantity = suggestion.quantity
        if let desc = suggestion.description {
            description = desc
        }
        // Note: Images are NOT copied from suggestions in edit mode
        // to preserve the current item's images

        // Hide suggestions
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
        }
        suggestionService.clearSuggestions()
    }
}
