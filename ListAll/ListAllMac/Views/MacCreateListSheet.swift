//
//  MacCreateListSheet.swift
//  ListAllMac
//
//  Sheet for creating new lists with template support.
//

import SwiftUI

struct MacCreateListSheet: View {
    @State private var listName = ""
    let onSave: (String) -> Void
    let onCreateFromTemplate: (SampleDataService.SampleListTemplate) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("New List")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 24)
                .padding(.bottom, 20)

            // Custom List Section
            VStack(spacing: 12) {
                TextField("List Name", text: $listName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .accessibilityLabel("List name")
                    .accessibilityIdentifier("ListNameTextField")
                    .onSubmit {
                        if !listName.isEmpty {
                            onSave(listName)
                        }
                    }

                Button(action: {
                    onSave(listName)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Custom List")
                    }
                    .frame(width: 300)
                }
                .buttonStyle(.borderedProminent)
                .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Creates new list with the entered name")
            }

            // Divider with "or" text
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text(String(localized: "or start from a template"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Template Section (Task 16.10)
            VStack(spacing: 8) {
                ForEach(SampleDataService.templates, id: \.name) { template in
                    MacCreateListTemplateButton(template: template) {
                        onCreateFromTemplate(template)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Cancel button
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .accessibilityHint("Discards changes")
            .accessibilityIdentifier("CancelButton")
        }
        .frame(width: 380)
        .accessibilityIdentifier("CreateListSheet")
    }
}

// MARK: - Create List Template Button (Task 16.10)

/// Compact template button for the create list sheet
struct MacCreateListTemplateButton: View {
    let template: SampleDataService.SampleListTemplate
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .cornerRadius(6)

                // Text content
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(template.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Item count badge
                Text("\(template.sampleItems.count) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isHovering ? Theme.Colors.primary.opacity(0.5) : Color.secondary.opacity(0.2),
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
        .accessibilityHint("Creates a new list with \(template.sampleItems.count) sample items")
    }
}
