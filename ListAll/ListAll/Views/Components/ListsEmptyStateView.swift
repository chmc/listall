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
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 70))
                    .foregroundColor(Theme.Colors.primary.opacity(0.15))
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.top, 40)

                // Welcome message
                VStack(spacing: Theme.Spacing.sm) {
                    Text(String(localized: "Welcome to ListAll"))
                        .font(Theme.Typography.largeTitle)
                        .fontWeight(.bold)

                    Text(String(localized: "Organize everything in one place"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondary)
                        .multilineTextAlignment(.center)
                }

                // Sample list templates
                VStack(spacing: Theme.Spacing.md) {
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
                    Text(String(localized: "or"))
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
                        Text(String(localized: "Create Custom List"))
                            .font(Theme.Typography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.brandGradient)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Feature highlights
                VStack(spacing: Theme.Spacing.md) {
                    FeatureHighlight(
                        icon: "icloud.fill",
                        title: String(localized: "iCloud sync across all devices"),
                        description: ""
                    )

                    FeatureHighlight(
                        icon: "checkmark.circle.fill",
                        title: String(localized: "Track progress with smart counts"),
                        description: ""
                    )

                    FeatureHighlight(
                        icon: "photo.fill",
                        title: String(localized: "Attach photos to any item"),
                        description: ""
                    )
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
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

            if description.isEmpty {
                Text(title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)

                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                }
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

#Preview("Lists Empty State") {
    ListsEmptyStateView(
        onCreateSampleList: { _ in },
        onCreateCustomList: { }
    )
}
