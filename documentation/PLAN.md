# UI Polish — Implementation Plan

## Context

Implement all visual polish changes to match design mockups across 4 platforms (iOS, iPad, macOS, watchOS). The investigation phase identified ~15% completion — infrastructure exists in `Theme.swift` and `AccentColor` assets but views are not using them.

**Design spec:** `docs/superpowers/specs/2026-03-12-ui-polish-design.md` (SwiftUI code patterns)
**Design mockups:** `.superpowers/brainstorm/57429-1773298544/screens/` (62 PNG files — visual source of truth)
**Comparison report:** `documentation/PLAN.md` (gap analysis from investigation phase)

**Simulators:** iPhone 16 Pro (`126F8D56`), iPad Air 11-inch M2 (`191F6F01`), Apple Watch Series 10 46mm (`EAE9023D`)
**Schemes:** `ListAll` (iOS), `ListAllMac` (macOS), `ListAllWatch Watch App` (watchOS)

---

## Visual Verification Protocol (MANDATORY for every task)

Every task below ends with this verification loop. **Do not mark a task complete without passing verification.**

```
VERIFY:
1. xcodebuild clean build for target platform(s)
2. Launch with UITEST_MODE + DISABLE_TOOLTIPS
3. Screenshot the relevant view in BOTH dark and light mode
4. Read the design mockup PNG(s) listed in the task (both dark + light variants)
5. Compare screenshot vs mockup — check: colors, spacing, typography, layout
6. For card styling: dark mode uses borders, light mode uses shadows — verify BOTH
7. IF mismatch → fix code → go to step 1
8. IF match → task passes, move to next task
```

**Platform cross-check rule:** If a task modifies a shared component (e.g., `ItemRowView.swift` used on iPhone AND iPad), verify on ALL platforms that use it — not just the primary platform listed.

Design mockup path prefix: `.superpowers/brainstorm/57429-1773298544/screens/`

---

## Phase A: macOS Sidebar (Spec Change 1)

**File:** `ListAll/ListAllMac/Views/MacMainView.swift` (MacSidebarView ~line 602+)

### Task A.1: Count Format `4 (6)` → `4/6` ✅ completed

Change `MacSidebarFormatting` (line ~4382) to output `active/total` format with `.monospacedDigit()` and `.secondary` color.

**VERIFY against (dark+light):**
- `desktop--01-1-macos-sidebar-no-list-selected-dark-mode.png`
- `desktop--02-1-macos-sidebar-no-list-selected-light-mode.png`
- Count text should show `4/6` not `4 (6)`

### Task A.2: Section Headers — Uppercase 9px ✅ completed

Change "Lists" header to `"LISTS"` with `.font(.system(size: 9, weight: .semibold))`, `.tracking(1.2)`, `.foregroundColor(.secondary.opacity(0.5))`, `.textCase(.uppercase)`.

**VERIFY against (dark+light):**
- `desktop--01-1-macos-sidebar-no-list-selected-dark-mode.png`
- `desktop--02-1-macos-sidebar-no-list-selected-light-mode.png`
- Header should be small uppercase "LISTS"

### Task A.3: Selection Style — Teal Left Border ✅ completed

Replace system `List(selection:)` highlight with custom selection: 3px teal left border + `Theme.Colors.primary.opacity(0.08)` background + right-side-only rounding via `UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 8, topTrailingRadius: 8)`. Unselected rows: standard padding aligned with selected content. Use `.listRowBackground(Color.clear)` to suppress system highlight.

**RISK: HIGH** — Overriding macOS List selection is fragile. After implementation, explicitly test:
- Keyboard navigation (arrow keys still select rows)
- VoiceOver accessibility (selected state announced correctly)
- Focus ring behavior
- Click + double-click still work
- **Fallback:** If keyboard nav or VoiceOver breaks irrecoverably, keep `List(selection:)` functional and overlay the visual treatment on top (teal bar + tinted bg as overlay, not replacement)

