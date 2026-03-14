//
//  MacEditItemImageSection.swift
//  ListAllMac
//
//  Expandable image section for the edit item sheet, with thumbnail preview.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            headerButton

            // Add button - show when collapsed OR when expanded but empty
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
        .contentShape(Rectangle())
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
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                .frame(width: 12)

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
                    compactEmptyState
                } else {
                    MacImageGalleryView(
                        images: $images,
                        itemId: itemId,
                        itemTitle: itemTitle
                    )
                    .frame(minHeight: 150)
                    .padding(.top, 16)
                }
            } else {
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
