//
//  MacQuickLookView.swift
//  ListAllMac
//
//  SwiftUI view modifier and helper for integrating Quick Look preview
//  with SwiftUI views on macOS.
//

import SwiftUI
import AppKit
import Quartz

// MARK: - Quick Look View Modifier

/// A view modifier that adds Quick Look preview capability to a view.
/// Responds to spacebar key press when the view is focused.
struct QuickLookPreviewModifier: ViewModifier {

    /// The item to preview (must have images)
    let item: Item?

    /// Whether Quick Look is enabled for this view
    let isEnabled: Bool

    /// Binding to track whether preview is showing
    @Binding var isShowingPreview: Bool

    /// The starting image index for multi-image items
    let startIndex: Int

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                guard isEnabled, let item = item, item.hasImages else {
                    return .ignored
                }

                isShowingPreview.toggle()

                if isShowingPreview {
                    QuickLookController.shared.preview(item: item, startIndex: startIndex)
                } else {
                    QuickLookController.shared.hidePreview()
                }

                return .handled
            }
            .onChange(of: isShowingPreview) { _, newValue in
                if !newValue && QuickLookController.shared.isPanelVisible {
                    QuickLookController.shared.hidePreview()
                }
            }
    }
}

// MARK: - View Extension

extension View {

    /// Adds Quick Look preview capability to the view.
    /// When the view is focused and spacebar is pressed, shows Quick Look preview.
    ///
    /// - Parameters:
    ///   - item: The item whose images to preview
    ///   - isEnabled: Whether Quick Look is enabled (default true)
    ///   - isShowing: Binding to track preview visibility
    ///   - startIndex: The index of the image to start with (default 0)
    /// - Returns: Modified view with Quick Look capability
    func quickLookPreview(
        item: Item?,
        isEnabled: Bool = true,
        isShowing: Binding<Bool>,
        startIndex: Int = 0
    ) -> some View {
        modifier(QuickLookPreviewModifier(
            item: item,
            isEnabled: isEnabled,
            isShowingPreview: isShowing,
            startIndex: startIndex
        ))
    }
}

// MARK: - Quick Look Button

/// A button that triggers Quick Look preview for an item's images.
struct QuickLookButton: View {

    /// The item to preview
    let item: Item

    /// Optional custom label
    var label: String?

    /// Optional custom system image
    var systemImage: String = "eye"

    var body: some View {
        Button(action: {
            QuickLookController.shared.preview(item: item)
        }) {
            if let label = label {
                Label(label, systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
            }
        }
        .disabled(!item.hasImages)
        .help(item.hasImages ? "Quick Look (Space)" : "No images to preview")
        .accessibilityLabel(label ?? "Quick Look")
        .accessibilityHint("Opens image preview")
    }
}

// MARK: - Quick Look Thumbnail View

/// A view that displays a thumbnail of an item's first image with Quick Look support.
struct QuickLookThumbnailView: View {

    /// The item to display thumbnail for
    let item: Item

    /// Size of the thumbnail
    var size: CGFloat = 40

    /// Corner radius
    var cornerRadius: CGFloat = 6

    @State private var isShowingPreview = false

    var body: some View {
        Group {
            if let firstImage = item.sortedImages.first,
               let nsImage = firstImage.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                    .onTapGesture(count: 2) {
                        QuickLookController.shared.preview(item: item)
                    }
                    .quickLookPreview(
                        item: item,
                        isShowing: $isShowingPreview
                    )
                    .help("Double-click or press Space to preview")
                    .accessibilityLabel("Image thumbnail")
                    .accessibilityHint("Double-tap or press Space to preview")

                    // Badge for multiple images (dark mode compatible)
                    .overlay(alignment: .bottomTrailing) {
                        if item.imageCount > 1 {
                            Text("\(item.imageCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial.opacity(0.9))
                                .background(Color(nsColor: .darkGray))
                                .clipShape(Capsule())
                                .offset(x: 2, y: 2)
                        }
                    }
            } else {
                // Placeholder when no images
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary.opacity(0.5))
                    )
            }
        }
    }
}

// MARK: - Image Preview Grid

/// A grid view displaying all images for an item with Quick Look support.
struct MacImagePreviewGrid: View {

    /// The item whose images to display
    let item: Item

    /// Size of each thumbnail
    var thumbnailSize: CGFloat = 60

    /// Spacing between thumbnails
    var spacing: CGFloat = 8

    /// Number of columns (0 for adaptive)
    var columns: Int = 0

    @State private var selectedImageIndex: Int = 0
    @State private var isShowingPreview = false

    private var gridColumns: [GridItem] {
        if columns > 0 {
            return Array(repeating: GridItem(.fixed(thumbnailSize), spacing: spacing), count: columns)
        } else {
            return [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize), spacing: spacing)]
        }
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(Array(item.sortedImages.enumerated()), id: \.element.id) { index, itemImage in
                ImageThumbnail(
                    itemImage: itemImage,
                    size: thumbnailSize,
                    isSelected: selectedImageIndex == index,
                    index: index
                )
                .onTapGesture {
                    selectedImageIndex = index
                }
                .onTapGesture(count: 2) {
                    selectedImageIndex = index
                    QuickLookController.shared.preview(item: item, startIndex: index)
                }
            }
        }
        .quickLookPreview(
            item: item,
            isShowing: $isShowingPreview,
            startIndex: selectedImageIndex
        )
    }
}

// MARK: - Image Thumbnail

/// A single image thumbnail view
private struct ImageThumbnail: View {

    let itemImage: ItemImage
    let size: CGFloat
    let isSelected: Bool
    let index: Int

    var body: some View {
        Group {
            if let nsImage = itemImage.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4)
        .accessibilityLabel("Image \(index + 1)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isImage] : [.isImage])
    }
}

// MARK: - Preview Provider

#Preview("Quick Look Thumbnail") {
    VStack(spacing: 20) {
        // Create test item with mock image
        let item = {
            var testItem = Item(title: "Test Item")
            // In preview, we don't have actual image data
            return testItem
        }()

        QuickLookThumbnailView(item: item)

        QuickLookButton(item: item, label: "Preview")
    }
    .padding()
    .frame(width: 200, height: 200)
}
