//
//  MacEditItemImageSection+Content.swift
//  ListAllMac
//
//  Image picker, thumbnail strip, expanded content, and drag-drop handling.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension MacEditItemImageSection {

    // MARK: - Image Picker

    func addImagesFromPicker() {
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

    // MARK: - Thumbnail Strip

    @ViewBuilder
    var thumbnailStrip: some View {
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

    var overflowBadge: some View {
        Text("+\(images.count - 4)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(width: 36, height: 36)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Expanded Content

    @ViewBuilder
    var expandedContent: some View {
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

    var compactEmptyState: some View {
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

    func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
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
