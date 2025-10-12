//
//  TooltipOverlay.swift
//  ListAll
//
//  Created by AI Assistant on 10/12/25.
//  Full-screen tooltip overlay that isn't clipped by navigation bars
//

import SwiftUI

/// A full-screen overlay that shows tooltips above all content
struct TooltipOverlay: View {
    @StateObject private var tooltipManager = TooltipManager.shared
    
    var body: some View {
        ZStack {
            // Semi-transparent background when tooltip is showing
            if tooltipManager.isShowingTooltip {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        tooltipManager.dismissCurrentTooltip()
                    }
                    .transition(.opacity)
            }
            
            // Tooltip content
            if tooltipManager.isShowingTooltip,
               let tooltip = tooltipManager.currentTooltip {
                tooltipContent(for: tooltip)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tooltipManager.isShowingTooltip)
    }
    
    @ViewBuilder
    private func tooltipContent(for tooltip: TooltipType) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // Tooltip bubble
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Text(tooltip.message)
                        .font(Theme.Typography.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button(action: {
                        tooltipManager.dismissCurrentTooltip()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                )
            }
            .padding(.horizontal, Theme.Spacing.lg)
            
            // Got it button
            Button(action: {
                tooltipManager.dismissCurrentTooltip()
            }) {
                Text("Got it!")
                    .font(Theme.Typography.headline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Color.white)
                    )
            }
        }
        .position(x: UIScreen.main.bounds.width / 2, y: tooltipPosition(for: tooltip))
        .transition(.scale.combined(with: .opacity))
    }
    
    private func tooltipPosition(for tooltip: TooltipType) -> CGFloat {
        // Position tooltips based on where they should appear
        switch tooltip {
        case .addListButton, .archiveFunctionality:
            // Top toolbar buttons - show near top
            return 120
        case .sortFilterOptions, .searchFunctionality:
            // List view toolbar - show near top
            return 120
        case .swipeActions:
            // Item rows - show in middle
            return UIScreen.main.bounds.height / 2
        case .itemSuggestions:
            // Item edit suggestions - show in middle
            return UIScreen.main.bounds.height / 2.5
        }
    }
}

#Preview {
    ZStack {
        // Sample app content
        NavigationView {
            SwiftUI.List {
                Text("Sample List Item 1")
                Text("Sample List Item 2")
                Text("Sample List Item 3")
            }
            .navigationTitle("Lists")
        }
        
        // Tooltip overlay
        TooltipOverlay()
    }
    .onAppear {
        // Show a sample tooltip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = TooltipManager.shared.showIfNeeded(.addListButton)
        }
    }
}

