//
//  MacImportProgressView.swift
//  ListAllMac
//
//  macOS-native import progress view showing linear progress bar,
//  percentage, current operation, and counts for lists/items processed.
//

import SwiftUI

/// macOS-native import progress view
/// Shows detailed progress during import operations
struct MacImportProgressView: View {
    let progress: ImportProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with percentage
            HStack {
                Text("Importing...")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(progress.progressPercentage)%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(progress.progressPercentage) percent complete")
            }

            // Linear progress bar
            ProgressView(value: progress.overallProgress)
                .progressViewStyle(.linear)
                .accessibilityValue("\(progress.progressPercentage) percent")

            // Current operation text
            Text(progress.currentOperation)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("Current operation: \(progress.currentOperation)")

            // Counts row
            HStack {
                // Lists count
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text("Lists: \(progress.processedLists)/\(progress.totalLists)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Lists: \(progress.processedLists) of \(progress.totalLists)")

                Spacer()

                // Items count
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text("Items: \(progress.processedItems)/\(progress.totalItems)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Items: \(progress.processedItems) of \(progress.totalItems)")
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Simple import progress view for when detailed progress is not available
struct MacImportProgressSimpleView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Import in progress")
            Text("Importing...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct MacImportProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Progress at 0%
            MacImportProgressView(
                progress: ImportProgress(
                    totalLists: 5,
                    processedLists: 0,
                    totalItems: 25,
                    processedItems: 0,
                    currentOperation: "Starting import..."
                )
            )
            .previewDisplayName("0% Progress")

            // Progress at 50%
            MacImportProgressView(
                progress: ImportProgress(
                    totalLists: 5,
                    processedLists: 3,
                    totalItems: 25,
                    processedItems: 12,
                    currentOperation: "Importing item 'Milk' into list 'Shopping'..."
                )
            )
            .previewDisplayName("50% Progress")

            // Progress at 100%
            MacImportProgressView(
                progress: ImportProgress(
                    totalLists: 5,
                    processedLists: 5,
                    totalItems: 25,
                    processedItems: 25,
                    currentOperation: "Import complete"
                )
            )
            .previewDisplayName("100% Progress")

            // Simple progress
            MacImportProgressSimpleView()
                .previewDisplayName("Simple Progress")
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
