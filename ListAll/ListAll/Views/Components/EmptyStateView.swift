import SwiftUI

/// Empty state view for lists screen with engaging design and quick start options
struct ListsEmptyStateView: View {
    let onCreateSampleList: (SampleDataService.SampleListTemplate) -> Void
    let onCreateCustomList: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Icon with subtle animation
                Image(systemName: Constants.UI.listIcon)
                    .font(.system(size: 70))
                    .foregroundColor(Theme.Colors.primary.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.top, 40)
                
                // Welcome message
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Welcome to ListAll")
                        .font(Theme.Typography.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Organize everything in one place")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Sample list templates
                VStack(spacing: Theme.Spacing.md) {
                    Text("Get Started with a Template")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.top, Theme.Spacing.md)
                    
                    ForEach(SampleDataService.templates, id: \.name) { template in
                        SampleListButton(template: template) {
                            onCreateSampleList(template)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)
                
                // Create custom list button
                Button(action: onCreateCustomList) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: Constants.UI.addIcon)
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create Custom List")
                            .font(Theme.Typography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .padding(.horizontal, Theme.Spacing.md)
                
                // Feature highlights
                VStack(spacing: Theme.Spacing.md) {
                    Text("ListAll Features")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.top, Theme.Spacing.lg)
                    
                    FeatureHighlight(
                        icon: "photo",
                        title: "Add Photos",
                        description: "Attach images to your items"
                    )
                    
                    FeatureHighlight(
                        icon: "arrow.left.arrow.right",
                        title: "Share & Sync",
                        description: "Share lists with family and friends"
                    )
                    
                    FeatureHighlight(
                        icon: "wand.and.stars",
                        title: "Smart Suggestions",
                        description: "Get intelligent item recommendations"
                    )
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Button for creating a sample list from a template
struct SampleListButton: View {
    let template: SampleDataService.SampleListTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text(template.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Feature highlight row
struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondary)
            }
            
            Spacer()
        }
    }
}

/// Custom button style with scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

/// Empty state view for items list with usage tips
struct ItemsEmptyStateView: View {
    let hasItems: Bool
    let onAddItem: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if hasItems {
                // All items crossed out - celebration state
                celebrationState
            } else {
                // No items yet - helpful state
                helpfulState
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
    
    private var celebrationState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Celebration icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.success)
            }
            
            Text("All Done! 🎉")
                .font(Theme.Typography.largeTitle)
                .fontWeight(.bold)
            
            Text("You've completed all items in this list.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("What's next?")
                    .font(Theme.Typography.headline)
                    .padding(.top, Theme.Spacing.md)
                
                TipRow(icon: "eye", text: "Toggle the eye icon to see completed items")
                TipRow(icon: "plus.circle", text: "Add more items to continue")
                TipRow(icon: "arrow.left", text: "Go back to view your other lists")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
    
    private var helpfulState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondary)
            
            Text("No Items Yet")
                .font(Theme.Typography.title)
            
            Text("Start adding items to your list")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
                .multilineTextAlignment(.center)
            
            // Add item button
            Button(action: onAddItem) {
                HStack {
                    Image(systemName: Constants.UI.addIcon)
                    Text("Add Your First Item")
                }
                .font(Theme.Typography.headline)
                .foregroundColor(.white)
                .padding()
                .background(Theme.Colors.primary)
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            // Usage tips
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("💡 Quick Tips")
                    .font(Theme.Typography.headline)
                    .padding(.top, Theme.Spacing.md)
                
                TipRow(icon: "hand.tap", text: "Tap an item to mark it complete")
                TipRow(icon: "arrow.right.circle", text: "Tap the arrow to edit details")
                TipRow(icon: "photo", text: "Add photos, quantities, and descriptions")
                TipRow(icon: "wand.and.stars", text: "Get smart suggestions as you type")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

/// Tip row component
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondary)
            
            Spacer()
        }
    }
}

#Preview("Lists Empty State") {
    ListsEmptyStateView(
        onCreateSampleList: { _ in },
        onCreateCustomList: { }
    )
}

#Preview("Items Empty State - No Items") {
    ItemsEmptyStateView(hasItems: false, onAddItem: { })
}

#Preview("Items Empty State - All Complete") {
    ItemsEmptyStateView(hasItems: true, onAddItem: { })
}

