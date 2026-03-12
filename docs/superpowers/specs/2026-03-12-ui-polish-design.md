# UI Polish Design Spec — SwiftUI Implementation Reference

## Context

ListAll is a cross-platform checklist app (iOS/iPad/macOS/watchOS). A previous UI polish attempt partially implemented the designs — brand colors and empty states are done, but most visual changes (sidebar selection, card-based items, watchOS polish) were not implemented or don't match the original designs.

This spec provides **exact SwiftUI code patterns** for each change, eliminating the CSS→SwiftUI translation gap that caused the previous implementation to drift from the designs.

**Visual reference mockups** (HTML) are in `.superpowers/brainstorm/57429-1773298544/` — open directly in browser. These show the target look; this document shows the target code.
- `design-iphone-full.html` — 11 iPhone views (dark+light)
- `design-desktop-full.html` — 10 macOS + iPad views
- `design-watchos-full.html` — 11 watchOS views

---

## Scope

### In Scope (this spec)
Changes 1–5 below cover the primary visual gaps: sidebar selection, card-based items, watchOS polish.

### Deferred (not in this round)
These views from VIEW-INVENTORY.md need work but are deferred to avoid scope creep:
- **View #3** `ItemDetailView.swift` — Card styling, status badge (minor, rarely seen)
- **View #7** `ArchivedListView.swift` — Brand teal accents (low traffic view)
- **View #13** iPad sidebar empty state — styling follows from Change 4
- **View #14** iPad sidebar archived row — styling follows from Change 4
- **View #23** `MacNoListSelectedView.swift` — Brand styling (low priority)
- **View #30** `WatchFilterPicker.swift` — Teal active state (minor)

These can be addressed in a follow-up pass after the core changes are verified.

---

## Brand Color System (Already Implemented ✅)

These are already in `Theme.swift` and `AccentColor` assets:

```swift
// Theme.Colors (already exists)
static let primary = Color("AccentColor")  // #00B4DC light, #7DD8F0 dark
static let completedGreen = Color(red: 0.063, green: 0.725, blue: 0.506)  // #10B981
static let brandGradient = LinearGradient(colors: [Color("AccentColor"), ...])
```

**Note:** `Theme.swift` is available in iOS and macOS targets only (`#if os(iOS)` / `#elseif os(macOS)`). The watchOS target does NOT have access to Theme — use `.accentColor` and inline color definitions instead (see Change 5).

---

## Change 1: macOS Sidebar — Selection State & Count Format

**File:** `ListAll/ListAllMac/Views/MacMainView.swift` (MacSidebarView, ~line 602+)
**Status:** NOT IMPLEMENTED

### 1a. Count Format: `4 (6)` → `4/6`

Current code shows counts like `"4 (6)"`. Change to `"4/6"`:

```swift
// REPLACE the current count text with:
Text("\(activeCount)/\(totalCount)")
    .font(.caption)
    .monospacedDigit()
    .foregroundColor(.secondary)
    .numericContentTransition()  // existing extension
```

### 1b. Selected Row: Teal Left Border

The macOS sidebar currently uses system selection (solid blue). Override with custom selection appearance:

```swift
// For the selected row, wrap content in:
HStack(spacing: 0) {
    // Teal left accent bar
    RoundedRectangle(cornerRadius: 2)
        .fill(Theme.Colors.primary)
        .frame(width: 3)

    // Row content with tinted background
    HStack {
        Text(list.name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Theme.Colors.primary)
        Spacer()
        Text("\(activeCount)/\(totalCount)")
            .font(.caption)
            .monospacedDigit()
            .foregroundColor(Theme.Colors.primary.opacity(0.5))
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
}
.background(Theme.Colors.primary.opacity(0.08))
.clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 8, topTrailingRadius: 8))
```

For **unselected rows**, keep the same layout but without the left bar and tinted bg:

```swift
HStack {
    Text(list.name)
        .font(.system(size: 13))
        .foregroundColor(.primary.opacity(0.7))
    Spacer()
    Text("\(activeCount)/\(totalCount)")
        .font(.caption)
        .monospacedDigit()
        .foregroundColor(.secondary.opacity(0.5))
}
.padding(.vertical, 10)
.padding(.leading, 15)  // 12 + 3 (align with selected content after border)
.padding(.trailing, 12)
```

