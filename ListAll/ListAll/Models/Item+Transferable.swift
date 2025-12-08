//
//  Item+Transferable.swift
//  ListAll
//
//  Drag-and-drop support for Item model on macOS.
//  Enables dragging items between lists and reordering within lists.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType Extension

extension UTType {
    /// Custom uniform type identifier for ListAll items (drag-and-drop on macOS)
    /// Registered as exported type in Info.plist
    static let listAllItem = UTType(exportedAs: "io.github.chmc.ListAll.item")
}

// MARK: - Transfer Representation

/// Lightweight representation for drag-and-drop transfers.
/// Uses ID-only approach to avoid stale data - the full Item is looked up
/// from DataManager when the drop occurs.
struct ItemTransferData: Codable, Transferable {
    let itemId: UUID
    let sourceListId: UUID?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .listAllItem)
    }
}

// MARK: - Transferable Conformance

extension Item: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Use proxy representation to convert Item to lightweight ItemTransferData
        ProxyRepresentation { item in
            ItemTransferData(
                itemId: item.id,
                sourceListId: item.listId
            )
        }
    }
}
#endif