**VERIFY against (dark+light):**
- `desktop--03-2-macos-sidebar-items-list-dark-mode.png`
- `desktop--04-2-macos-sidebar-items-list-light-mode.png`
- Selected row: teal left bar, tinted bg, teal text weight 600
- Unselected rows: muted text, aligned with selected content

---

## Phase B: iOS Item Rows — Card Styling (Spec Change 2)

**Files:** `ListAll/ListAll/Views/Components/ItemRowView.swift`, `ListAll/ListAll/Views/ListView.swift`

**Note:** `ItemRowView` is SHARED between iPhone and iPad. Every task in this phase must verify on BOTH iPhone and iPad simulators.

### Task B.1: Card Background on Item Rows ✅ completed

Add card background to `ItemRowView`: rounded rect (12px radius), dark mode = `white.opacity(0.03)` fill + `primary.opacity(0.06)` stroke border, light mode = white fill + shadow. In `ListView`: `.listRowSeparator(.hidden)`, `.listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))`.

**VERIFY against (iPhone dark + iPad dark + iPad light):**
- `iphone--02-2-items-list.png` (iPhone dark)
- `ipad--01-1-sidebar-items-list.png` (iPad dark)
- `ipad--02-2-sidebar-items-list-light.png` (iPad light)
- Items should appear as discrete cards with rounded corners, no dividers

### Task B.2: Checkbox Circles ✅ completed

Update `checkboxView()`: active items get teal circle border (`Theme.Colors.primary.opacity(0.4)`, 22px), completed items get green circle with checkmark (`Theme.Colors.completedGreen`). Ensure both normal mode and selection mode use consistent checkbox styling.

**VERIFY against:**
- `iphone--02-2-items-list.png` — teal ring (active) or green checkmark circle (completed)
- `ipad--01-1-sidebar-items-list.png` — same on iPad

### Task B.3: Quantity Badge — Teal Capsule ✅ completed

Update `quantityBadge()`: teal capsule with `×N` format, `Theme.Colors.primary` text/border for active items, `completedGreen` for completed. Do NOT modify `item.formattedQuantity` property — build `×N` format inline.

**VERIFY against:**
- `iphone--02-2-items-list.png` — teal capsule badge on right side
- `ipad--01-1-sidebar-items-list.png` — same on iPad

### Task B.4: Completed Row Opacity ✅ completed

Apply `.opacity(0.5)` to entire completed item row (currently uses 0.7/0.6 split).

**VERIFY against:**
- `iphone--02-2-items-list.png` — completed items noticeably dimmer than active

### Task B.5: Press Feedback (CardPressStyle) ✅ completed

Ensure `CardPressStyle` (scale 0.97 on press) is applied to card rows. Verify it works with existing context menu / swipe action gesture handlers.

**VERIFY:** Interactive test on iPhone — tap and hold an item card, confirm scale feedback. Also test on iPad.

### Task B.6: Cross-Platform Smoke Check ✅ completed

After all Phase B tasks, take iPad full-screen screenshot and compare holistically against `ipad--01-*` and `ipad--02-*` to catch any shared-component regressions before moving to macOS.

---

## Phase C: macOS Item Rows — Card Treatment (Spec Change 3)

**File:** `ListAll/ListAllMac/Views/MacMainView.swift` (content area item rows)

### Task C.1: macOS Card Background + Checkbox + Quantity ✅ completed

Same card pattern as iOS but with macOS sizing: 10px radius, 20px checkbox diameter, 11px vertical / 14px horizontal padding. Add hover state via `.onHover`: dark mode = `white.opacity(0.05)`, light mode = `black.opacity(0.02)` (white opacity is invisible on light backgrounds). Apply teal checkbox circles and teal quantity capsule badges.

**Dependency:** Uses same card approach as Phase B (iOS). If Phase B's approach needs rework (e.g., `ButtonStyle` conflicts with context menus), Phase C will need corresponding changes.

**VERIFY against (dark+light):**
- `desktop--03-2-macos-sidebar-items-list-dark-mode.png`
- `desktop--04-2-macos-sidebar-items-list-light-mode.png`
- Items: discrete cards with teal checkboxes, teal quantity badges, hover feedback

