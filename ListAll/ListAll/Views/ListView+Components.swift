import SwiftUI

extension ListView {

    // MARK: - Editable List Name Header

    var editableListNameHeader: some View {
        Button(action: {
            showingEditList = true
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(Theme.CornerRadius.md)
        }
        .buttonStyle(EditableHeaderButtonStyle())
        .accessibilityLabel("Edit list name: \(list.name)")
        .accessibilityHint("Double tap to edit")
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 4)
    }

    // MARK: - Inline Filter Pills

    static var inlineFilterOptions: [(label: String, option: ItemFilterOption)] {
        [
            ("All", .all),
            ("Active", .active),
            ("Done", .completed)
        ]
    }

    var filterPillsView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Self.inlineFilterOptions, id: \.option) { pill in
                let isSelected = viewModel.currentFilterOption == pill.option
                Button {
                    viewModel.updateFilterOption(pill.option)
                } label: {
                    Text(pill.label)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.Colors.primary : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
    }

    // MARK: - Add Item Button

    var addItemButton: some View {
        Button(action: {
            showingCreateItem = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: Constants.UI.addIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text(String(localized: "Item"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
        .hoverEffect(.lift)
        .accessibilityLabel("Add new item")
        .accessibilityIdentifier("AddItemButton")
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}
