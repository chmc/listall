//
//  List+Transferable.swift
//  ListAll
//
//  Drag-and-drop support for List model on macOS.
//  Enables reordering lists in the sidebar via drag-and-drop.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType Extension

extension UTType {
    /// Custom uniform type identifier for ListAll lists (drag-and-drop on macOS)
    /// Registered as exported type in Info.plist
    static let listAllList = UTType(exportedAs: "io.github.chmc.ListAll.list")
}

// MARK: - Transfer Representation

/// Lightweight representation for drag-and-drop transfers.
/// Uses ID-only approach to avoid stale data - the full List is looked up
/// from DataManager when the drop occurs.
struct ListTransferData: Codable, Transferable {
    let listId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .listAllList)
    }
}

// MARK: - Transferable Conformance

extension List: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Use proxy representation to convert List to lightweight ListTransferData
        ProxyRepresentation { list in
            ListTransferData(listId: list.id)
        }
    }
}
#endif
