import SwiftUI

/// A row component displaying a list with its name, item counts in `4/6 items` format, and a progress bar
struct WatchListRowView: View {
    let list: List

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
                .accessibilityIdentifier("WatchListRow_Name_\(list.id.uuidString)")

            HStack(spacing: 4) {
                Text(activeCountText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.accentColor)

                Text(watchLocalizedString("items", comment: "watchOS list row: items label"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                progressBar
            }
            .accessibilityIdentifier("WatchListRow_ItemCount_\(list.id.uuidString)")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("WatchListRowView_\(list.id.uuidString)")
    }

    // MARK: - Computed Properties (internal for testing)

    /// Format: "4/6"
    var activeCountText: String {
        "\(list.activeItemCount)/\(list.itemCount)"
    }

    /// Ratio of completed items (0.0 to 1.0)
    var progressRatio: Double {
        guard list.itemCount > 0 else { return 0 }
        return Double(list.crossedOutItemCount) / Double(list.itemCount)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { _ in
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 32 * progressRatio, height: 3)
                .background(
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 3),
                    alignment: .leading
                )
        }
        .frame(width: 32, height: 3)
    }
}

// MARK: - Preview
#Preview("Single List") {
    SwiftUI.List {
        WatchListRowView(list: List(name: "Groceries"))
    }
}

#Preview("List with Items") {
    let list = List(name: "Shopping List")
    SwiftUI.List {
        WatchListRowView(list: list)
    }
}
