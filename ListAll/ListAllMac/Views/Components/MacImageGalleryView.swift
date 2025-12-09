//
//  MacImageGalleryView.swift
//  ListAllMac
//
//  A comprehensive image gallery component for managing item images.
//  Supports grid layout, drag-and-drop, copy/paste, Quick Look, and keyboard navigation.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Quartz

// MARK: - Main Gallery View

/// A gallery view for managing images attached to an item.
/// Uses controlled component pattern with @Binding for images array.
struct MacImageGalleryView: View {

    // MARK: - Properties

    /// Binding to the images array owned by parent
    @Binding var images: [ItemImage]

    /// The ID of the item these images belong to
    let itemId: UUID

    /// Title of the item (for Quick Look preview)
    let itemTitle: String

    // MARK: - State

    /// Currently selected image IDs
    @State private var selectedImageIDs: Set<UUID> = []

    /// Last selected image ID (for shift-click range selection)
    @State private var lastSelectedID: UUID?

    /// Thumbnail size (80-200px)
    @State private var thumbnailSize: CGFloat = 120

    /// Whether Quick Look preview is showing
    @State private var isShowingQuickLook = false

    /// ID of image being dragged for reordering
    @State private var draggedImageID: UUID?

    /// Whether view is currently a drop target
    @State private var isDropTargeted = false

    /// Status message to show user
    @State private var statusMessage: String?

    /// Whether status is an error
    @State private var isStatusError = false

    // MARK: - Computed Properties

