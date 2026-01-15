# macOS Filter UI Redesign - From iOS Popover to Native macOS Pattern

**Date**: January 15, 2026
**Task**: Task 12.4 - Redesign Filter UI from iOS Popover to Native macOS Pattern

## Problem

The filter UI used an iOS-style popover pattern that violated macOS conventions:
1. Filter state hidden until clicked (no discoverability)
2. Requires 2 clicks + animation wait to change filter
3. No keyboard shortcuts for filters
4. No View menu integration (macOS convention)

```swift
// Previous iOS-ism: Button -> Popover -> Select -> Dismiss
Button(action: { showingOrganizationPopover.toggle() }) {
    Image(systemName: "arrow.up.arrow.down")
}
.popover(isPresented: $showingOrganizationPopover) {
    MacItemOrganizationView(viewModel: viewModel)
}
```

## Research Findings

Agent swarm research (January 2026) revealed:
- **None of 7 best-in-class macOS apps** (Finder, Mail, Notes, Reminders, Things 3, Bear, OmniFocus) use popovers for primary filtering
- All use **always-visible controls**: sidebar sections, toolbar buttons, or segmented controls
- Apple HIG explicitly discourages popovers for "frequently used filters"

## Solution

Replaced the popover with native macOS pattern:

### 1. Toolbar Segmented Control (MacMainView.swift)

```swift
@ViewBuilder
private var filterSortControls: some View {
    HStack(spacing: 8) {
        // Filter segmented control - always visible, single click
        Picker("Filter", selection: $viewModel.currentFilterOption) {
            Text("All").tag(ItemFilterOption.all)
            Text("Active").tag(ItemFilterOption.active)
            Text("Done").tag(ItemFilterOption.completed)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .help("Filter items by status (Cmd+1/2/3)")
        .accessibilityIdentifier("FilterSegmentedControl")

        // Sort button - keeps popover for less-frequent sort options
        Button(action: { showingOrganizationPopover.toggle() }) {
            Image(systemName: "arrow.up.arrow.down")
        }
        .buttonStyle(.plain)
        .help("Sort Options")
        .accessibilityIdentifier("SortButton")
        .popover(isPresented: $showingOrganizationPopover) {
            MacSortOnlyView(viewModel: viewModel)
        }
    }
}
```

### 2. View Menu with Keyboard Shortcuts (AppCommands.swift)

```swift
// MARK: - Filter Shortcuts (Task 12.4)
Button("All Items") {
    NotificationCenter.default.post(
        name: NSNotification.Name("SetFilterAll"),
        object: nil
    )
}
.keyboardShortcut("1", modifiers: .command)

Button("Active Only") {
    NotificationCenter.default.post(
        name: NSNotification.Name("SetFilterActive"),
        object: nil
    )
}
.keyboardShortcut("2", modifiers: .command)

Button("Completed Only") {
    NotificationCenter.default.post(
        name: NSNotification.Name("SetFilterCompleted"),
        object: nil
    )
}
.keyboardShortcut("3", modifiers: .command)
```

### 3. Notification Receivers (MacListDetailView)

```swift
// MARK: - View Menu Filter Shortcuts (Task 12.4)
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterAll"))) { _ in
    viewModel.updateFilterOption(.all)
    viewModel.items = items
}
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterActive"))) { _ in
    viewModel.updateFilterOption(.active)
    viewModel.items = items
}
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterCompleted"))) { _ in
    viewModel.updateFilterOption(.completed)
    viewModel.items = items
}
```

### 4. Sort-Only Popover (MacSortOnlyView.swift)

Created a new component that shows only sorting options (extracted from MacItemOrganizationView). Sort options are used less frequently, so keeping them in a popover is acceptable per HIG.

## Key Design Decisions

1. **Segmented Control for Filters**: Provides immediate visual feedback of current filter state. Single click changes filter without popover animation.

2. **Keyboard Shortcuts Cmd+1/2/3**: Standard macOS pattern (like Finder's View menu). Users can quickly switch filters without mouse.

3. **View Menu Integration**: Native macOS apps expose filter/view options in the View menu. This provides discoverability and accessibility.

4. **Sort Stays in Popover**: Sort options are changed less frequently. Keeping them in a popover reduces toolbar clutter while still being accessible.

5. **Notification Pattern**: Used NotificationCenter consistent with existing patterns (CreateNewList, FocusSearchField, etc.) for menu command -> view communication.

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`:
  - Replaced `filterSortButton` with `filterSortControls`
  - Added notification receivers for filter shortcuts

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Commands/AppCommands.swift`:
  - Added View menu filter commands with Cmd+1/2/3 shortcuts

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacSortOnlyView.swift`:
  - New component for sort-only popover

## Tests

21 tests in `FilterUIRedesignTests` verify:
- Segmented control has All, Active, Done options
- Filter state changes immediately (no popover delay)
- Keyboard shortcuts Cmd+1/2/3 work
- Current filter is visually indicated in toolbar
- View menu integration with filter options
- Sort options remain in popover

## Lessons Learned

1. **iOS-isms in macOS Apps**: Popover-for-everything is an iOS pattern. macOS users expect always-visible controls for frequently used features.

2. **HIG Research Pays Off**: Agent swarm research of 7 best-in-class apps provided strong evidence for the design direction.

3. **Separate Frequent from Infrequent**: Filters (frequent) get direct access via segmented control. Sort (infrequent) stays in popover.

4. **View Menu Convention**: macOS apps consistently expose view/filter options in the View menu with standard keyboard shortcuts.

5. **Notification Pattern Consistency**: Using the same notification pattern as other menu commands (CreateNewList, RefreshData) maintains codebase consistency.

## References

- Task 12.4 in /documentation/TODO.md
- Apple HIG: Toolbar design, menu structure
- Agent research: macos-ux-best-practices-research-2025.md
- Existing notification patterns: CreateNewList, FocusSearchField, RefreshData
