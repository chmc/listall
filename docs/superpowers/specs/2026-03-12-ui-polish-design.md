# UI Polish Design Spec — SwiftUI Implementation Reference

## Context

ListAll is a cross-platform checklist app (iOS/iPad/macOS/watchOS). A previous UI polish attempt partially implemented the designs — brand colors and empty states are done, but most visual changes (sidebar selection, card-based items, watchOS polish) were not implemented or don't match the original designs.

This spec provides **exact SwiftUI code patterns** for each change, eliminating the CSS→SwiftUI translation gap that caused the previous implementation to drift from the designs.

**Visual reference mockups** (HTML) are in `.superpowers/brainstorm/57429-1773298544/` — open directly in browser. These show the target look; this document shows the target code.
- `design-iphone-full.html` — 13 iPhone views (dark+light): lists overview, items list, item detail, empty states, archived lists overview, archived list view, settings (top/bottom scroll), create list, edit item, sort/filter
- `design-ipad.html` — 14 iPad views (dark+light): sidebar+items, no list selected, empty states, item detail, archived lists overview, archived list view, settings (top/bottom scroll), create list, edit item, sort/filter
- `design-desktop-full.html` — 20 macOS + iPad views (dark+light): sidebar states, items, sheets, settings, empty states, search empty
- `design-watchos-full.html` — 11 watchOS views: lists overview, items, filter, empty states, loading, sync

**Mockups are the visual source of truth.** When implementing, take screenshots and compare against mockups. The spec provides SwiftUI code patterns; the mockups show what it should look like.

---

## Scope

### In Scope (this spec)
Changes 1–12 below cover ALL visual gaps across all platforms. Changes 1–6 are the core visual changes. Changes 7–12 are secondary polish (accent colors, brand consistency).

### Already Done
Empty states (gradient CTAs, green celebration circles), brand color foundation, count format on iOS lists, content transitions, symbol effects.

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
**Status:** COMPLETED

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

The macOS sidebar currently uses `List(selection:)` with `NavigationLink(value:)` which provides system selection (solid blue). To override with custom selection: disable the system row background with `.listRowBackground(Color.clear)` on each row, then apply the custom selection appearance below. This prevents double-highlighting from the system selection + custom background:

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
**Status:** COMPLETED

### 2a. Card Background on Item Rows

ListView already uses `.listStyle(.plain)`, so add card styling directly in ItemRowView (not via `listRowBackground`, which fights with plain lists):

```swift
@Environment(\.colorScheme) private var colorScheme

// Wrap ItemRowView content in:
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

Current: quantity shown inline via `item.formattedQuantity` (returns `"3x"` format).
New: teal capsule badge, right-aligned, using `×3` format (multiplication sign prefix). **Do NOT modify `formattedQuantity` property** — it's used in macOS tests. Build the new format inline:

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

**IMPORTANT:** Preserve ALL existing behavior:
- Descriptions use `MixedTextView` (from `URLHelper.swift`), NOT plain `Text` — this renders URLs as clickable links. `MixedTextView` requires named parameters: `MixedTextView(text:font:textColor:...)` — NOT a single positional argument.
- Use `item.hasDescription` (Bool) and `item.displayDescription` (String) — NOT `item.itemDescription` directly
- The `isInSelectionMode` layout path must continue to work with the new card styling
- The existing `.hoverEffect(.lift)` on iPad can be removed since we're adding custom press feedback
- **PRESERVE the chevron.right navigation button** (right side) — it navigates to item detail/edit
- **PRESERVE the image count indicator** (`photo` icon with count) when item has images
- **PRESERVE the secondary info HStack** showing image count and any other metadata
- Do NOT change `item.formattedQuantity` property — build the `×N` format inline with a new `Text` view

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
            // KEEP existing MixedTextView with named parameters:
            MixedTextView(text: item.displayDescription, font: Theme.Typography.caption, textColor: .secondary)
                .lineLimit(1)
        }

        // PRESERVE: secondary info row (image count indicator, etc.)
        // Keep existing HStack that shows photo icon + count when item has images
    }

    Spacer()

    // Quantity badge (2c above)
    quantityBadge(for: item)

    // PRESERVE: chevron.right navigation button
    // Keep the existing chevron that navigates to item detail/edit
}
.padding(.vertical, 12)
.padding(.horizontal, 14)
// + card background from 2a
.opacity(item.isCrossedOut ? 0.5 : 1.0)
// + accessibility: add labels to new checkbox and badge elements
```

### 2f. Press Feedback

Use a custom `ButtonStyle` to get `isPressed` state. Wrap the card row in a `Button` with this style:

```swift
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Apply to the card row:
Button(action: { /* existing tap action */ }) {
    // ... card row content from 2e
}
.buttonStyle(CardPressStyle())
```

