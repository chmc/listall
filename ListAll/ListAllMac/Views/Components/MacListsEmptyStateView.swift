//
//  MacListsEmptyStateView.swift
//  ListAllMac
//
//  Empty state views for the lists screen on macOS.
//

import SwiftUI
import AppKit

// MARK: - Lists Empty State View

/// Empty state view for lists screen with engaging design and quick start options.
/// macOS equivalent of iOS ListsEmptyStateView.
struct MacListsEmptyStateView: View {
    let onCreateSampleList: (SampleDataService.SampleListTemplate) -> Void
    let onCreateCustomList: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 32)

                // Teal circle with list icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
                .accessibilityHidden(true)

                // Welcome message
                VStack(spacing: 8) {
                    Text(String(localized: "Welcome to ListAll"))
                        .font(.title)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "Create your first list or start from a template"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 2x2 Template grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(SampleDataService.templates, id: \.name) { template in
                        MacTemplateGridButton(template: template) {
                            onCreateSampleList(template)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Create custom list button - solid teal
                Button(action: onCreateCustomList) {
                    Text(String(localized: "Create Custom List"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 350)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens sheet to create new list")
                .padding(.horizontal, 16)

                Spacer()
                    .frame(height: 32)
            }
            .frame(maxWidth: 450)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Template Grid Button

/// Compact template button for the 2x2 grid in welcome state.
struct MacTemplateGridButton: View {
    let template: SampleDataService.SampleListTemplate
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 32, height: 32)

                // Text content
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("\(template.sampleItems.count) \(String(localized: "items"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isHovering ? Theme.Colors.primary.opacity(0.5) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("\(template.name) template")
        .accessibilityHint("Creates a new list with \(template.sampleItems.count) sample items")
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

#Preview("Lists Empty State") {
    MacListsEmptyStateView(
        onCreateSampleList: { _ in },
        onCreateCustomList: { }
    )
    .frame(width: 600, height: 700)
}
