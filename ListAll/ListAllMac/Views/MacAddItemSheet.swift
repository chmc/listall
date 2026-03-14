//
//  MacAddItemSheet.swift
//  ListAllMac
//
//  Sheet view for adding a new item to a list.
//

import SwiftUI

struct MacAddItemSheet: View {
    let listId: UUID
    let onSave: (String, Int, String?) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var dataManager: DataManager

    @State private var title = ""
    @State private var quantity = 1
    @State private var description = ""

    // Suggestion state
    @StateObject private var suggestionService = SuggestionService()
    @State private var showingSuggestions = false
    @State private var showAllSuggestions = false

    /// Get the current list from DataManager for suggestions context
    private var currentList: List? {
        dataManager.lists.first(where: { $0.id == listId })
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Item")
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
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3))
                        .accessibilityIdentifier("ItemDescriptionEditor")
                }
            }
            .frame(width: 350)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .accessibilityHint("Discards changes")
                .accessibilityIdentifier("CancelButton")

                Button("Add") {
                    onSave(title, quantity, description.isEmpty ? nil : description)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves new item")
                .accessibilityIdentifier("AddItemButton")
            }
        }
        .padding(30)
        .frame(minWidth: 450)
        .accessibilityIdentifier("AddItemSheet")
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
    }

    // MARK: - Suggestion Handling

    private func handleTitleChange(_ newValue: String) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.count >= 2 {
            // Get suggestions from current list context
            suggestionService.getSuggestions(for: trimmedValue, in: currentList)
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

        // Hide suggestions
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
            showAllSuggestions = false
        }
        suggestionService.clearSuggestions()
    }
}