    /// Images sorted by order number
    private var sortedImages: [ItemImage] {
        images.sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Selected images in order
    private var selectedImages: [ItemImage] {
        sortedImages.filter { selectedImageIDs.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        galleryContent
            .frame(minHeight: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(borderOverlay)
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleExternalDrop(providers: providers)
                return true
            }
            .focusable()
            .modifier(GalleryKeyboardModifier(
                hasSelection: !selectedImageIDs.isEmpty,
                onQuickLook: showQuickLookForSelected,
                onDelete: deleteSelectedImages,
                onSelectAll: selectAllImages,
                onCopy: copySelectedImages,
                onPaste: pasteImages
            ))
    }

    // MARK: - Content Views

    @ViewBuilder
    private var galleryContent: some View {
        VStack(spacing: 0) {
            MacImageGalleryToolbar(
                imageCount: images.count,
                selectedCount: selectedImageIDs.count,
                thumbnailSize: $thumbnailSize,
                onAddImages: addImagesFromPicker,
                onDeleteSelected: deleteSelectedImages,
                onQuickLook: showQuickLookForSelected,
                canDelete: !selectedImageIDs.isEmpty,
                canQuickLook: !selectedImageIDs.isEmpty
            )

            Divider()

            contentArea

            statusBar
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if images.isEmpty {
            MacImageGalleryEmptyState(isDropTargeted: isDropTargeted)
        } else {
            MacImageGalleryGrid(
                images: sortedImages,
                selectedImageIDs: selectedImageIDs,
                thumbnailSize: thumbnailSize,
                draggedImageID: draggedImageID,
                onSelect: handleImageSelection,
                onDoubleClick: showQuickLook,
                onDragStarted: { draggedImageID = $0 },
                onDragEnded: { draggedImageID = nil },
                onReorder: reorderImage
            )
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        if let message = statusMessage {
            HStack {
                Image(systemName: isStatusError ? "exclamationmark.triangle" : "checkmark.circle")
                    .foregroundColor(isStatusError ? .orange : .green)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
    }

    // MARK: - Selection Handling

    /// Handles image selection with modifier key support
    private func handleImageSelection(_ imageID: UUID, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            // Cmd+click: Toggle selection
            toggleSelection(imageID)
        } else if modifiers.contains(.shift), let lastID = lastSelectedID {
            // Shift+click: Range selection
            selectRange(from: lastID, to: imageID)
        } else {
            // Single click: Select only this image
            selectedImageIDs = [imageID]
            lastSelectedID = imageID
        }
    }

    /// Toggles selection of a single image
    private func toggleSelection(_ imageID: UUID) {
        if selectedImageIDs.contains(imageID) {
            selectedImageIDs.remove(imageID)
        } else {
            selectedImageIDs.insert(imageID)
            lastSelectedID = imageID
        }
    }

    /// Selects a range of images
    private func selectRange(from startID: UUID, to endID: UUID) {
        let imageIDs = sortedImages.map { $0.id }
        guard let startIndex = imageIDs.firstIndex(of: startID),
              let endIndex = imageIDs.firstIndex(of: endID) else {
            return
        }

        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        selectedImageIDs = Set(imageIDs[range])
        lastSelectedID = endID
    }

    /// Selects all images
    private func selectAllImages() {
        selectedImageIDs = Set(images.map { $0.id })
        showStatus("Selected all \(images.count) images")
    }

    // MARK: - Image Operations

    /// Opens file picker to add images
    private func addImagesFromPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .tiff, .gif]
        panel.message = "Select images to add"

        panel.begin { response in
            guard response == .OK else { return }

            Task {
                var addedCount = 0
                for url in panel.urls {
                    if let image = NSImage(contentsOf: url) {
                        await addImage(image)
                        addedCount += 1
                    }
                }

                if addedCount > 0 {
                    showStatus("Added \(addedCount) image\(addedCount == 1 ? "" : "s")")
                }
            }
        }
    }

    /// Adds a single NSImage to the gallery
    @MainActor
    private func addImage(_ nsImage: NSImage) async {
        guard let itemImage = ImageService.shared.createItemImage(from: nsImage, itemId: itemId) else {
            showStatus("Failed to process image", isError: true)
            return
        }

        var newImage = itemImage
        newImage.orderNumber = images.count
        images.append(newImage)
    }

    /// Deletes selected images
    private func deleteSelectedImages() {
        let countToDelete = selectedImageIDs.count
        images.removeAll { selectedImageIDs.contains($0.id) }

        // Update order numbers
        for index in images.indices {
            images[index].orderNumber = index
        }

        selectedImageIDs.removeAll()
        lastSelectedID = nil

        showStatus("Deleted \(countToDelete) image\(countToDelete == 1 ? "" : "s")")
    }

    /// Reorders an image from one position to another
    private func reorderImage(from sourceID: UUID, to targetID: UUID) {
        guard let sourceIndex = images.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = images.firstIndex(where: { $0.id == targetID }),
              sourceIndex != targetIndex else {
            return
        }

        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: targetIndex)

        // Update order numbers
        for index in images.indices {
            images[index].orderNumber = index
        }
    }

    // MARK: - Drop Handling

    /// Handles external image drops from Finder
    private func handleExternalDrop(providers: [NSItemProvider]) {
        Task {
            var addedCount = 0

            for provider in providers {
                // Try file URL first (Finder)
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    if let image = await loadImageFromFileProvider(provider) {
                        await addImage(image)
                        addedCount += 1
                    }
                }
                // Try direct image
                else if provider.canLoadObject(ofClass: NSImage.self) {
                    if let image = await loadDirectImage(from: provider) {
                        await addImage(image)
                        addedCount += 1
                    }
                }
            }

            if addedCount > 0 {
                showStatus("Added \(addedCount) image\(addedCount == 1 ? "" : "s")")
            }
        }
    }

    /// Loads image from file URL provider
    private func loadImageFromFileProvider(_ provider: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url else {
                    continuation.resume(returning: nil)
                    return
                }

                // Handle security-scoped resource
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let image = NSImage(contentsOf: url)
                continuation.resume(returning: image)
            }
        }
    }

    /// Loads direct NSImage from provider
    private func loadDirectImage(from provider: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSImage.self) { image, error in
                continuation.resume(returning: image as? NSImage)
            }
        }
    }

    // MARK: - Clipboard Operations

    /// Copies selected images to clipboard
    private func copySelectedImages() {
        guard !selectedImages.isEmpty else { return }

        let nsImages = selectedImages.compactMap { $0.nsImage }
        guard !nsImages.isEmpty else {
            showStatus("No valid images to copy", isError: true)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(nsImages)

        showStatus("Copied \(nsImages.count) image\(nsImages.count == 1 ? "" : "s")")
    }

    /// Pastes images from clipboard
    private func pasteImages() {
        let pasteboard = NSPasteboard.general

        guard let nsImages = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
              !nsImages.isEmpty else {
            showStatus("No images on clipboard", isError: true)
            return
        }

        Task {
            for nsImage in nsImages {
                await addImage(nsImage)
            }
            showStatus("Pasted \(nsImages.count) image\(nsImages.count == 1 ? "" : "s")")
        }
    }

    // MARK: - Quick Look

    /// Shows Quick Look for a specific image
    private func showQuickLook(for imageID: UUID) {
        guard let index = sortedImages.firstIndex(where: { $0.id == imageID }) else { return }

        // Create temporary item for Quick Look
        var tempItem = Item(title: itemTitle)
        tempItem.images = sortedImages

        QuickLookController.shared.preview(item: tempItem, startIndex: index)
    }

    /// Shows Quick Look for selected images
    private func showQuickLookForSelected() {
        guard let firstSelectedID = selectedImages.first?.id else { return }
        showQuickLook(for: firstSelectedID)
    }

    // MARK: - Status Messages

    /// Shows a status message that auto-dismisses
    private func showStatus(_ message: String, isError: Bool = false) {
        withAnimation {
            statusMessage = message
            isStatusError = isError
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                if statusMessage == message {
                    statusMessage = nil
                }
            }
        }
    }
}

