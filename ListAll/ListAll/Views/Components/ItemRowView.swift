import SwiftUI

// MARK: - Card Press Style (2f)

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card Press Modifier (for non-Button views)

struct CardPressModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: .infinity)
                    .updating($isPressed) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
            )
    }
}

extension View {
    func cardPressEffect() -> some View {
        modifier(CardPressModifier())
    }
}

struct ItemRowView: View {
    let item: Item
    var viewModel: ListViewModel? = nil
    let onToggle: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(item: Item,
         viewModel: ListViewModel? = nil,
         onToggle: (() -> Void)? = nil,
         onEdit: (() -> Void)? = nil,
         onDuplicate: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil) {
        self.item = item
        self.viewModel = viewModel
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }

    private var isInSelectionMode: Bool {
        viewModel?.isInSelectionMode ?? false
    }

    private var isSelected: Bool {
        viewModel?.selectedItems.contains(item.id) ?? false
    }

    // MARK: - Checkbox View (2b)

    @ViewBuilder
    private func checkboxView() -> some View {
        if item.isCrossedOut {
            ZStack {
                Circle()
                    .fill(Theme.Colors.completedGreen)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 22, height: 22)
            .accessibilityLabel("Completed")
        } else {
            Circle()
                .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
                .frame(width: 22, height: 22)
                .accessibilityLabel("Active")
        }
    }

    // MARK: - Selection Mode Checkbox

    @ViewBuilder
    private func selectionCheckboxView() -> some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 22, height: 22)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }

    // MARK: - Quantity Badge (2c)

    @ViewBuilder
    private func quantityBadge() -> some View {
        if item.quantity > 1 {
            Text("\u{00D7}\(item.quantity)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(item.isCrossedOut
                    ? Theme.Colors.completedGreen.opacity(0.6)
                    : Theme.Colors.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(item.isCrossedOut
                            ? Theme.Colors.completedGreen.opacity(0.08)
                            : Theme.Colors.primary.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(item.isCrossedOut
                                    ? Theme.Colors.completedGreen.opacity(0.15)
                                    : Theme.Colors.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Quantity \(item.quantity)")
        }
    }

    // MARK: - Card Background (2a)

    private func cardBackground<Content: View>(_ content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 1, y: 1)
            }
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
    }

    // MARK: - Item Content (2e)

    private var itemContentView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
                .font(Theme.Typography.body)
                .fontWeight(.medium)
                .strikethrough(item.isCrossedOut)
                .foregroundColor(item.isCrossedOut ? .secondary : .primary)
                .animation(Theme.Animation.spring, value: item.isCrossedOut)

            if item.hasDescription {
                MixedTextView(
                    text: item.displayDescription,
                    font: Theme.Typography.caption,
                    textColor: .secondary,
                    linkColor: Theme.Colors.primary,
                    isCrossedOut: item.isCrossedOut,
                    opacity: 1.0
                )
                .lineLimit(1)
                .allowsHitTesting(true)
            }

            // Secondary info row (image count)
            if item.hasImages {
                HStack(spacing: 2) {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("\(item.imageCount)")
                        .font(Theme.Typography.caption)
                        .numericContentTransition()
                }
                .foregroundColor(Theme.Colors.info)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Normal Mode Row

    private var normalModeRow: some View {
        cardBackground(
            HStack(spacing: 12) {
                Button(action: {
                    onToggle?()
                }) {
                    checkboxView()
                }
                .buttonStyle(CardPressStyle())

                itemContentView
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggle?()
                    }

                Spacer()

                quantityBadge()

                // Chevron navigation button
                Button(action: {
                    onEdit?()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("ItemDetailButton")
            }
        )
        .opacity(item.isCrossedOut ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .cardPressEffect()
    }

    // MARK: - Selection Mode Row

    private var selectionModeRow: some View {
        cardBackground(
            HStack(spacing: 12) {
                selectionCheckboxView()

                itemContentView

                Spacer()

                quantityBadge()
            }
        )
        .opacity(item.isCrossedOut ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .cardPressEffect()
        .onTapGesture {
            viewModel?.toggleSelection(for: item.id)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isInSelectionMode {
                selectionModeRow
            } else {
                normalModeRow
            }
        }
        .if(!isInSelectionMode) { view in
            view.contextMenu {
                Button(action: { onToggle?() }) {
                    Label(item.isCrossedOut ? "Mark Active" : "Cross Out",
                          systemImage: item.isCrossedOut ? "arrow.uturn.backward" : "checkmark")
                }
                Button(action: { onEdit?() }) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(action: { onDuplicate?() }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(role: .destructive, action: { onDelete?() }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .if(!isInSelectionMode) { view in
            view
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button(action: {
                        onEdit?()
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button(action: {
                        onDuplicate?()
                    }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(action: {
                        onDelete?()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
        }
    }
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
