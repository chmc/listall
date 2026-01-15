# macOS Proactive Feature Tips Implementation

## Problem

The macOS app had a feature tips system via MacTooltipManager, but tips were only accessible via Settings > General > View All Feature Tips. Users had to actively navigate to settings to learn about features. This violated the principle of progressive disclosure where features should be introduced contextually.

## Solution

Implemented a proactive feature tips system with toast-style notifications that appear contextually based on user actions and app state.

### 1. Extended MacTooltipManager

File: `ListAllMac/Utils/MacTooltipManager.swift`

Added proactive tip display support:

```swift
// MARK: - Proactive Tip Display (Task 12.5)
/// Currently displayed tooltip (for toast-style notification)
@Published var currentTooltip: MacTooltipType?

/// Whether a tooltip notification is currently visible
@Published var isShowingTooltip = false

/// Shows a tooltip if it hasn't been shown before and no other tooltip is currently visible.
@discardableResult
func showIfNeeded(_ type: MacTooltipType) -> Bool {
    guard !hasShown(type) else { return false }
    guard !isShowingTooltip else { return false }

    currentTooltip = type
    isShowingTooltip = true
    objectWillChange.send()
    return true
}

/// Dismisses the currently visible tooltip and marks it as shown
func dismissCurrentTooltip() {
    if let tooltip = currentTooltip {
        markAsShown(tooltip)
    }
    isShowingTooltip = false
    currentTooltip = nil
    objectWillChange.send()
}
```

### 2. Created MacTooltipNotificationView

File: `ListAllMac/Views/Components/MacTooltipNotificationView.swift`

Toast-style notification with:
- SF Symbol icon from tip definition
- Title and message
- Dismiss button
- Material background
- Shadow and rounded corners
- Slide-in animation from right

```swift
struct MacTooltipNotificationView: View {
    let tip: MacTooltipType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)
                Text(tip.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 3)
        .frame(maxWidth: 350)
    }
}
```

### 3. Added Tooltip Overlay to MacMainView

Wrapped NavigationSplitView in ZStack with tooltip overlay in top-right:

```swift
var body: some View {
    ZStack(alignment: .topTrailing) {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // ... sidebar and detail views
        }

        // Proactive Feature Tips Overlay
        if tooltipManager.isShowingTooltip, let tip = tooltipManager.currentTooltip {
            MacTooltipNotificationView(tip: tip) {
                withAnimation(.easeOut(duration: 0.2)) {
                    tooltipManager.dismissCurrentTooltip()
                }
            }
            .padding(.top, 60) // Below toolbar
            .padding(.trailing, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
            .zIndex(100)
        }
    }
    .onAppear {
        triggerProactiveTips()
    }
}
```

### 4. Contextual Tip Triggers

**MacMainView - App-level triggers:**
```swift
private func triggerProactiveTips() {
    guard !isEditingAnyItem else { return }

    // 0.8s: Keyboard shortcuts tip for new users
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        withAnimation(.easeIn(duration: 0.3)) {
            _ = tooltipManager.showIfNeeded(.keyboardShortcuts)
        }
    }

    // 1.2s: Add list tip if no lists exist
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        if dataManager.lists.isEmpty {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.addListButton)
            }
        }
    }

    // 1.5s: Archive tip if 3+ lists
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        if dataManager.lists.count >= 3 {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.archiveFunctionality)
            }
        }
    }
}
```

**MacListDetailView - Item-related triggers:**
```swift
private func triggerItemRelatedTips() {
    let itemCount = items.count

    // 5+ items: Show search tip
    if itemCount >= 5 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.searchFunctionality)
            }
        }
    }

    // 7+ items: Show sort/filter tip
    if itemCount >= 7 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.sortFilterOptions)
            }
        }
    }

    // 2+ items: Show context menu tip
    if itemCount >= 2 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                _ = tooltipManager.showIfNeeded(.contextMenuActions)
            }
        }
    }
}
```

## Key Learnings

### 1. withAnimation and Return Values

`withAnimation` closure expects `Void` return type. When wrapping a function that returns a value (like `showIfNeeded` returning `Bool`), you must explicitly discard the result:

```swift
// ERROR: Conflicting arguments to generic parameter 'Result'
withAnimation(.easeIn(duration: 0.3)) {
    tooltipManager.showIfNeeded(.keyboardShortcuts)
}

// CORRECT: Discard the return value
withAnimation(.easeIn(duration: 0.3)) {
    _ = tooltipManager.showIfNeeded(.keyboardShortcuts)
}
```

### 2. Tooltip Queue Pattern

The `showIfNeeded` method implements a simple queue pattern:
- Only one tip visible at a time (`isShowingTooltip` guard)
- Tips are not shown if already viewed (`hasShown` check)
- Dismissing marks the tip as viewed (persisted to UserDefaults)

### 3. Staggered Delays

Using staggered delays prevents tips from competing:
- 0.8s for primary tip (keyboard shortcuts)
- 1.2s for conditional tip (add list if empty)
- 1.5s for conditional tip (archive if many lists)

Each subsequent tip only shows if the previous one wasn't shown.

### 4. ZStack for Overlay

The tooltip overlay uses ZStack at the root level with `.zIndex(100)` to ensure it appears above all content including sheets and popovers.

### 5. Asymmetric Transitions

Different entry and exit animations provide polished UX:
- Entry: Slide from right + fade
- Exit: Just fade

## Files Modified

1. `ListAllMac/Utils/MacTooltipManager.swift` - Added proactive methods
2. `ListAllMac/Views/MacMainView.swift` - Added overlay and triggers
3. `ListAllMac/Views/Components/MacTooltipNotificationView.swift` - New file

## Test Results

- 21 ProactiveFeatureTipsTests passed
- 166 total macOS tests passed