---

## Phase D: iPad Sidebar Selection (Spec Change 4)

**Files:** `ListAll/ListAll/Views/MainView.swift`, `ListAll/ListAll/Views/Components/ListRowView.swift`

### Task D.1: iPad Sidebar — Teal Selection ✅ completed

Modify iPad sidebar: selected row gets 3px teal left border + tinted bg + teal text, clipped with `.clipShape(RoundedRectangle(cornerRadius: 10))` (fully rounded, unlike macOS which uses right-side-only rounding). Disable system selection bg with `.listRowBackground(Color.clear)`. Count format already shows `4/6 items` — just fix accent color to teal.

**VERIFY against (dark+light):**
- `ipad--01-1-sidebar-items-list.png` (dark)
- `ipad--02-2-sidebar-items-list-light.png` (light)
- `desktop--19-8-ipad-sidebar-items-list-dark-mode.png` (dark, from desktop set)
- `desktop--20-9-ipad-sidebar-items-list-light-mode.png` (light, from desktop set)
- Selected sidebar row: teal left bar, teal text, tinted background

---

## Phase E: watchOS Polish (Spec Change 5 + 12)

**Files:**
- `ListAllWatch Watch App/Views/Components/WatchListRowView.swift`
- `ListAllWatch Watch App/Views/Components/WatchItemRowView.swift`
- `ListAllWatch Watch App/Views/WatchListView.swift`
- `ListAllWatch Watch App/Views/Components/WatchFilterPicker.swift`

**Note:** watchOS has no `Theme.swift` access — use `.accentColor` and inline color definitions.

### Task E.1: List Row — Count Format + Progress Bar ✅ completed

Change count from `4 (6) items` to `4/6` teal + "items" muted. Add inline 32x3px progress bar with teal-to-green gradient. All left-aligned.

**VERIFY against:** `watchos--01-1-lists-overview.png` — list rows show `4/6 items` with teal count and small progress bar

### Task E.2: Item Row — Remove Checkboxes, Teal Quantity ✅ completed

Remove checkbox circles from `WatchItemRowView`. Use tap-to-toggle with color differentiation only. Left-aligned title, right-aligned teal `×N` quantity. Completed items use green color + strikethrough.

**VERIFY against:**
- `watchos--02-2-items-list-with-filter.png` — no checkbox circles, text with teal color
- `watchos--03-3-completed-items-view.png` — completed items green + strikethrough

### Task E.3: Status Counts — Text Labels ✅ completed

Replace icon-based status indicators in `WatchListView` with text: "4 active 2 done 6 total" using teal/green/muted colors. Use `watchLocalizedString()` for localization.

**Localization required:** Add new strings ("active", "done", "total") to watchOS `Localizable.strings` for all supported locales (at minimum: English + Finnish). Check existing watchOS localization files for the pattern.

**VERIFY against:** `watchos--02-2-items-list-with-filter.png` — status shows text labels not icons

### Task E.4: Dividers + Filter Picker (includes Spec Change 12) ✅ completed

Apply `.listRowSeparatorTint(Color.white.opacity(0.06))` for subtle dividers. Update `WatchFilterPicker` to use `.tint(.accentColor)` for brand teal selection highlight.

**Scope note:** The gap analysis notes the filter uses a modal sheet while design shows push navigation. This plan covers the teal accent styling only — the modal-to-push navigation change is out of scope per spec (Change 12 says "teal active state" only).

**VERIFY against:** `watchos--11-11-filter-picker-expanded.png` — filter picker highlights selected option in teal

---

## Phase F: Filter/Sort Accent Colors (Spec Change 6)

**Files:** `ListAll/ListAll/Views/Components/ItemOrganizationView.swift`, macOS content area filter

### Task F.1: iOS/iPad Filter Sheet — Teal Accents ✅ completed

