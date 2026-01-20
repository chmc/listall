//
//  MacEmptyStateView.swift
//  ListAllMac
//
//  Enhanced empty state views for macOS with sample list templates and feature highlights.
//  Provides the same onboarding experience as the iOS app.
//

import SwiftUI
import AppKit

// MARK: - Lists Empty State View

/// Empty state view for lists screen with engaging design and quick start options.
/// macOS equivalent of iOS ListsEmptyStateView.
struct MacListsEmptyStateView: View {
    let onCreateSampleList: (SampleDataService.SampleListTemplate) -> Void
    let onCreateCustomList: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon with subtle animation
                Image(systemName: Constants.UI.listIcon)
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.top, 32)
                    .accessibilityHidden(true)

                // Welcome message
                VStack(spacing: 8) {
                    Text(String(localized: "Welcome to ListAll"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "Organize everything in one place"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Sample list templates
                VStack(spacing: 12) {
                    Text(String(localized: "Get Started with a Template"))
                        .font(.headline)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.top, 8)

                    ForEach(SampleDataService.templates, id: \.name) { template in
                        MacSampleListButton(template: template) {
                            onCreateSampleList(template)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Divider with "or" text
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text(String(localized: "or"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)

                // Create custom list button
                Button(action: onCreateCustomList) {
                    HStack(spacing: 8) {
                        Image(systemName: Constants.UI.addIcon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(String(localized: "Create Custom List"))
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 350)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens sheet to create new list")
                .padding(.horizontal, 16)

                // Feature highlights
                VStack(spacing: 12) {
                    Text(String(localized: "ListAll Features"))
                        .font(.headline)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.top, 16)

                    MacFeatureHighlight(
                        icon: "photo",
                        title: String(localized: "Add Photos"),
                        description: String(localized: "Attach images to your items")
                    )

                    MacFeatureHighlight(
                        icon: "arrow.left.arrow.right",
                        title: String(localized: "Share & Sync"),
                        description: String(localized: "Share lists with family and friends")
                    )

                    MacFeatureHighlight(
                        icon: "wand.and.stars",
                        title: String(localized: "Smart Suggestions"),
                        description: String(localized: "Get intelligent item recommendations")
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 450)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Sample List Button

/// Button for creating a sample list from a template.
/// macOS-native styling with hover effects.
struct MacSampleListButton: View {
    let template: SampleDataService.SampleListTemplate
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .cornerRadius(6)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isHovering ? Theme.Colors.primary.opacity(0.5) : Theme.Colors.primary.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("\(template.name) template")
        .accessibilityHint("Creates a new list with sample \(template.name.lowercased()) items")
    }
}

// MARK: - Feature Highlight

/// Feature highlight row for the empty state.
/// Shows an icon, title, and description.
struct MacFeatureHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - No List Selected Empty State

/// Simple empty state shown when no list is selected in the sidebar.
/// Used as a placeholder in the detail view.
struct MacNoListSelectedView: View {
    let onCreateList: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text("No List Selected")
                .font(.title2)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text("Select a list from the sidebar or create a new one.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create New List") {
                onCreateList()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens sheet to create new list")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Items Empty State View

/// Empty state view for items list with usage tips.
/// macOS equivalent of iOS ItemsEmptyStateView.
struct MacItemsEmptyStateView: View {
    let hasItems: Bool
    let isArchived: Bool
    let onAddItem: () -> Void

    init(hasItems: Bool, isArchived: Bool = false, onAddItem: @escaping () -> Void) {
        self.hasItems = hasItems
        self.isArchived = isArchived
        self.onAddItem = onAddItem
    }

    var body: some View {
        VStack(spacing: 20) {
            if hasItems {
                // All items crossed out - celebration state
                if isArchived {
                    archivedCelebrationState
                } else {
                    celebrationState
                }
            } else if isArchived {
                // Archived list with no items - read-only state
                archivedEmptyState
            } else {
                // No items yet - helpful state
                helpfulState
            }
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var archivedEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "Empty Archived List"))
                .font(.title2)

            Text(String(localized: "This archived list has no items. Restore it to add items."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var archivedCelebrationState: some View {
        VStack(spacing: 20) {
            // Celebration icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.success.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.success)
            }
            .accessibilityHidden(true)

            Text(String(localized: "All Done!"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "All items in this archived list were completed."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var celebrationState: some View {
        VStack(spacing: 20) {
            // Celebration icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.success.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.success)
            }
            .accessibilityHidden(true)

            Text(String(localized: "All Done!"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "You've completed all items in this list."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "What's next?"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "eye", text: String(localized: "Toggle the eye icon to see completed items"))
                MacTipRow(icon: "plus.circle", text: String(localized: "Add more items to continue"))
                MacTipRow(icon: "arrow.left", text: String(localized: "Go back to view your other lists"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    @ViewBuilder
    private var helpfulState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "No Items Yet"))
                .font(.title2)

            Text(String(localized: "Start adding items to your list"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Add item button
            Button(action: onAddItem) {
                HStack {
                    Image(systemName: Constants.UI.addIcon)
                    Text(String(localized: "Add Your First Item"))
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            // Usage tips
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Quick Tips"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "hand.tap", text: String(localized: "Click an item to mark it complete"))
                MacTipRow(icon: "pencil", text: String(localized: "Double-click to edit details"))
                MacTipRow(icon: "photo", text: String(localized: "Add photos, quantities, and descriptions"))
                MacTipRow(icon: "wand.and.stars", text: String(localized: "Get smart suggestions as you type"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }
}

// MARK: - Tip Row

/// Tip row component for empty state views.
struct MacTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Search Empty State View (Task 12.7)

/// Empty state view shown when search returns no results.
/// Provides clear messaging about the search query and option to clear search.
struct MacSearchEmptyStateView: View {
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            // Title
            Text(String(localized: "No Results Found"))
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            // Search query display
            VStack(spacing: 4) {
                Text(String(localized: "No items match"))
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("\"\(searchText)\"")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Clear search button
            Button(action: onClear) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text(String(localized: "Clear Search"))
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Clear search")
            .accessibilityHint("Clears the search text to show all items")

            // Tips section
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Search Tips"))
                    .font(.headline)
                    .padding(.top, 8)

                MacTipRow(icon: "textformat", text: String(localized: "Check for typos in your search"))
                MacTipRow(icon: "magnifyingglass", text: String(localized: "Try searching for part of the item name"))
                MacTipRow(icon: "line.3.horizontal.decrease", text: String(localized: "Check if filters are hiding results"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SearchEmptyStateView")
    }
}

// MARK: - Previews

#Preview("Lists Empty State") {
    MacListsEmptyStateView(
        onCreateSampleList: { _ in },
        onCreateCustomList: { }
    )
    .frame(width: 600, height: 700)
}

#Preview("No List Selected") {
    MacNoListSelectedView(onCreateList: { })
        .frame(width: 600, height: 400)
}

#Preview("Items Empty State - No Items") {
    MacItemsEmptyStateView(hasItems: false, isArchived: false, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - All Complete") {
    MacItemsEmptyStateView(hasItems: true, isArchived: false, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - Archived Empty") {
    MacItemsEmptyStateView(hasItems: false, isArchived: true, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Items Empty State - Archived All Complete") {
    MacItemsEmptyStateView(hasItems: true, isArchived: true, onAddItem: { })
        .frame(width: 500, height: 400)
}

#Preview("Search Empty State") {
    MacSearchEmptyStateView(
        searchText: "nonexistent item",
        onClear: { }
    )
    .frame(width: 500, height: 450)
}
