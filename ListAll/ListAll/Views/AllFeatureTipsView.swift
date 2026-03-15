import SwiftUI

struct AllFeatureTipsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        NavigationView {
            SwiftUI.List {
                Section {
                    ForEach(TooltipType.allCases, id: \.rawValue) { tipType in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            // Icon
                            Image(systemName: tipType.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)

                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(tipType.title)
                                        .font(Theme.Typography.headline)

                                    Spacer()

                                    // Viewed indicator
                                    if tooltipManager.hasShown(tipType) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(tipType.message)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                } header: {
                    HStack {
                        Text("All Feature Tips")
                        Spacer()
                        Text("\(tooltipManager.shownTooltipCount())/\(tooltipManager.totalTooltipCount()) viewed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.none)
                    }
                } footer: {
                    Text(String(localized: "Tips marked with ✓ have been viewed. Tips will appear automatically when you use features, or you can reset them to see all tips again from Settings."))
                }
            }
            .navigationTitle(String(localized: "Feature Tips"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