**Note:** `ItemRowView` currently uses `onTapGesture` and the custom `.if()` modifier (from `ListRowView.swift`) for context menus and swipe actions. Ensure the `ButtonStyle` approach works with these existing gesture handlers — test thoroughly.

---

## Change 3: macOS Item Rows — Same Card Treatment

**File:** `ListAll/ListAllMac/Views/MacMainView.swift` (content area)
**Status:** COMPLETED

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
        .fill(Color.white.opacity(isHovered ? 0.05 : 0.03))
)
```

---

## Change 4: iPad Sidebar Selection

**File:** `ListAll/ListAll/Views/MainView.swift` (iPad NavigationSplitView path)
**Status:** NOT IMPLEMENTED

iPad uses `NavigationSplitView` with a sidebar that renders rows via `ListRowView` component (`ListAll/ListAll/Views/Components/ListRowView.swift`). The current sidebar uses `.listRowBackground()` for selection state (MainView.swift ~line 226). **Modify `ListRowView`** (or create an iPad-specific variant) to apply the custom teal selection treatment. Disable system selection bg with `.listRowBackground(Color.clear)`. Apply the same teal selection pattern as macOS (Change 1b), but with iPad sizing:
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

**Layout principle:** Everything left-aligned on watchOS. Apple's own apps (Reminders, Weather, Activity) all use left-aligned text. Centered text is only for empty states and modal prompts.

```swift
// watchOS green (same as Theme.Colors.completedGreen on iOS)
private let completedGreen = Color(red: 0.063, green: 0.725, blue: 0.506)

// All content left-aligned
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

        // Mini progress bar — inline with count text
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

### 5b. Item Row: Left-Aligned Text, No Checkboxes, Separated Quantity

**Design rationale:** **REMOVE** the existing checkbox circles from watchOS item rows (current code has `Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")` in `WatchItemRowView`). The watchOS screen is too small for checkboxes. Use tap-to-toggle (existing behavior) with color differentiation only. Everything left-aligned, consistent with list rows.

```swift
Button {
    toggleItem()
} label: {
    HStack {
        // Title — left-aligned
        Text(item.title)
            .font(.body)
            .strikethrough(item.isCrossedOut)
            .foregroundColor(item.isCrossedOut ? completedGreen.opacity(0.6) : .primary)
            .lineLimit(2)

        Spacer()

        // Quantity badge (right-aligned, only when > 1)
        if item.quantity > 1 {
            Text("×\(item.quantity)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundColor(item.isCrossedOut
                    ? completedGreen.opacity(0.5)
                    : .accentColor)
        }
    }
    .opacity(item.isCrossedOut ? 0.6 : 1.0)
}
.buttonStyle(.plain)
.padding(.vertical, 4)
```

### 5c. Status Counts (in WatchListView)

Left-aligned, text-only (no icons — consistent with the rest of watchOS).

**IMPORTANT:** Use `watchLocalizedString()` or `NSLocalizedString()` for all user-facing strings — the current watchOS code is fully localized and new strings must follow the same pattern.

```swift
HStack(spacing: 8) {
    // Active count — teal
    Text("\(activeCount) \(watchLocalizedString("active"))")
        .foregroundColor(.accentColor)

    // Completed count — green
    Text("\(completedCount) \(watchLocalizedString("done"))")
        .foregroundColor(completedGreen)

    Spacer()

    // Total — muted
    Text("\(totalCount) \(watchLocalizedString("total"))")
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

The sort buttons currently use `.blue.opacity(0.1)` background and blue checkmarks. Replace with brand teal:

```swift
// Selected sort/filter button background:
Theme.Colors.primary.opacity(0.1)
// Selected checkmark/icon color:
Theme.Colors.primary
// Unselected: keep existing secondary styling
```

---

## Change 7: Item Detail View — Brand Styling

**File:** `ListAll/ListAll/Views/ItemDetailView.swift`
**Status:** NOT IMPLEMENTED

The item detail view currently uses a simple HStack with icon+text to show status ("Completed"/"Pending"). **Replace** this with a styled capsule badge using brand colors. Note: "Active" replaces "Pending" as the label for non-crossed-out items.

### 7a. Status Badge (replaces existing icon+text status indicator)

```swift
// Active status badge
HStack(spacing: 6) {
    Circle()
        .fill(Theme.Colors.primary)
        .frame(width: 8, height: 8)
    Text("Active")
        .font(.caption.weight(.semibold))
        .foregroundColor(Theme.Colors.primary)
}
.padding(.horizontal, 10)
.padding(.vertical, 5)
.background(Theme.Colors.primary.opacity(0.1))
.clipShape(Capsule())

