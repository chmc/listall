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

    @State private var isAnimating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon with subtle animation
                Image(systemName: Constants.UI.listIcon)
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary.opacity(0.15))
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
                    .background(Theme.Colors.brandGradient)
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

#Preview("Lists Empty State") {
    MacListsEmptyStateView(
        onCreateSampleList: { _ in },
        onCreateCustomList: { }
    )
    .frame(width: 600, height: 700)
}