Apply `.tint(Theme.Colors.primary)` on picker. Sort buttons: `Theme.Colors.primary.opacity(0.1)` bg, teal checkmarks.

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` (iPhone)
- `ipad--14-12-sort-filter-sheet.png` (iPad)
- Filter/sort controls use teal, not system blue

### Task F.2: macOS Filter Control — Teal Active State 🔄 in-progress

Apply teal accent to macOS segmented control / filter in content area.

**VERIFY against (dark+light):**
- `desktop--03-2-macos-sidebar-items-list-dark-mode.png`
- `desktop--04-2-macos-sidebar-items-list-light-mode.png`
- Filter control shows teal active state

---

## Phase G: Item Detail View — Brand Styling (Spec Change 7)

**File:** `ListAll/ListAll/Views/ItemDetailView.swift` (file already exists — style existing view, NOT creating new)

### Task G.1: Status Badge — Capsule Styling ✅ completed

Replace current icon+text status with styled capsule: "Active" teal capsule (dot + text) / "Completed" green capsule (checkmark + text).

**VERIFY against:**
- `iphone--03-3-item-detail-view.png` (iPhone)
- `ipad--06-6-item-detail-view.png` (iPad)
- Status shows as colored capsule badge, not plain text

### Task G.2: Detail Card Icons — Brand Teal ✅ completed

Use `Theme.Colors.primary` for detail card icons (quantity, images) instead of system colors.

**VERIFY against:**
- `iphone--03-3-item-detail-view.png` — info card icons should be teal
- `ipad--06-6-item-detail-view.png` — same on iPad

### Task G.3: "Mark as Completed" Button — Capsule ✅ completed

Style the toggle button: white text on green capsule (for "Mark as Completed") / white text on teal capsule (for "Mark as Active").

**VERIFY against:**
- `iphone--03-3-item-detail-view.png` (iPhone)
- `ipad--06-6-item-detail-view.png` (iPad)
- Action button is prominent colored capsule

---

## Phase H: Archived List View Polish (Spec Change 8)

**File:** `ListAll/ListAll/Views/ArchivedListView.swift`

### Task H.1: Orange Archived Badge ✅ completed

Replace current archive indicator with orange "Archived" capsule: archivebox icon + "Archived" text in `.orange`, with `orange.opacity(0.12)` background capsule.

**VERIFY against:**
- `iphone--07-7a-archived-lists-overview.png` (iPhone)
- `ipad--08-8a-archived-lists-overview.png` (iPad)
- Archived badge is orange capsule

### Task H.2: Toolbar Buttons + Item Row Styling ✅ completed

Restore button → `Theme.Colors.primary`. Archived items: strikethrough + `.secondary` + `.opacity(0.6)`.

**VERIFY against:**
- `iphone--08-7b-archived-list-view.png` (iPhone)
- `ipad--09-8b-archived-list-view.png` (iPad)
- Restore button teal, items muted

---

## Phase I: Settings Accent Colors (Spec Change 9)

**Files:** `ListAll/ListAll/Views/SettingsView.swift`, `ListAll/ListAllMac/Views/MacSettingsView.swift`

### Task I.1: iOS/iPad Settings — Toggle Tints + Button Colors ✅ completed

All toggles: `.tint(Theme.Colors.primary)`. Export/Import buttons: `.foregroundColor(Theme.Colors.primary)`. About icon: `Theme.Colors.primary`.

**VERIFY against:**
- `iphone--09-8a-settings-view-top.png` (iPhone top)
- `iphone--10-8b-settings-view-bottom.png` (iPhone bottom)
- `ipad--10-9a-settings-view-top.png` (iPad top)
- `ipad--11-9b-settings-view-bottom.png` (iPad bottom)
- Toggles teal (not green), buttons teal (not blue)

### Task I.2: macOS Settings — Toggle Tints + Button Colors ✅ completed

Same changes in `MacSettingsView.swift`.

**VERIFY against (dark+light):**
- `desktop--09-5-macos-settings-window-dark-mode.png`
- `desktop--10-5-macos-settings-window-light-mode.png`
- macOS settings toggles and buttons use teal

---

## Phase J: Create/Edit Sheet Accent Colors (Spec Change 10)

**Files:** `ListAll/ListAll/Views/CreateListView.swift`, `ListAll/ListAll/Views/ItemEditView.swift`
**Note:** Check if macOS uses separate sheet views or shares iOS views. If separate, apply same changes to macOS equivalents.

### Task J.1: Create List Sheet — Teal Accent ✅ completed

"Create" button: `.foregroundColor(Theme.Colors.primary)`, `.fontWeight(.semibold)`.

**VERIFY against:**
- `iphone--11-9-create-list-sheet.png` (iPhone)
- `ipad--12-10-create-list-sheet.png` (iPad)
- `desktop--05-3-macos-create-list-sheet-dark-mode.png` (macOS dark)
- `desktop--06-3-macos-create-list-sheet-light-mode.png` (macOS light)
- Create button should be teal on all platforms

### Task J.2: Edit Item Sheet — Teal Accent ✅ completed

"Save" button and "Add Photo" button: `.foregroundColor(Theme.Colors.primary)`.

**VERIFY against:**
- `iphone--12-10-edit-item-sheet.png` (iPhone)
- `ipad--13-11-edit-item-sheet.png` (iPad)
- `desktop--07-4-macos-edit-item-sheet-dark-mode.png` (macOS dark)
- `desktop--08-4-macos-edit-item-sheet-light-mode.png` (macOS light)
- Save and camera buttons should be teal on all platforms

---

## Phase K: macOS Empty States (Spec Change 11)

**File:** `ListAll/ListAllMac/Views/Components/MacNoListSelectedView.swift` + other empty state views

### Task K.1: No List Selected — Brand Styling `completed`

Icon: `.secondary.opacity(0.4)`. Subtitle: "Select a list from the sidebar or create a new one." CTA button: `.tint(Theme.Colors.primary)`.

**VERIFY against (dark+light):**
- `desktop--01-1-macos-sidebar-no-list-selected-dark-mode.png`
- `desktop--02-1-macos-sidebar-no-list-selected-light-mode.png`
- Empty state has teal CTA button, proper subtitle

### Task K.2: Other macOS Empty States — No Items + All Done + Welcome + Search `completed`

Verify/update remaining empty states to match mockups: teal CTA buttons, teal icons, proper text.

**VERIFY against (dark+light pairs):**
- `desktop--11-6a-macos-empty-state-no-items-yet-dark-mode.png` + `desktop--12-6a-macos-empty-state-no-items-yet-light-mode.png`
- `desktop--13-6b-macos-empty-state-all-done-dark-mode.png` + `desktop--14-6b-macos-empty-state-all-done-light-mode.png`
- `desktop--15-6c-macos-empty-state-welcome-no-lists-dark-mode.png` + `desktop--16-6c-macos-empty-state-welcome-no-lists-light-mode.png`
- `desktop--17-7-macos-search-empty-state-dark-mode.png` + `desktop--18-7-macos-search-empty-state-light-mode.png`

---

## Phase M: Verification-Only — Empty States + Lists Overview

These screens were marked "Already Done" in the spec but were UNTESTED in the investigation. Verify they match mockups; fix if they don't.

### Task M.1: iPhone Lists Overview — AccentColor Verification

Verify that the AccentColor asset makes toolbar icons, tab bar, and count colors teal (not system blue). If not, add explicit `.tint(Theme.Colors.primary)` where needed.

**VERIFY against:** `iphone--01-1-lists-overview.png` — toolbar icons, tab bar active color, count numbers should all be teal

### Task M.2: iPhone Empty States

Verify empty states match mockups. Fix accent colors if still system blue.

**VERIFY against:**
- `iphone--04-4-lists-empty-state-welcome.png`
- `iphone--05-5-items-empty-state-no-items.png`
- `iphone--06-6-all-done-celebration.png`

### Task M.3: iPad Empty States

Verify empty states match mockups. Fix accent colors if still system blue.

**VERIFY against:**
- `ipad--03-3-no-list-selected.png`
- `ipad--04-4-empty-state-no-items-yet.png`
- `ipad--05-5-empty-state-all-done.png`
- `ipad--07-7-lists-empty-state-welcome.png`
- `desktop--21-10-ipad-no-list-selected-dark-mode.png`
- `desktop--22-10-ipad-no-list-selected-light-mode.png`

### Task M.4: watchOS Empty States

Verify empty states match mockups where possible (may require data manipulation).

**VERIFY against:**
- `watchos--04-4-empty-state-no-lists.png`
- `watchos--05-5-empty-state-all-done.png`
- `watchos--06-6-empty-state-no-active-items.png`
- `watchos--07-7-empty-state-no-completed-items.png`

### Task M.5: watchOS Transient States (Best-Effort)

Verify loading, sync, and error states if reproducible.

**VERIFY against (best-effort):**
- `watchos--08-8-loading-state.png`
- `watchos--09-9-sync-indicator.png`
- `watchos--10-10-error-state.png`

---

## Phase N: Inline Filter Pills (All / Active / Done)

**Files:** `ListAll/ListAll/Views/ListView.swift`, `ListAll/ListAllMac/Views/MacMainView.swift` (content area, lines ~1673-1705)

Design shows a horizontal "All / Active / Done" pill bar inline above items. Currently: iOS has no inline filter (hidden in sheet), macOS has a system `Picker(.segmented)` with 3 options (lines 1673-1705).

**Enum:** `ItemFilterOption` (in `ListAll/ListAll/Models/Item.swift`, lines 45-83) has 5 cases: `.all`, `.active`, `.completed`, `.hasDescription`, `.hasImages`. The inline pills only expose the first 3 (All/Active/Done). The full Sort & Filter sheet (Phase O) exposes all 5.

**Connection:** Use `viewModel.currentFilterOption` / `viewModel.updateFilterOption()` — same binding the sheet uses.

### Task N.1: iOS/iPad Inline Filter Pills ✅ completed

Add an `HStack` of 3 teal pill capsule buttons in `ListView.swift` between the header section (line ~90) and items section (line ~93). Insert as a new row inside the header `Section` or as a separate section. Three pills: "All", "Active", "Done" mapping to `.all`, `.active`, `.completed`. Selected: `Theme.Colors.primary` fill + white text. Unselected: `Color.clear` with muted border + secondary text. Use `Capsule()` clip shape.

**Edge case — sheet-only filters:** When the user selects "With Photos" (`.hasImages`) in the Sort & Filter sheet, `currentFilterOption` is `.hasImages` which has no matching inline pill. In this case, all 3 pills should appear deselected (none highlighted). Tapping any pill overrides the sheet filter back to that option. This is the simplest UX — pills are quick-access shortcuts, not a complete filter display.

`ListView` is shared between iPhone and iPad — one implementation covers both.

**Label:** Use "Done" for the third pill (not "Completed") — shorter, matches mockup. macOS segmented control currently uses "Completed" — update to "Done" for consistency.

**VERIFY against:**
- `iphone--02-2-items-list.png` — pills below "4 of 6 items", above first card (dark + light)
- `ipad--01-1-sidebar-items-list.png` — pills in detail area (dark)
- `ipad--02-2-sidebar-items-list-light.png` — pills in detail area (light)

### Task N.2: macOS Inline Filter Pills ✅ completed

Replace the system `Picker(.segmented)` in `MacMainView.swift` (line ~1681, `filterSortControls`) with matching teal pill-style `HStack`. Same 3 options (All/Active/Done), same visual treatment as iOS: teal filled for selected, muted for unselected. Keep the separate Sort button (arrow icon) that opens `MacSortOnlyView` popover — only replace the filter picker.

**VERIFY against (dark+light):**
- `desktop--03-2-macos-sidebar-items-list-dark-mode.png`
- `desktop--04-2-macos-sidebar-items-list-light-mode.png`
- Filter pills should be teal capsules, not system segmented control

---

## Phase O: Sort & Filter Sheet Redesign

**File:** `ListAll/ListAll/Views/Components/ItemOrganizationView.swift` (194 lines)

Current: `Form`-based sheet titled "Organization" with 2-column grid sort buttons (using `Color.blue.opacity(0.1)`), list-row filter options, and HStack summary rows. Toolbar: conditional "Reset" (red) + "Done".

Design: Pill-style buttons throughout, title "Sort & Filter", teal accents, stat cards.

**Enums (in `Item.swift`):**
- `ItemSortOption`: `.orderNumber` ("Order"), `.title` ("Title"), `.createdAt` ("Created Date"), `.modifiedAt` ("Modified Date"), `.quantity` ("Quantity")
- `ItemFilterOption`: `.all`, `.active`, `.completed`, `.hasDescription`, `.hasImages`
- Mockup shows short labels: "Order", "A-Z", "Qty", "Created", "Modified" — use these as pill labels

**ViewModel methods:** `viewModel.updateSortOption()`, `viewModel.updateSortDirection()`, `viewModel.updateFilterOption()`, `viewModel.clearAllFilters()`, `viewModel.hasActiveFilters`

### Task O.1: Sheet Title + Toolbar

Change `.navigationTitle("Organization")` → `.navigationTitle("Sort & Filter")`. Toolbar: "Reset" (left, **keep red** — matches mockup and iOS destructive action convention) + "Done" (right, **teal** via `Theme.Colors.primary`). Keep conditional Reset visibility based on `viewModel.hasActiveFilters`.

**Localization:** New title "Sort & Filter" needs Finnish translation. Add to `Localizable.strings`.

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` — title "Sort & Filter", Reset (teal) + Done (teal)

