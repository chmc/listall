//
//  MacSuggestionListView.swift
//  ListAllMac
//
//  macOS-specific suggestion list component.
//  Displays intelligent item suggestions with score indicators and metadata.
//

import SwiftUI

/// macOS-specific suggestion list view.
/// Reuses shared SuggestionService logic, provides native macOS UI.
struct MacSuggestionListView: View {
    let suggestions: [ItemSuggestion]
    let onSuggestionTapped: (ItemSuggestion) -> Void

    @State private var showAllSuggestions = false
    @State private var hoveredSuggestionId: UUID?

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerView

                Divider()

                // Suggestions List
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let displayedSuggestions = showAllSuggestions ? suggestions : Array(suggestions.prefix(3))

                        ForEach(displayedSuggestions, id: \.id) { suggestion in
                            MacSuggestionRowView(
                                suggestion: suggestion,
                                isHovered: hoveredSuggestionId == suggestion.id,
                                showExtendedDetails: showAllSuggestions,
                                onTapped: onSuggestionTapped
                            )
                            .onHover { isHovering in
                                hoveredSuggestionId = isHovering ? suggestion.id : nil
                            }

                            if suggestion.id != displayedSuggestions.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: showAllSuggestions ? 300 : 150)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)

            Text("Suggestions (\(suggestions.count))")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Show All toggle button if we have more than 3 suggestions
            if suggestions.count > 3 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllSuggestions.toggle()
                    }
                }) {
                    Text(showAllSuggestions ? "Show Top 3" : "Show All")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Suggestion Row View

private struct MacSuggestionRowView: View {
    let suggestion: ItemSuggestion
    let isHovered: Bool
    let showExtendedDetails: Bool
    let onTapped: (ItemSuggestion) -> Void

    var body: some View {
        Button(action: { onTapped(suggestion) }) {
            HStack(spacing: 8) {
                // Score indicator icon
                scoreIcon
                    .frame(width: 16)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    // Title row
                    HStack {
                        Text(suggestion.title)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(showExtendedDetails ? 2 : 1)

                        // Quantity badge
                        if suggestion.quantity > 1 {
                            Text("\(suggestion.quantity)")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    // Description
                    if let description = suggestion.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(showExtendedDetails ? 2 : 1)
                    }

                    // Extended details
                    if showExtendedDetails {
                        HStack(spacing: 8) {
                            Text("Score: \(Int(suggestion.score))")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text("Used: \(formatRelativeDate(suggestion.lastUsed))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Right-side indicators
                HStack(spacing: 4) {
                    // Frequency indicator
                    if suggestion.frequency > 1 {
                        Text("\(suggestion.frequency)x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Recency indicator
                    if suggestion.recencyScore >= 90 {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if suggestion.recencyScore >= 70 {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    // Hot item indicator
                    if suggestion.frequencyScore >= 80 {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    // Image indicator
                    if !suggestion.images.isEmpty {
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var scoreIcon: some View {
        if suggestion.score >= 90 {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.caption)
        } else if suggestion.score >= 70 {
            Image(systemName: "star")
                .foregroundColor(.orange)
                .font(.caption)
        } else {
            Image(systemName: "circle.fill")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 6))
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let daysSince = Int(now.timeIntervalSince(date) / 86400)
        let language = LocalizationManager.shared.currentLanguage

        if daysSince == 0 {
            return language == .finnish ? "Tanaan" : "Today"
        } else if daysSince == 1 {
            return language == .finnish ? "Eilen" : "Yesterday"
        } else if daysSince < 7 {
            return language == .finnish ? "\(daysSince) pv sitten" : "\(daysSince)d ago"
        } else if daysSince < 30 {
            let weeks = daysSince / 7
            return language == .finnish ? "\(weeks) vk sitten" : "\(weeks)w ago"
        } else {
            let months = daysSince / 30
            return language == .finnish ? "\(months) kk sitten" : "\(months)mo ago"
        }
    }
}

// MARK: - Preview

#Preview("Suggestions List") {
    let sampleSuggestions = [
        ItemSuggestion(id: UUID(), title: "Milk", description: "2% low fat", quantity: 2, images: [], frequency: 5, lastUsed: Date().addingTimeInterval(-3600), score: 95.0, recencyScore: 95.0, frequencyScore: 85.0, totalOccurrences: 5),
        ItemSuggestion(id: UUID(), title: "Bread", description: "Whole wheat", quantity: 1, images: [], frequency: 3, lastUsed: Date().addingTimeInterval(-86400), score: 85.0, recencyScore: 75.0, frequencyScore: 70.0, totalOccurrences: 3),
        ItemSuggestion(id: UUID(), title: "Eggs", quantity: 12, images: [], frequency: 2, lastUsed: Date().addingTimeInterval(-86400 * 3), score: 75.0, recencyScore: 60.0, frequencyScore: 50.0, totalOccurrences: 2),
        ItemSuggestion(id: UUID(), title: "Butter", quantity: 1, images: [], frequency: 1, lastUsed: Date().addingTimeInterval(-86400 * 7), score: 65.0, recencyScore: 40.0, frequencyScore: 30.0, totalOccurrences: 1),
        ItemSuggestion(id: UUID(), title: "Cheese", description: "Cheddar sharp", quantity: 1, images: [], frequency: 4, lastUsed: Date().addingTimeInterval(-86400 * 2), score: 80.0, recencyScore: 70.0, frequencyScore: 75.0, totalOccurrences: 4)
    ]

    return VStack {
        MacSuggestionListView(suggestions: sampleSuggestions) { suggestion in
            print("Selected: \(suggestion.title)")
        }
        .frame(width: 350)
        .padding()

        Spacer()
    }
    .frame(height: 400)
}