### 1c. Section Headers

```swift
Text("LISTS")
    .font(.system(size: 9, weight: .semibold))
    .tracking(1.2)
    .foregroundColor(.secondary.opacity(0.5))
    .textCase(.uppercase)
```

---

## Change 2: iOS Item Rows — Card-Based Styling

**Files:**
- `ListAll/ListAll/Views/Components/ItemRowView.swift`
- `ListAll/ListAll/Views/ListView.swift`
**Status:** ~20% IMPLEMENTED (has opacity on completed, needs card styling)

### 2a. Card Background on Item Rows

ListView already uses `.listStyle(.plain)`, so add card styling directly in ItemRowView (not via `listRowBackground`, which fights with plain lists):

```swift
@Environment(\.colorScheme) private var colorScheme

// Wrap ItemRowView content in:
.padding(.vertical, 12)
.padding(.horizontal, 14)
.background {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.03 : 1.0))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 1, y: 1)
}
.overlay {
    if colorScheme == .dark {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }
}

// Also in ListView, hide default separators:
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
```

### 2b. Checkbox Circle

**Context:** The current `ItemRowView` has no visible checkbox in normal mode — it uses a tap gesture on content to toggle. In selection mode (`isInSelectionMode`), it shows circle/checkmark.circle.fill. This change adds a **new visible checkbox** to the left of every item row in normal mode. The existing selection mode checkbox should be updated to match the same visual style.

Add a visible circle checkbox:

```swift
// Active item checkbox
Circle()
    .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 2)
    .frame(width: 22, height: 22)

// Completed item checkbox
ZStack {
    Circle()
        .fill(Theme.Colors.completedGreen.opacity(0.2))
    Circle()
        .strokeBorder(Theme.Colors.completedGreen.opacity(0.3), lineWidth: 2)
    Image(systemName: "checkmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(Theme.Colors.completedGreen)
}
.frame(width: 22, height: 22)
```

### 2c. Quantity Badge

Current: quantity shown inline via `item.formattedQuantity` (returns `"Nx"` format, e.g. `"3x"`).
New: teal capsule badge, right-aligned, using `×N` format (multiplication sign prefix):

```swift
// Only show when quantity > 1
if item.quantity > 1 {
    Text("×\(item.quantity)")
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
}
```

### 2d. Completed Item Row

```swift
// Wrap the entire completed row with:
.opacity(item.isCrossedOut ? 0.5 : 1.0)
// NOTE: Existing code uses 0.7 for title and 0.6 for secondary elements.
// This change unifies to 0.5 on the entire row for stronger visual differentiation.
// Title gets strikethrough (already implemented)
```

### 2e. Item Row Layout (Complete)

**IMPORTANT:** Preserve existing behavior:
- Descriptions use `MixedTextView` (from `URLHelper.swift`), NOT plain `Text` — this renders URLs as clickable links
- Use `item.hasDescription` (Bool) and `item.displayDescription` (String) — NOT `item.itemDescription` directly
- The `isInSelectionMode` layout path must continue to work with the new card styling
- The existing `.hoverEffect(.lift)` on iPad can be removed since we're adding custom press feedback

```swift
HStack(spacing: 12) {
    // Checkbox circle (2b above)
    checkboxView(for: item)

    // Content
    VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
            .font(Theme.Typography.body)  // use Theme constant, not hard-coded
            .fontWeight(.medium)
            .strikethrough(item.isCrossedOut)
            .foregroundColor(item.isCrossedOut ? .secondary : .primary)

        if item.hasDescription {
            // KEEP existing MixedTextView for URL support
            MixedTextView(item.displayDescription)
                .font(Theme.Typography.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    Spacer()

    // Quantity badge (2c above)
    quantityBadge(for: item)
}
.padding(.vertical, 12)
.padding(.horizontal, 14)
// + card background from 2a
.opacity(item.isCrossedOut ? 0.5 : 1.0)
// + accessibility: add labels to new checkbox and badge elements
```

### 2f. Press Feedback

```swift
// On the card row, add scale effect:
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.easeInOut(duration: 0.15), value: isPressed)
```

---

## Change 3: macOS Item Rows — Same Card Treatment

