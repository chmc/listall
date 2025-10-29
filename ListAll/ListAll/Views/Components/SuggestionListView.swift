import SwiftUI

struct SuggestionListView: View {
    let suggestions: [ItemSuggestion]
    let onSuggestionTapped: (ItemSuggestion) -> Void
    let showAllSuggestions: Bool
    let onShowAllToggled: (() -> Void)?
    
    // Default initializer for backward compatibility
    init(suggestions: [ItemSuggestion], onSuggestionTapped: @escaping (ItemSuggestion) -> Void) {
        self.suggestions = suggestions
        self.onSuggestionTapped = onSuggestionTapped
        self.showAllSuggestions = true
        self.onShowAllToggled = nil
    }
    
    // Enhanced initializer for Phase 14
    init(suggestions: [ItemSuggestion], 
         onSuggestionTapped: @escaping (ItemSuggestion) -> Void,
         showAllSuggestions: Bool = true,
         onShowAllToggled: (() -> Void)? = nil) {
        self.suggestions = suggestions
        self.onSuggestionTapped = onSuggestionTapped
        self.showAllSuggestions = showAllSuggestions
        self.onShowAllToggled = onShowAllToggled
    }
    
    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header with Show All toggle
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(Theme.Colors.primary)
                        .font(.caption)
                    Text("Suggestions (\(suggestions.count))")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    Spacer()
                    
                    // Show All toggle button if we have more than 3 suggestions
                    if suggestions.count > 3, let onShowAllToggled = onShowAllToggled {
                        Button(action: onShowAllToggled) {
                            Text(showAllSuggestions ? "Show Top 3" : "Show All")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                
                // Suggestions List
                LazyVStack(alignment: .leading, spacing: 0) {
                    let displayedSuggestions = showAllSuggestions ? suggestions : Array(suggestions.prefix(3))
                    
                    ForEach(displayedSuggestions.indices, id: \.self) { index in
                        SuggestionRowView(
                            suggestion: displayedSuggestions[index],
                            onTapped: onSuggestionTapped,
                            showExtendedDetails: showAllSuggestions
                        )
                        
                        if index < displayedSuggestions.count - 1 {
                            Divider()
                                .padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
            }
            .background(Theme.Colors.groupedBackground)
            .cornerRadius(Theme.CornerRadius.md)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

struct SuggestionRowView: View {
    let suggestion: ItemSuggestion
    let onTapped: (ItemSuggestion) -> Void
    let showExtendedDetails: Bool
    
    // Default initializer for backward compatibility
    init(suggestion: ItemSuggestion, onTapped: @escaping (ItemSuggestion) -> Void) {
        self.suggestion = suggestion
        self.onTapped = onTapped
        self.showExtendedDetails = false
    }
    
    // Enhanced initializer for Phase 14
    init(suggestion: ItemSuggestion, onTapped: @escaping (ItemSuggestion) -> Void, showExtendedDetails: Bool = false) {
        self.suggestion = suggestion
        self.onTapped = onTapped
        self.showExtendedDetails = showExtendedDetails
    }
    
    var body: some View {
        Button(action: {
            onTapped(suggestion)
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                // Icon based on suggestion score
                Image(systemName: suggestionIcon)
                    .foregroundColor(suggestionIconColor)
                    .font(.caption)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                        .lineLimit(showExtendedDetails ? 2 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let description = suggestion.description, !description.isEmpty {
                        Text(description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                            .lineLimit(showExtendedDetails ? 3 : 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Extended details for Phase 14
                    if showExtendedDetails {
                        HStack(spacing: 8) {
                            // Score indicator
                            Text("Score: \(Int(suggestion.score))")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.secondary)
                            
                            // Last used indicator
                            Text("Used: \(formatRelativeDate(suggestion.lastUsed))")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Advanced metrics display
                HStack(spacing: 4) {
                    // Frequency indicator
                    if suggestion.frequency > 1 {
                        Text("\(suggestion.frequency)×")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Recency indicator (for very recent items)
                    if suggestion.recencyScore >= 90 {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if suggestion.recencyScore >= 70 {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    // High usage frequency indicator
                    if suggestion.frequencyScore >= 80 {
                        Image(systemName: "flame")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
    
    private var suggestionIcon: String {
        if suggestion.score >= 90 {
            return "star.fill"
        } else if suggestion.score >= 70 {
            return "star"
        } else {
            return "circle"
        }
    }
    
    private var suggestionIconColor: Color {
        if suggestion.score >= 90 {
            return Theme.Colors.primary
        } else if suggestion.score >= 70 {
            return Theme.Colors.primary.opacity(0.7)
        } else {
            return Theme.Colors.secondary
        }
    }
    
    // Helper function for formatting relative dates
    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let daysSince = Int(now.timeIntervalSince(date) / 86400)
        
        if daysSince == 0 {
            return "Today"
        } else if daysSince == 1 {
            return "Yesterday"
        } else if daysSince < 7 {
            return "\(daysSince)d ago"
        } else if daysSince < 30 {
            let weeks = daysSince / 7
            return "\(weeks)w ago"
        } else {
            let months = daysSince / 30
            return "\(months)mo ago"
        }
    }
}

#Preview("Suggestions List") {
    let sampleSuggestions = [
        ItemSuggestion(id: UUID(), title: "Milk", description: "2% low fat", quantity: 2, images: [], frequency: 5, lastUsed: Date().addingTimeInterval(-3600), score: 95.0, recencyScore: 95.0, frequencyScore: 85.0, totalOccurrences: 5),
        ItemSuggestion(id: UUID(), title: "Bread", description: "Whole wheat", quantity: 1, images: [], frequency: 3, lastUsed: Date().addingTimeInterval(-86400), score: 85.0, recencyScore: 75.0, frequencyScore: 70.0, totalOccurrences: 3),
        ItemSuggestion(id: UUID(), title: "Eggs", quantity: 12, images: [], frequency: 2, lastUsed: Date().addingTimeInterval(-86400 * 3), score: 75.0, recencyScore: 60.0, frequencyScore: 50.0, totalOccurrences: 2),
        ItemSuggestion(id: UUID(), title: "Butter", quantity: 1, images: [], frequency: 1, lastUsed: Date().addingTimeInterval(-86400 * 7), score: 65.0, recencyScore: 40.0, frequencyScore: 30.0, totalOccurrences: 1)
    ]
    
    return VStack {
        SuggestionListView(suggestions: sampleSuggestions) { suggestion in
            // Handle suggestion tap
        }
        .padding()
        
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Empty Suggestions") {
    SuggestionListView(suggestions: []) { _ in }
        .padding()
        .background(Theme.Colors.background)
}