### Task O.2: Sort By — Pill Buttons

Replace `LazyVGrid` (lines 16-45) with teal pill capsule buttons in a wrapping `FlowLayout` or `LazyVGrid(columns: 3)`. 5 pills with short labels: "Order", "A-Z", "Qty", "Created", "Modified". Selected: `Theme.Colors.primary` fill + white text. Unselected: muted border capsule. Remove checkmark icons. Section header: "SORT BY" (uppercase, muted, like mockup).

**Implementation:** Add a `shortDisplayName` computed property to `ItemSortOption` enum (in `Item.swift`) returning the abbreviated labels. Keep existing `displayName` unchanged — it's used by `MacSortOnlyView` and other consumers. Finnish translations needed for all short names. Remove the "Drag-to-reorder enabled/disabled" note (lines 74-93) — not in mockup.

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` — "SORT BY" section with 5 pill buttons (3+2 layout)

### Task O.3: Sort Direction — Two Pill Buttons

Replace single direction toggle (lines 48-72) with two side-by-side pills: "Ascending" / "Descending". Selected: teal filled + white text. Unselected: muted border. Section header: "SORT DIRECTION". Remove the arrow icon.

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` — "SORT DIRECTION" with two equal-width pills

### Task O.4: Filter — Chip Buttons

Replace list-row filter options (lines 100-131) with capsule chips in a wrapping layout. 4 visible chips: "All", "Active", "Completed", "With Photos" (map to `.all`, `.active`, `.completed`, `.hasImages`). Drop `.hasDescription` — not in mockup, minor feature reduction. Selected: teal filled. Section header: "FILTER".

