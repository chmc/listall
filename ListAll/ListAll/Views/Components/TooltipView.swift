//
//  TooltipView.swift
//  ListAll
//
//  Created by AI Assistant on 10/12/25.
//  Reusable tooltip component with pointer and animations
//

import SwiftUI

/// Position of the tooltip arrow relative to the target element
enum TooltipArrowPosition {
    case top
    case bottom
    case leading
    case trailing
}

/// A contextual tooltip view with an arrow pointer
struct TooltipView: View {
    let message: String
    let arrowPosition: TooltipArrowPosition
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            if arrowPosition == .bottom {
                arrow
                    .rotationEffect(.degrees(180))
            }
            
            HStack(spacing: 0) {
                if arrowPosition == .trailing {
                    arrow
                        .rotationEffect(.degrees(90))
                }
                
                tooltipContent
                
                if arrowPosition == .leading {
                    arrow
                        .rotationEffect(.degrees(-90))
                }
            }
            
            if arrowPosition == .top {
                arrow
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
    
    private var tooltipContent: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            .accessibilityLabel("Dismiss tooltip")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.blue)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
    
    private var arrow: some View {
        Triangle()
            .fill(Color.blue)
            .frame(width: 20, height: 10)
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

/// Triangle shape for the tooltip arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// View modifier to attach a tooltip to any view
struct TooltipModifier: ViewModifier {
    let tooltipType: TooltipType
    let arrowPosition: TooltipArrowPosition
    let alignment: Alignment
    let offset: CGSize
    
    @StateObject private var tooltipManager = TooltipManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if tooltipManager.isShowingTooltip,
                   tooltipManager.currentTooltip == tooltipType {
                    TooltipView(
                        message: tooltipType.message,
                        arrowPosition: arrowPosition,
                        onDismiss: {
                            tooltipManager.dismissCurrentTooltip()
                        }
                    )
                    .offset(offset)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1000) // Ensure tooltip appears above other content
                }
            }
    }
}

extension View {
    /// Attach a tooltip that shows conditionally based on TooltipManager
    func tooltip(
        _ type: TooltipType,
        arrowPosition: TooltipArrowPosition = .top,
        alignment: Alignment = .bottom,
        offset: CGSize = CGSize(width: 0, height: 8)
    ) -> some View {
        modifier(TooltipModifier(
            tooltipType: type,
            arrowPosition: arrowPosition,
            alignment: alignment,
            offset: offset
        ))
    }
}

#Preview("Tooltip Bottom") {
    VStack {
        Spacer()
        
        Button("Add List") {
            // Button action
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
        .tooltip(
            .addListButton,
            arrowPosition: .top,
            alignment: .bottom,
            offset: CGSize(width: 0, height: 8)
        )
        
        Spacer()
    }
    .onAppear {
        TooltipManager.shared.showIfNeeded(.addListButton)
    }
}

#Preview("Tooltip Top") {
    VStack {
        Spacer()
        
        Text("Search Field")
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .tooltip(
                .searchFunctionality,
                arrowPosition: .bottom,
                alignment: .top,
                offset: CGSize(width: 0, height: -8)
            )
        
        Spacer()
    }
    .onAppear {
        TooltipManager.shared.showIfNeeded(.searchFunctionality)
    }
}

