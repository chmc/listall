import SwiftUI

// MARK: - Archive Banner Component
struct ArchiveBanner: View {
    let listName: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "archivebox.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Archived")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.secondary)

                Text(listName)
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
