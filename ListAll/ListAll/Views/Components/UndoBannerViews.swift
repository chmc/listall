import SwiftUI

// MARK: - Custom Button Style for Editable Header

struct EditableHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Undo Banner Component

struct UndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.Colors.success)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onUndo) {
                Text("Undo")
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.background)
                .shadow(color: Theme.Shadow.largeColor, radius: Theme.Shadow.largeRadius, x: Theme.Shadow.largeX, y: Theme.Shadow.largeY)
        )
    }
}

// MARK: - Delete Undo Banner Component

struct DeleteUndoBanner: View {
    let itemName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Text(itemName)
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onUndo) {
                Text("Undo")
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.background)
                .shadow(color: Theme.Shadow.largeColor, radius: Theme.Shadow.largeRadius, x: Theme.Shadow.largeX, y: Theme.Shadow.largeY)
        )
    }
}
