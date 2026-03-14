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

    @State var isHovering = false
    @State var isAddButtonHovering = false

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
}