// MARK: - Toolbar

/// Toolbar with gallery actions
private struct MacImageGalleryToolbar: View {
    let imageCount: Int
    let selectedCount: Int
    @Binding var thumbnailSize: CGFloat
    let onAddImages: () -> Void
    let onDeleteSelected: () -> Void
    let onQuickLook: () -> Void
    let canDelete: Bool
    let canQuickLook: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Add button
            Button(action: onAddImages) {
                Label("Add", systemImage: "plus")
            }
            .help("Add images (drag & drop or click)")

            // Delete button
            Button(action: onDeleteSelected) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!canDelete)
            .help("Delete selected images (Delete key)")

            // Quick Look button
            Button(action: onQuickLook) {
                Label("Preview", systemImage: "eye")
            }
            .disabled(!canQuickLook)
            .help("Quick Look preview (Space)")

            Spacer()

            // Selection info
            Text(selectionText)
                .font(.caption)
                .foregroundColor(.secondary)

            // Size slider
            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $thumbnailSize, in: 80...200, step: 20)
                    .frame(width: 100)

                Image(systemName: "square.grid.2x2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .help("Thumbnail size")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var selectionText: String {
        if selectedCount > 0 {
            return "\(selectedCount) of \(imageCount) selected"
        } else {
            return "\(imageCount) image\(imageCount == 1 ? "" : "s")"
        }
    }
}

// MARK: - Grid View

/// Grid layout for image thumbnails
private struct MacImageGalleryGrid: View {
    let images: [ItemImage]
    let selectedImageIDs: Set<UUID>
    let thumbnailSize: CGFloat
    let draggedImageID: UUID?
    let onSelect: (UUID, EventModifiers) -> Void
    let onDoubleClick: (UUID) -> Void
    let onDragStarted: (UUID) -> Void
    let onDragEnded: () -> Void
    let onReorder: (UUID, UUID) -> Void

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(images) { image in
                    MacImageThumbnailCell(
                        image: image,
                        size: thumbnailSize,
                        isSelected: selectedImageIDs.contains(image.id),
                        isDragging: draggedImageID == image.id,
                        onSelect: onSelect,
                        onDoubleClick: onDoubleClick
                    )
                    .onDrag {
                        onDragStarted(image.id)
                        return NSItemProvider(object: image.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ImageReorderDropDelegate(
                        imageID: image.id,
                        draggedImageID: draggedImageID,
                        onReorder: onReorder,
                        onDragEnded: onDragEnded
                    ))
                }
            }
            .padding()
        }
    }
}