**Localization:** New section headers ("SORT BY", "SORT DIRECTION", "FILTER", "SUMMARY") and chip labels need Finnish translations.

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` — "FILTER" section with 4 chip buttons

### Task O.5: Summary — Stat Cards

Replace HStack summary rows (lines 134-166) with horizontal stat card bar. 4 cards: "Total" (white/muted), "Filtered" (white/muted), "Active" (teal number), "Completed" (green number). Card background: subtle rounded rect. Section header: "SUMMARY".

**VERIFY against:**
- `iphone--13-11-sort-filter-sheet.png` — "SUMMARY" section with 4 inline stat cards
- `ipad--14-12-sort-filter-sheet.png` — same on iPad

---

## Phase Q: Archived List Layout Changes

**Files:** `ListAll/ListAll/Views/Components/ListRowView.swift` (lines 61-94), `ListAll/ListAll/Views/ArchivedListView.swift`

Design mockups show archived lists overview with simple rows + chevrons for drill-down (NO inline Restore/Delete buttons). Current: `ListRowView.swift` lines 61-94 render an `HStack` with Restore pill button (`Color.accentColor.opacity(0.1)` bg, radius 8) and Delete trash icon button when `mainViewModel.showingArchivedLists` is true. These appear inline in every archived row on both iPhone and iPad.

### Task Q.1: Remove Inline Restore/Delete from Archived List Overview

Remove the conditional HStack at `ListRowView.swift` lines 61-94 that shows Restore/Delete buttons inline in archived rows. Keep the simple row layout: name + count subtitle + chevron for navigation. Restore/Delete remain in `ArchivedListView.swift` toolbar (lines 83-106) where they belong per design.

**VERIFY against:**
- `iphone--07-7a-archived-lists-overview.png` — clean rows with chevrons, no inline buttons
- `ipad--08-8a-archived-lists-overview.png` — sidebar shows clean rows without inline actions

### Task Q.2: Verify iPhone Drill-Down into Archived List Items

Exploration confirmed drill-down already works (NavigationLink pushes `ArchivedListView`). Take screenshots to verify and fix if needed.

**VERIFY against:**
- `iphone--08-7b-archived-list-view.png` — detail view with title, orange "Archived" badge, read-only items, Restore/Delete in toolbar only

---

## Execution Order Summary

| Phase | Description | Platform(s) | Key Files | Tasks |
|-------|-------------|-------------|-----------|-------|
| A | macOS Sidebar (Spec 1) | macOS | MacMainView.swift | A.1–A.3 |
| B | iOS Item Rows — Cards (Spec 2) | iPhone + iPad | ItemRowView.swift, ListView.swift | B.1–B.6 |
| C | macOS Item Rows — Cards (Spec 3) | macOS | MacMainView.swift | C.1 |
| D | iPad Sidebar Selection (Spec 4) | iPad | MainView.swift, ListRowView.swift | D.1 |
| E | watchOS Polish (Spec 5+12) | watchOS | WatchListRowView, WatchItemRowView, WatchListView, WatchFilterPicker | E.1–E.4 |
| F | Filter/Sort Accent Colors (Spec 6) | iPhone, iPad, macOS | ItemOrganizationView.swift | F.1–F.2 |
| G | Item Detail Styling (Spec 7) | iPhone, iPad | ItemDetailView.swift | G.1–G.3 |
| H | Archived List Styling (Spec 8) | iPhone, iPad | ArchivedListView.swift | H.1–H.2 |
| I | Settings Accents (Spec 9) | iPhone, iPad, macOS | SettingsView.swift, MacSettingsView.swift | I.1–I.2 |
| J | Create/Edit Accents (Spec 10) | iPhone, iPad, macOS | CreateListView.swift, ItemEditView.swift | J.1–J.2 |
| K | macOS Empty States (Spec 11) | macOS | MacNoListSelectedView.swift + others | K.1–K.2 |
| M | Verification — Empty States | All | Various | M.1–M.5 |
| N | Inline Filter Pills (new) | iPhone, iPad, macOS | ListView.swift, MacMainView.swift | N.1–N.2 |
| O | Sort & Filter Sheet Redesign (new) | iPhone, iPad | ItemOrganizationView.swift | O.1–O.5 |
| Q | Archived List Layout (new) | iPhone, iPad | ListRowView.swift, ArchivedListView.swift | Q.1–Q.2 |

**Recommended execution order:**
1. Phases A–K (spec changes 1–12, accent colors + card styling + platform polish)
2. Phase N (inline filter pills — depends on B/C card styling being done first)
3. Phase O (sort & filter redesign — can be done independently)
4. Phase Q (archived layout — do after H which styles archived views)
5. Phase M (verification sweep — final pass after all changes)

**Total: 15 phases, 38 tasks, each with mandatory visual verification loop against specific mockup PNGs**

**All 62 design mockup PNGs are covered by at least one task's verification step.**
