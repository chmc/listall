//
//  MacCollapsedThumbnailView.swift
//  ListAllMac
//
//  Small thumbnail view for the collapsed image section header.
//

import SwiftUI
import AppKit

/// Thread-safe wrapper to pass NSImage across isolation boundaries
private struct SendableImage: @unchecked Sendable {
    let image: NSImage?
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