/// Drop delegate for image reordering
private struct ImageReorderDropDelegate: DropDelegate {
    let imageID: UUID
    let draggedImageID: UUID?
    let onReorder: (UUID, UUID) -> Void
    let onDragEnded: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedImageID, draggedID != imageID else { return }
        onReorder(draggedID, imageID)
    }

    func performDrop(info: DropInfo) -> Bool {
        onDragEnded()
        return true
    }
}

// MARK: - Thumbnail Cell

/// Individual thumbnail cell with async thumbnail loading for performance
private struct MacImageThumbnailCell: View {
    let image: ItemImage
    let size: CGFloat
    let isSelected: Bool
    let isDragging: Bool
    let onSelect: (UUID, EventModifiers) -> Void
    let onDoubleClick: (UUID) -> Void

    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Image or placeholder - use cached thumbnail for performance
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Loading/placeholder state
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
            }
        }
        .task(id: image.id) {
            // Load thumbnail asynchronously using ImageService cache
            await loadThumbnail()
        }
        .opacity(isDragging ? 0.5 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick(image.id)
        }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.command)
                .onEnded { _ in
                    onSelect(image.id, .command)
                }
        )
        .simultaneousGesture(
            TapGesture()
                .modifiers(.shift)
                .onEnded { _ in
                    onSelect(image.id, .shift)
                }
        )
        .onTapGesture {
            onSelect(image.id, [])
        }
        .contextMenu {
            Button("Quick Look") {
                onDoubleClick(image.id)
            }
            .keyboardShortcut(.space, modifiers: [])

            Divider()

            Button("Select") {
                onSelect(image.id, [])
            }
        }
    }

    // MARK: - Async Thumbnail Loading

    /// Loads thumbnail asynchronously using ImageService cache for performance
    private func loadThumbnail() async {
        // Capture values needed for background processing
        let imageData = image.imageData
        let thumbnailSize = CGSize(width: size * 2, height: size * 2) // 2x for retina

        // Run image processing off the main thread
        let loadedThumbnail = await Task.detached(priority: .userInitiated) {
            guard let data = imageData else { return nil as NSImage? }

            // Use ImageService's cached thumbnail creation
            return await ImageService.shared.createThumbnail(from: data, size: thumbnailSize)
        }.value

        // Update UI on main thread with no implicit animation
        // Using withTransaction prevents layout recursion by ensuring
        // state changes don't trigger concurrent animation passes
        await MainActor.run {
            withTransaction(Transaction(animation: nil)) {
                self.thumbnail = loadedThumbnail
                self.isLoading = false
            }
        }
    }
}

// MARK: - Empty State

/// Empty state view with drop zone
private struct MacImageGalleryEmptyState: View {
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(isDropTargeted ? .accentColor : .secondary)

            Text("No Images")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Drop images here, paste with ⌘V, or click Add")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
        .padding()
    }
}

// MARK: - Keyboard Modifier

/// ViewModifier to handle keyboard shortcuts for the gallery
/// Extracted to help Swift type-checker with complex view bodies
private struct GalleryKeyboardModifier: ViewModifier {
    let hasSelection: Bool
    let onQuickLook: () -> Void
    let onDelete: () -> Void
    let onSelectAll: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                if hasSelection {
                    onQuickLook()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if hasSelection {
                    onDelete()
                    return .handled
                }
                return .ignored
            }
    }
}

// MARK: - Preview

#Preview("Gallery with Images") {
    struct PreviewWrapper: View {
        @State private var images: [ItemImage] = {
            var imgs: [ItemImage] = []
            for i in 0..<6 {
                var img = ItemImage(imageData: nil, itemId: UUID())
                img.orderNumber = i
                imgs.append(img)
            }
            return imgs
        }()

        var body: some View {
            MacImageGalleryView(
                images: $images,
                itemId: UUID(),
                itemTitle: "Test Item"
            )
            .frame(width: 500, height: 400)
        }
    }

    return PreviewWrapper()
}

#Preview("Empty Gallery") {
    struct PreviewWrapper: View {
        @State private var images: [ItemImage] = []

        var body: some View {
            MacImageGalleryView(
                images: $images,
                itemId: UUID(),
                itemTitle: "Test Item"
            )
            .frame(width: 500, height: 400)
        }
    }

    return PreviewWrapper()
}
