//
//  MacMainView+Tips.swift
//  ListAllMac
//
//  Proactive feature tips for MacMainView.
//

import SwiftUI

extension MacMainView {
    // MARK: - Proactive Feature Tips (Task 12.5)

    /// Triggers proactive feature tips based on current app state
    /// Tips are shown with delays to avoid overwhelming new users
    func triggerProactiveTips() {
        // Skip if user is editing (don't interrupt workflows)
        guard !isEditingAnyItem else { return }

        // 0.8s delay: Keyboard shortcuts tip for new users
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.keyboardShortcuts)
            }
        }

        // 1.2s delay: Add list tip if no lists exist
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if dataManager.lists.isEmpty {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.addListButton)
                }
            }
        }

        // 1.5s delay: Archive tip if user has 3+ lists
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if dataManager.lists.count >= 3 {
                withAnimation(.easeIn(duration: 0.3)) {
                    _ = tooltipManager.showIfNeeded(.archiveFunctionality)
                }
            }
        }
    }
}
