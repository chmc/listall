---
title: macOS Proactive Feature Tips Implementation
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [feature-tips, toast, proactive, contextual, withAnimation, zstack]
symptoms: [Tips only accessible via Settings, No contextual tip display, Users must actively seek tips]
root_cause: Tips were passive (Settings-only) rather than proactive (contextual display)
solution: Extend MacTooltipManager with proactive display and add toast notifications based on app state
files_affected: [ListAllMac/Utils/MacTooltipManager.swift, ListAllMac/Views/MacMainView.swift, ListAllMac/Views/Components/MacTooltipNotificationView.swift]
related: [macos-feature-tips-implementation.md]
---

## Problem

Tips only accessible via Settings. Users had to actively navigate to settings to learn about features.

## Solution

### Extended MacTooltipManager

```swift
// MARK: - Proactive Tip Display
@Published var currentTooltip: MacTooltipType?
@Published var isShowingTooltip = false

@discardableResult
func showIfNeeded(_ type: MacTooltipType) -> Bool {
    guard !hasShown(type) else { return false }
    guard !isShowingTooltip else { return false }

    currentTooltip = type
    isShowingTooltip = true
    objectWillChange.send()
    return true
}

func dismissCurrentTooltip() {
    if let tooltip = currentTooltip {
        markAsShown(tooltip)
    }
    isShowingTooltip = false
    currentTooltip = nil
}
```

### MacTooltipNotificationView

Toast-style notification with:
- SF Symbol icon, title, message
- Dismiss button
- Material background, shadow, rounded corners
- Slide-in animation from right

### Tooltip Overlay in MacMainView

```swift
var body: some View {
    ZStack(alignment: .topTrailing) {
        NavigationSplitView { ... }

        if tooltipManager.isShowingTooltip, let tip = tooltipManager.currentTooltip {
            MacTooltipNotificationView(tip: tip) {
                withAnimation(.easeOut(duration: 0.2)) {
                    tooltipManager.dismissCurrentTooltip()
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
            .zIndex(100)
        }
    }
    .onAppear { triggerProactiveTips() }
}
```

### Contextual Triggers

**App-level (MacMainView):**
- 0.8s: Keyboard shortcuts tip for new users
- 1.2s: Add list tip if no lists exist
- 1.5s: Archive tip if 3+ lists

**Item-related (MacListDetailView):**
- 5+ items: Search tip
- 7+ items: Sort/filter tip
- 2+ items: Context menu tip

## Critical Learning: withAnimation and Return Values

`withAnimation` expects `Void` return. Discard non-void returns:

```swift
// ERROR: Conflicting arguments to generic parameter 'Result'
withAnimation(.easeIn(duration: 0.3)) {
    tooltipManager.showIfNeeded(.keyboardShortcuts)
}

// CORRECT
withAnimation(.easeIn(duration: 0.3)) {
    _ = tooltipManager.showIfNeeded(.keyboardShortcuts)
}
```

## Key Patterns

1. **Tooltip Queue**: Only one tip visible at a time (`isShowingTooltip` guard)
2. **Staggered Delays**: 0.8s, 1.2s, 1.5s prevents tips competing
3. **ZStack with zIndex(100)**: Ensures overlay above all content
4. **Asymmetric Transitions**: Slide-in entry, fade-out exit