// Completed status badge
HStack(spacing: 6) {
    Image(systemName: "checkmark")
        .font(.caption.weight(.bold))
        .foregroundColor(Theme.Colors.completedGreen)
    Text("Completed")
        .font(.caption.weight(.semibold))
        .foregroundColor(Theme.Colors.completedGreen)
}
.padding(.horizontal, 10)
.padding(.vertical, 5)
.background(Theme.Colors.completedGreen.opacity(0.1))
.clipShape(Capsule())
```

### 7b. Detail Cards (Quantity, Images)

```swift
// Use brand teal for detail card icons instead of info/warning colors:
Image(systemName: "number")
    .font(.title2)
    .foregroundColor(Theme.Colors.primary)
```

### 7c. "Mark as Completed" Button

```swift
Button(action: toggleCompletion) {
    HStack {
        Image(systemName: item.isCrossedOut ? "arrow.uturn.backward" : "checkmark")
        Text(item.isCrossedOut ? "Mark as Active" : "Mark as Completed")
    }
    .font(.body.weight(.semibold))
    .foregroundColor(.white)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(
        item.isCrossedOut
            ? Theme.Colors.primary
            : Theme.Colors.completedGreen
    )
    .clipShape(Capsule())
}
```

---

## Change 8: Archived List View — Brand Teal Accents

**File:** `ListAll/ListAll/Views/ArchivedListView.swift`
**Status:** COMPLETED

### 8a. Archived Badge

Replace the current secondary-colored archive indicator with an orange "Archived" badge:

```swift
HStack(spacing: 4) {
    Image(systemName: "archivebox")
        .font(.caption2)
    Text("Archived")
        .font(.caption.weight(.semibold))
}
.foregroundColor(.orange)
.padding(.horizontal, 10)
.padding(.vertical, 4)
.background(Color.orange.opacity(0.12))
.clipShape(Capsule())
```

### 8b. Toolbar Buttons

```swift
// Restore button — brand teal
Button(action: { showingRestoreConfirmation = true }) {
    HStack(spacing: 4) {
        Image(systemName: "arrow.uturn.backward")
        Text("Restore")
    }
    .foregroundColor(Theme.Colors.primary)
}

// Delete button — red (already correct)
```

### 8c. Archived Item Rows — Read-Only Styling

Items in archived lists are strikethrough with muted opacity. No checkboxes. Keep existing `ArchivedItemRowView` but ensure consistent styling:

```swift
Text(item.displayTitle)
    .font(Theme.Typography.body)
    .strikethrough(item.isCrossedOut)
    .foregroundColor(.secondary)
    .opacity(0.6)
```

---

## Change 9: Settings View — Accent Color Consistency

**File:** `ListAll/ListAll/Views/SettingsView.swift`
**Status:** COMPLETED

Settings is already functional. Apply minor brand accent consistency:

### 9a. Action Buttons (Export/Import)

```swift
// Data action buttons should use brand teal:
Button("Export Data") { ... }
    .foregroundColor(Theme.Colors.primary)
Button("Import Data") { ... }
    .foregroundColor(Theme.Colors.primary)
```

### 9b. Toggle Tint

```swift
// Ensure all toggles use brand teal:
Toggle(isOn: $hapticManager.isEnabled) { ... }
    .tint(Theme.Colors.primary)
Toggle(isOn: $requiresBiometricAuth) { ... }
    .tint(Theme.Colors.primary)
```

### 9c. About Section App Icon

```swift
// App icon in About section should use brand teal:
Image(systemName: "list.bullet.clipboard")
    .font(.system(size: 40))
    .foregroundColor(Theme.Colors.primary)  // was .accentColor — ensure it's brand teal
```

**Note:** Settings layout is NOT changing — only accent colors. See mockups sections 8a/8b (iPhone), 9a/9b (iPad), 5 (macOS) for the exact visual target. The mockups show all rows/icons for content reference.

**macOS Settings:** Also apply the same accent color changes to `ListAll/ListAllMac/Views/MacSettingsView.swift` (separate file from iOS SettingsView). Ensure toggle tints and action button colors match.

---

## Change 10: Create List & Edit Item Sheets — Accent Colors

**Files:**
- `ListAll/ListAll/Views/CreateListView.swift`
- `ListAll/ListAll/Views/ItemEditView.swift`
**Status:** NOT IMPLEMENTED

Minor accent color changes only — no layout changes:

### 10a. Create List Sheet

```swift
// "Create" button should use brand teal:
Button("Create") { ... }
    .foregroundColor(Theme.Colors.primary)
    .fontWeight(.semibold)
```

### 10b. Edit Item Sheet

```swift
// "Save" button should use brand teal:
Button("Save") { ... }
    .foregroundColor(Theme.Colors.primary)
    .fontWeight(.semibold)

