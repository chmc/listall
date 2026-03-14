//
//  MacItemRowView+Subviews.swift
//  ListAllMac
//
//  Subview components: checkboxes, quantity badge, hover actions, row background.
//

import SwiftUI
import AppKit

extension MacItemRowView {

    // MARK: - Checkbox View (macOS 20px diameter)

    @ViewBuilder
    func checkboxView() -> some View {
        if item.isCrossedOut {
            ZStack {
                Circle()
                    .fill(Theme.Colors.completedGreen.opacity(0.2))
                Circle()
                    .strokeBorder(Theme.Colors.completedGreen.opacity(0.3), lineWidth: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.completedGreen)
            }
            .frame(width: 20, height: 20)
            .accessibilityLabel("Completed")
        } else {
            Circle()
                .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
                .frame(width: 20, height: 20)
                .accessibilityLabel("Active")
        }
    }

    // MARK: - Selection Mode Checkbox (macOS 20px diameter)

    @ViewBuilder
    func selectionCheckboxView() -> some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.2))
                Circle()
                    .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
            .frame(width: 20, height: 20)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Quantity Badge (teal capsule)

    @ViewBuilder
    func quantityBadge() -> some View {
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

    // MARK: - Hover Actions

    @ViewBuilder
    var hoverActions: some View {
        HStack(spacing: 8) {
            if item.hasImages {
                Button(action: onQuickLook) {
                    Image(systemName: "eye")
                }
                .buttonStyle(.plain)
                .help("Quick Look (Space)")
                .accessibilityLabel("Quick Look")
                .accessibilityHint("Opens image preview")
            }

            if !isArchivedList {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit Item")
                .accessibilityLabel("Edit item")
                .accessibilityHint("Opens edit sheet")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete Item")
                .accessibilityLabel("Delete item")
                .accessibilityHint("Permanently removes this item")
            }
        }
    }

    // MARK: - Row Background

    var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(colorScheme == .dark
                ? Color.white.opacity(isHovering ? 0.05 : 0.03)
                : isHovering ? Color.black.opacity(0.02) : Color.white)
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 1, y: 1)
    }

    @ViewBuilder
    var rowBorderOverlay: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
