import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    @ObservedObject var viewModel: ImportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Import Summary"))
                            .font(.headline)

                        if preview.listsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                if preview.listsToCreate == 1 {
                                    Text(String(localized: "1 new list"))
                                } else {
                                    Text(String(localized: "\(preview.listsToCreate) new lists"))
                                }
                            }
                        }

                        if preview.listsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                if preview.listsToUpdate == 1 {
                                    Text(String(localized: "1 list to update"))
                                } else {
                                    Text(String(localized: "\(preview.listsToUpdate) lists to update"))
                                }
                            }
                        }

                        if preview.itemsToCreate > 0 {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                if preview.itemsToCreate == 1 {
                                    Text(String(localized: "1 new item"))
                                } else {
                                    Text(String(localized: "\(preview.itemsToCreate) new items"))
                                }
                            }
                        }

                        if preview.itemsToUpdate > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                if preview.itemsToUpdate == 1 {
                                    Text(String(localized: "1 item to update"))
                                } else {
                                    Text(String(localized: "\(preview.itemsToUpdate) items to update"))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Conflicts Section
                    if preview.hasConflicts {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(String(localized: "Conflicts (\(preview.conflicts.count))"))
                                    .font(.headline)
                            }

                            ForEach(Array(preview.conflicts.prefix(5).enumerated()), id: \.offset) { _, conflict in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conflict.entityName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(conflict.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }

                            if preview.conflicts.count > 5 {
                                Text(String(localized: "And \(preview.conflicts.count - 5) more..."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Strategy Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Import Strategy"))
                            .font(.headline)
                        HStack {
                            Image(systemName: viewModel.strategyIcon(viewModel.selectedStrategy))
                            Text(viewModel.strategyName(viewModel.selectedStrategy))
                                .font(.subheadline)
                        }
                        Text(viewModel.strategyDescription(viewModel.selectedStrategy))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                            viewModel.confirmImport()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(String(localized: "Confirm Import"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            dismiss()
                            viewModel.cancelPreview()
                        }) {
                            Text(String(localized: "Cancel"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Import Preview"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
