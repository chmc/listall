import SwiftUI

struct SuggestionListView: View {
    let suggestions: [ItemSuggestion]
    let onSuggestionTapped: (ItemSuggestion) -> Void
    
    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(Theme.Colors.primary)
                        .font(.caption)
                    Text("Suggestions")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                
                // Suggestions List
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.indices, id: \.self) { index in
                        SuggestionRowView(
                            suggestion: suggestions[index],
                            onTapped: onSuggestionTapped
                        )
                        
                        if index < suggestions.count - 1 {
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
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let description = suggestion.description, !description.isEmpty {
                        Text(description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
}

#Preview("Suggestions List") {
    let sampleSuggestions = [
        ItemSuggestion(title: "Milk", description: "2% low fat", frequency: 5, lastUsed: Date().addingTimeInterval(-3600), score: 95.0, recencyScore: 95.0, frequencyScore: 85.0, totalOccurrences: 5),
        ItemSuggestion(title: "Bread", description: "Whole wheat", frequency: 3, lastUsed: Date().addingTimeInterval(-86400), score: 85.0, recencyScore: 75.0, frequencyScore: 70.0, totalOccurrences: 3),
        ItemSuggestion(title: "Eggs", frequency: 2, lastUsed: Date().addingTimeInterval(-86400 * 3), score: 75.0, recencyScore: 60.0, frequencyScore: 50.0, totalOccurrences: 2),
        ItemSuggestion(title: "Butter", frequency: 1, lastUsed: Date().addingTimeInterval(-86400 * 7), score: 65.0, recencyScore: 40.0, frequencyScore: 30.0, totalOccurrences: 1)
    ]
    
    return VStack {
        SuggestionListView(suggestions: sampleSuggestions) { suggestion in
            print("Tapped: \(suggestion.title)")
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
