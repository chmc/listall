//
//  AppCommands.swift
//  ListAllMac
//
//  Created for macOS menu commands.
//

import SwiftUI

/// macOS-specific menu commands for ListAll
struct AppCommands: Commands {

    /// Environment to open windows by ID
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Replace the default New Item command group
        CommandGroup(replacing: .newItem) {
            Button("New List") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreateNewList"),
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Item") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreateNewItem"),
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)

            // Quick Entry (Task 12.10)
            // Opens a floating window for rapid item entry
            Button("Quick Entry") {
                openWindow(id: "quickEntry")
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickEntry"),
                    object: nil
                )
            }
            .keyboardShortcut(.space, modifiers: [.command, .option])

            Divider()
        }

        // Custom Lists menu
        CommandMenu("Lists") {
            Button("Archive List") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ArchiveSelectedList"),
                    object: nil
                )
            }
            .keyboardShortcut(.delete, modifiers: [.command])

            // MARK: - Restore Archived List (Task 13.1)
            Button("Restore List") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RestoreSelectedList"),
                    object: nil
                )
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Duplicate List") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DuplicateSelectedList"),
                    object: nil
                )
            }
            .keyboardShortcut("d", modifiers: [.command])

            Divider()

            Button("Share List...") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShareSelectedList"),
                    object: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Export All Lists...") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ExportAllLists"),
                    object: nil
                )
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

        }
        // Note: "Show Archived Lists" menu item removed - archived lists now always
        // visible in their own sidebar section (Apple HIG two-section pattern)

        // Custom View menu additions
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Refresh") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshData"),
                    object: nil
                )
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            // MARK: - Filter Shortcuts (Task 12.4)
            // Native macOS pattern: View menu with keyboard shortcuts for filters
            Button("All Items") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SetFilterAll"),
                    object: nil
                )
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Active Only") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SetFilterActive"),
                    object: nil
                )
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Completed Only") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SetFilterCompleted"),
                    object: nil
                )
            }
            .keyboardShortcut("3", modifiers: .command)
        }

        // Help menu
        CommandGroup(replacing: .help) {
            Button("ListAll Help") {
                // Open help documentation or website
                if let url = URL(string: "https://github.com/chmc/listall") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