**File:** `ListAll/ListAllMac/Views/MacMainView.swift` (content area)
**Status:** NOT IMPLEMENTED

Same card styling as iOS Change 2, but with macOS sizing (intentionally tighter radii per macOS platform convention):
- Card border-radius: 10px (vs 12px on iOS — deliberate platform difference)
- Checkbox: 20px diameter (vs 22px on iOS)
- Padding: 11px vertical, 14px horizontal
- Quantity badge: same teal capsule pattern
- Hover state on cards:

```swift
.onHover { hovering in
    isHovered = hovering
}
.background(
    RoundedRectangle(cornerRadius: 10)
        .fill(Color.primary.opacity(isHovered ? 0.05 : 0.03))
)
```

---

## Change 4: iPad Sidebar Selection

**File:** `ListAll/ListAll/Views/MainView.swift` (iPad NavigationSplitView path)
**Status:** NOT IMPLEMENTED

iPad uses `NavigationSplitView` with a sidebar. Apply the same teal selection treatment as macOS (Change 1b), but with iPad sizing:
- Sidebar rows show `4/6 items` format (like iPhone, not just `4/6`)
- Selected row gets teal left border + tinted background
- Unselected rows get standard padding

```swift
// iPad sidebar row (selected):
HStack(spacing: 0) {
    RoundedRectangle(cornerRadius: 2)
        .fill(Theme.Colors.primary)
        .frame(width: 3)

    VStack(alignment: .leading, spacing: 3) {
        Text(list.name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.Colors.primary)
        HStack(spacing: 0) {
            Text("\(activeCount)/\(totalCount)")
                .monospacedDigit()
                .foregroundColor(Theme.Colors.primary.opacity(0.6))
            Text(" items")
                .foregroundColor(.secondary.opacity(0.5))
        }
        .font(.caption)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)

    Spacer()
}
.background(Theme.Colors.primary.opacity(0.08))
.clipShape(RoundedRectangle(cornerRadius: 10))
```

---

## Change 5: watchOS Polish

**Files:**
- `ListAllWatch Watch App/Views/Components/WatchListRowView.swift`
- `ListAllWatch Watch App/Views/Components/WatchItemRowView.swift`
**Status:** NOT IMPLEMENTED

### 5a. List Row: Count Format + Progress Bar

**Note:** watchOS does NOT have access to `Theme.swift`. Use `.accentColor` for teal and inline color definitions for green.

```swift
// watchOS green (same as Theme.Colors.completedGreen on iOS)
private let completedGreen = Color(red: 0.063, green: 0.725, blue: 0.506)

VStack(alignment: .leading, spacing: 3) {
    Text(list.name)
        .font(.headline)

    HStack(spacing: 6) {
        Text("\(activeCount)/\(totalCount)")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundColor(.accentColor)

        Text("items")
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.5))

        Spacer()

        // Mini progress bar
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, completedGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(width: 32, height: 3)
    }
}
.padding(.vertical, 4)
```

### 5b. Item Row: Left-Aligned, Color Differentiation, Separated Quantity

**Design rationale:** No checkbox circles on watchOS — the screen is too small and circles + text + badge doesn't fit well. Instead, use tap-to-toggle (existing behavior) with teal/green color treatment and strikethrough for completed items. This keeps the layout consistent with the list rows (left-aligned, no leading icons).

```swift
Button {
    toggleItem()
} label: {
    HStack(spacing: 0) {
        // Title — left-aligned, full width
        Text(item.title)
            .font(.body)
            .strikethrough(item.isCrossedOut)
            .foregroundColor(item.isCrossedOut ? completedGreen.opacity(0.6) : .primary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Quantity (separated, right-aligned)
        if item.quantity > 1 {
            Text("×\(item.quantity)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundColor(item.isCrossedOut
                    ? completedGreen.opacity(0.5)
                    : .accentColor)
                .padding(.leading, 8)
        }
    }
    .opacity(item.isCrossedOut ? 0.6 : 1.0)
}
.buttonStyle(.plain)
.padding(.vertical, 4)
```

### 5c. Status Counts (in WatchListView)

Left-aligned, text-only (no icons — consistent with the rest of watchOS):

