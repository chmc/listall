//
//  MacItemSheets.swift
//  ListAllMac
//
//  Sheet views for adding, editing items and managing item images.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Quartz

/// Thread-safe wrapper to pass NSImage across isolation boundaries
private struct SendableImage: @unchecked Sendable {
    let image: NSImage?
}

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

// MARK: - Edit Item Sheet

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

// MARK: - Edit List Sheet

struct MacEditListSheet: View {
    let list: List
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String

    init(list: List, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.list = list
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: list.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit List")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            TextField("List Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .accessibilityLabel("List name")
                .accessibilityIdentifier("ListNameTextField")
                .onSubmit {
                    if !name.isEmpty {
                        onSave(name)
                    }
                }

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .accessibilityHint("Discards changes")
                .accessibilityIdentifier("CancelButton")

                Button("Save") {
                    onSave(name)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves changes")
                .accessibilityIdentifier("SaveButton")
            }
        }
        .padding(30)
        .frame(minWidth: 350)
        .accessibilityIdentifier("EditListSheet")
    }
}

// MARK: - Edit Item Image Section

/// Custom expandable image section with larger click target and thumbnail preview
/// Shows thumbnail strip when collapsed for better UX
struct MacEditItemImageSection: View {
    @Binding var images: [ItemImage]
    @Binding var isExpanded: Bool
    let isGalleryReady: Bool
    let itemId: UUID
    let itemTitle: String

    @State private var isHovering = false
    @State private var isAddButtonHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            expandedContent
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            // Toggle button for expand/collapse - main clickable area
            headerButton

            // Add button - show when collapsed OR when expanded but empty
            // When expanded with images, the gallery toolbar has its own Add button
            if !isExpanded || images.isEmpty {
                addButton
            }
        }
    }

    private var headerButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            headerContent
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle()) // Ensure entire area is clickable
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Images section")
        .accessibilityValue(isExpanded ? "expanded, \(images.count) images" : "collapsed, \(images.count) images")
        .accessibilityHint("Double-tap to \(isExpanded ? "collapse" : "expand")")
        .accessibilityAddTraits(.isButton)
    }

    private var addButton: some View {
        Button(action: addImagesFromPicker) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(isAddButtonHovering ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isAddButtonHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isAddButtonHovering = hovering
        }
        .help("Add images")
        .accessibilityLabel("Add images")
        .padding(.trailing, 8)
    }

    private var headerContent: some View {
        HStack(spacing: 8) {
            // Rotating chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                .frame(width: 12)

            // Label with count
            Text("Images")
                .font(.caption)
                .foregroundColor(.secondary)

            if !images.isEmpty {
                Text("(\(images.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Thumbnail strip when collapsed (shows first 4 images)
            if !isExpanded && isGalleryReady {
                thumbnailStrip
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Image Picker

    private func addImagesFromPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .tiff, .gif]
        panel.message = "Select images to add"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    var newImage = ItemImage(imageData: data, itemId: itemId)
                    newImage.orderNumber = images.count
                    images.append(newImage)
                }
            }
            // Auto-expand section after adding images
            if !images.isEmpty && !isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnailStrip: some View {
        HStack(spacing: 4) {
            if images.isEmpty {
                Text("No images")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(images.prefix(4)) { image in
                    CollapsedThumbnailView(image: image)
                }
                if images.count > 4 {
                    overflowBadge
                }
            }
        }
        .frame(minWidth: 40, alignment: .trailing)
    }

    private var overflowBadge: some View {
        Text("+\(images.count - 4)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(width: 36, height: 36)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var expandedContent: some View {
        if isExpanded {
            if isGalleryReady {
                if images.isEmpty {
                    // Compact empty state - no large placeholder
                    compactEmptyState
                } else {
                    // Show gallery only when there are images
                    MacImageGalleryView(
                        images: $images,
                        itemId: itemId,
                        itemTitle: itemTitle
                    )
                    .frame(minHeight: 150)
                    .padding(.top, 16)
                }
            } else {
                // Loading state
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 44)
                .padding(.leading, 20)
            }
        }
    }

    private var compactEmptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.body)
                .foregroundStyle(.tertiary)
            Text("No images - drag files here or click +")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.quaternary)
        )
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            handleImageDrop(providers)
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            var newImage = ItemImage(imageData: data, itemId: itemId)
                            newImage.orderNumber = images.count
                            images.append(newImage)
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Collapsed Thumbnail View

/// Small thumbnail view for the collapsed image section header
/// Shows a 36x36pt preview of an image with async loading
struct CollapsedThumbnailView: View {
    let image: ItemImage
    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    private let size: CGFloat = 36

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if isLoading {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let imageData = image.imageData else {
            await MainActor.run { isLoading = false }
            return
        }

        // Generate small thumbnail on background thread
        let thumbnailSize = CGSize(width: size * 2, height: size * 2) // 2x for retina
        // Use SendableImage wrapper to avoid NSImage crossing isolation boundaries
        let loadedThumbnail = await Task.detached(priority: .userInitiated) {
            let result = await ImageService.shared.createThumbnailAsync(from: imageData, size: thumbnailSize)
            return SendableImage(image: result)
        }.value.image

        await MainActor.run {
            withTransaction(Transaction(animation: nil)) {
                self.thumbnail = loadedThumbnail
                self.isLoading = false
            }
        }
    }
}