// Add Photo button — brand teal instead of blue:
Button(action: addPhoto) {
    Label("Add Photo", systemImage: "camera.fill")
}
.foregroundColor(Theme.Colors.primary)
```

See mockups sections 9-10 (iPhone), 10-11 (iPad) for visual reference.

---

## Change 11: macOS No List Selected — Brand Styling

**File:** `ListAll/ListAllMac/Views/Components/MacNoListSelectedView.swift`
**Status:** NOT IMPLEMENTED

```swift
VStack(spacing: 20) {
    Image(systemName: "list.bullet.clipboard")
        .font(.system(size: 64))
        .foregroundColor(.secondary.opacity(0.4))

    Text("No List Selected")
        .font(.title2)
        .foregroundColor(.secondary)

    Text("Select a list from the sidebar or create a new one.")
        .font(.body)
        .foregroundColor(.secondary.opacity(0.7))
        .multilineTextAlignment(.center)

    // CTA button with brand gradient:
    Button("Create New List") { ... }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Colors.primary)
}
```

See desktop mockup section 1 for visual reference.

---

## Change 12: watchOS Filter Picker — Teal Active State

**File:** `ListAll/ListAllWatch Watch App/Views/Components/WatchFilterPicker.swift`
**Status:** NOT IMPLEMENTED

```swift
// Ensure Picker uses brand teal for selection:
Picker("Filter", selection: $selectedFilter) {
    // ... filter options
}
.tint(.accentColor)  // watchOS uses .accentColor, which is already brand teal
```

**Note:** watchOS Picker styling is system-driven with limited customization. The main change is ensuring `.accentColor` (brand teal) is used consistently. See watchOS mockup section 3.

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

**Phase A — Core Visual Changes (Changes 1–5):**
1. **macOS sidebar** (Change 1) — most visible gap, self-contained
2. **iOS item rows** (Change 2) — card styling, checkboxes, quantity badges
3. **macOS item rows** (Change 3) — same patterns as iOS
4. **iPad sidebar** (Change 4) — selection treatment
5. **watchOS** (Change 5) — count format, teal colors, progress bars

**Phase B — Secondary Polish (Changes 6–12):**
6. **Filter/sort accent colors** (Change 6) — teal active states in ItemOrganizationView
7. **Item detail view** (Change 7) — status badges, detail cards, action button
8. **Archived list view** (Change 8) — archived badge, toolbar buttons, item styling
9. **Settings accent colors** (Change 9) — toggles, buttons, about section
10. **Sheet accent colors** (Change 10) — create list, edit item buttons
11. **macOS no list selected** (Change 11) — brand styling on empty state
12. **watchOS filter picker** (Change 12) — teal active state

Each step: implement → build → screenshot (both light+dark) → compare against mockup → fix if needed → commit → next.

---

## Files to Modify

| Priority | File | Changes |
|----------|------|---------|
| 1 | `ListAllMac/Views/MacMainView.swift` | Sidebar selection, count format, section headers |
| 2 | `ListAll/Views/Components/ItemRowView.swift` | Checkbox circle, quantity badge, card layout |
| 2 | `ListAll/Views/ListView.swift` | Card row background, list row separator |
| 3 | `ListAllMac/Views/MacMainView.swift` | Content area item cards, hover states |
| 4 | `ListAll/Views/MainView.swift` | iPad sidebar selection |
| 5 | `ListAll/ListAllWatch Watch App/Views/Components/WatchListRowView.swift` | Count format, progress bar |
| 5 | `ListAll/ListAllWatch Watch App/Views/Components/WatchItemRowView.swift` | Left-aligned text, no checkboxes, separated quantity |
| 5 | `ListAll/ListAllWatch Watch App/Views/WatchListView.swift` | Status counts (5c), divider tint (5d) |
| 6 | `ListAll/Views/Components/ItemOrganizationView.swift` | Filter/sort teal active states |
| 7 | `ListAll/Views/ItemDetailView.swift` | Status badge, detail card icons, action button |
| 8 | `ListAll/Views/ArchivedListView.swift` | Archived badge, toolbar buttons, item styling |
| 9 | `ListAll/Views/SettingsView.swift` | Toggle tints, button colors, about icon |
| 9 | `ListAllMac/Views/MacSettingsView.swift` | Toggle tints, button colors (macOS settings) |
| 10 | `ListAll/Views/CreateListView.swift` | Create button teal accent |
| 10 | `ListAll/Views/ItemEditView.swift` | Save button, add photo button teal accents |
| 11 | `ListAllMac/Views/Components/MacNoListSelectedView.swift` | Brand styling, CTA button |
| 12 | `ListAll/ListAllWatch Watch App/Views/Components/WatchFilterPicker.swift` | Teal accent on picker |
| — | `ListAll/Utils/Theme.swift` | Any new shared color/modifier additions |