```swift
HStack(spacing: 8) {
    // Active count — teal
    Text("\(activeCount) active")
        .foregroundColor(.accentColor)

    // Completed count — green
    Text("\(completedCount) done")
        .foregroundColor(completedGreen)

    Spacer()

    // Total — muted
    Text("\(totalCount) total")
        .foregroundColor(.secondary.opacity(0.6))
}
.font(.caption2.monospacedDigit())
```

### 5d. Dividers

Reduce divider opacity in watchOS list:
```swift
.listRowSeparatorTint(Color.white.opacity(0.06))
```

---

## Change 6: Filter/Sort Accent Colors (iOS/macOS)

**Files:** `ListAll/ListAll/Views/Components/ItemOrganizationView.swift`, macOS content area
**Status:** NOT IMPLEMENTED

The filter is handled via a separate sheet (`ItemOrganizationView`) using `ItemFilterOption` enum (cases: `.all`, `.active`, `.completed`, `.hasDescription`, `.hasImages`). The current filter is stored as `viewModel.currentFilterOption` (default: `.active`).

Apply brand teal to active filter states:

```swift
// In ItemOrganizationView, ensure the active filter option uses brand teal:
.tint(Theme.Colors.primary)
// Apply to the Picker or any selection controls in the sheet
```

**Note:** This is a minor accent color change, not a full redesign of the filter UI.

---

## Verification Protocol

**CRITICAL: After EACH individual change (not each file, each CHANGE):**

1. `xcodebuild clean build` for the target platform
2. Launch with `UITEST_MODE`
3. Screenshot in **both light and dark mode** (dark mode has different card styling — borders vs shadows)
4. Compare screenshots against design mockup in `.superpowers/brainstorm/57429-1773298544/`
   - Check: spacing matches, colors correct, layout alignment, text sizing
   - Card backgrounds: dark = border + 0.03 opacity fill; light = white + shadow
5. If it doesn't match → fix immediately before moving to next change
6. If it matches → commit and move to next change

**Simulator discovery:**
```bash
# List available simulators to find UDIDs:
listall_list_simulators
# Or: xcrun simctl list devices available
# Recommended: iPhone 16 Pro, iPad Air, Apple Watch Series 10 (46mm)
```

**Build commands:**
```bash
# macOS
xcodebuild clean build -project ListAll/ListAll.xcodeproj -scheme "ListAllMac" -destination "generic/platform=macOS" -quiet

# iOS (replace <UDID> with actual simulator UDID from discovery step)
xcodebuild clean build -project ListAll/ListAll.xcodeproj -scheme "ListAll" -destination "platform=iOS Simulator,id=<UDID>" -quiet

# watchOS
xcodebuild clean build -project ListAll/ListAll.xcodeproj -scheme "ListAllWatch Watch App" -destination "platform=watchOS Simulator,id=<UDID>" -quiet
```

---

## Implementation Order

1. **macOS sidebar** (Change 1) — most visible gap, self-contained
2. **iOS item rows** (Change 2) — card styling, checkboxes, quantity badges
3. **macOS item rows** (Change 3) — same patterns as iOS
4. **iPad sidebar** (Change 4) — selection treatment
5. **watchOS** (Change 5) — count format, teal colors, progress bars

Each step: implement → build → screenshot → verify → commit → next.

---

## Files to Modify

| Priority | File | Changes |
|----------|------|---------|
| 1 | `ListAllMac/Views/MacMainView.swift` | Sidebar selection, count format, section headers |
| 2 | `ListAll/Views/Components/ItemRowView.swift` | Checkbox circle, quantity badge, card layout |
| 2 | `ListAll/Views/ListView.swift` | Card row background, list row separator |
| 3 | `ListAllMac/Views/MacMainView.swift` | Content area item cards, hover states |
| 4 | `ListAll/Views/MainView.swift` | iPad sidebar selection |
| 5 | `ListAllWatch/Views/Components/WatchListRowView.swift` | Count format, progress bar |
| 5 | `ListAllWatch/Views/Components/WatchItemRowView.swift` | Teal checkbox, separated quantity |
| 5 | `ListAllWatch/Views/WatchListView.swift` | Status counts (5c), divider tint (5d) |
| 6 | `ListAll/Views/Components/ItemOrganizationView.swift` | Filter accent colors |
| — | `ListAll/Utils/Theme.swift` | Any new shared color/modifier additions |
