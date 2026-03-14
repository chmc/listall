# UI Polish: Design vs Implementation — Full Comparison Report

## Context

Complete visual comparison of ALL 60 design mockups across 4 platforms against actual app on `feature/ui-polish` branch.

- **Design spec:** `docs/superpowers/specs/2026-03-12-ui-polish-design.md`
- **Design mockups:** `.superpowers/brainstorm/57429-1773298544/screens/`
- **Screenshots captured:** `.listall-mcp/260314-120150-phase1-macos-main/`

---

## Design Spec Change Status (Verified)

| # | Change | Spec Says | Verified Status | Reality |
|---|--------|-----------|-----------------|---------|
| 1 | macOS Sidebar | COMPLETED | **NOT DONE** | Count format still `4 (6)` not `4/6`; selection uses system blue highlight not teal left border; section headers not uppercase 9px |
| 2 | iOS Item Rows | COMPLETED | **NOT DONE** | Flat rows with dividers, not card-based; checkboxes present but not teal-styled; quantity badges are light blue not teal; no press feedback |
| 3 | macOS Item Rows | COMPLETED | **NOT DONE** | Flat rows with dividers, not card-based; quantity badges gray not teal; no hover states on cards |
| 4 | iPad Sidebar | NOT IMPLEMENTED | **NOT DONE** | Selection uses blue left border (partially done) but text is black not teal; count format `4/6 items` is correct |
| 5 | watchOS Polish | NOT IMPLEMENTED | **NOT DONE** | Zero changes: count `4 (6) items` not `4/6`, no progress bars, checkboxes still present (should be removed), no teal branding, status row uses icons not text |
| 6 | Filter/Sort Accents | NOT IMPLEMENTED | **NOT DONE** | System blue throughout, not teal; filter uses sheet not inline pills |
| 7 | Item Detail View | NOT IMPLEMENTED | **NOT DONE** | View doesn't exist — chevron goes to Edit Item sheet directly |
| 8 | Archived List View | COMPLETED | **PARTIAL** | Archived badge exists but styling differs; inline Restore/Delete buttons in sidebar rows (not in design); no drill-down to archived items on iPhone |
| 9 | Settings View | COMPLETED | **PARTIAL** | Layout correct; toggle tints are system green not teal; Export/Import buttons system blue not teal; section headers gray not teal |
| 10 | Create/Edit Sheets | COMPLETED | **PARTIAL** | Layout correct; Cancel/Save/Create buttons system blue not teal; templates section missing from Create List |
| 11 | macOS No List Selected | COMPLETED | **PARTIAL** | Text present; CTA button is gray/dark not teal; icon is gray clipboard not teal list icon; subtitle text differs |
| 12 | watchOS Filter Picker | COMPLETED | **NOT DONE** | Filter uses modal sheet (X dismiss) not push navigation; no teal highlight on selected option; uses system gray highlight |

**Overall: ~15% complete** (infrastructure exists but views not updated; spec incorrectly marked 7 items as COMPLETED)

---

## Cross-Platform Gap Summary

### Gap 1: System Blue vs Brand Teal (ALL platforms)

The single most pervasive issue. Design uses teal/cyan (`#00B4DC`/`#7DD8F0`) as brand accent throughout. Actual app uses system blue everywhere:

| Location | Affected Platforms |
|----------|--------------------|
| Toolbar icons | iPhone, iPad, macOS |
| Tab bar active color | iPhone |
| Back button color | iPhone |
| Cancel/Save/Create/Done buttons | iPhone, iPad |
| Toggle tints (system green) | iPhone, iPad, macOS |
| Export/Import Data buttons | iPhone, iPad |
| Count number coloring | macOS, watchOS |
| Quantity badge color | iPhone, iPad, macOS |
| Sort/filter selected state | iPhone, iPad, macOS |
| Sidebar selection text | macOS, iPad |
| Nav title | watchOS |
| Checkbox borders | iPhone, iPad, macOS |

**Fix:** App-wide `.tint(Theme.Colors.primary)` or `.accentColor` asset update, plus targeted per-view fixes.

### Gap 2: Flat Rows vs Card-Based Items (iPhone, iPad, macOS)

Design shows items as discrete rounded-rectangle cards with:
- 12px corner radius (iOS) / 10px (macOS)
- Dark: `white.opacity(0.03)` fill + `primary.opacity(0.06)` border
- Light: white fill + `black.opacity(0.04)` shadow
- Hidden list row separators

Actual: Standard flat list rows with thin horizontal dividers on ALL platforms.

**Files:** `ItemRowView.swift`, `ListView.swift`, `MacMainView.swift`

### Gap 3: macOS Sidebar Selection (macOS)

| Element | Design | Actual |
|---------|--------|--------|
| Selection indicator | 3px teal left border + `primary.opacity(0.08)` bg + right-rounded corners | Full system blue/white highlight rectangle |
| Selected text | Teal text, weight 600 | White text on blue bg |
| Count format | `4/6` | `4 (6)` |
| Section headers | "LISTS" uppercase 9px, tracking 1.2px, 0.5 opacity | "Lists" title case |

**File:** `MacMainView.swift` (MacSidebarView ~line 602+)

### Gap 4: watchOS — Zero Design Changes (watchOS)

| Element | Design | Actual |
|---------|--------|--------|
| Count format | `4/6` teal + "items" muted | `4 (6) items` all gray |
| Progress bars | 32x3px teal-to-green gradient | None |
| Checkboxes | Removed (tap-to-toggle) | Blue circles present |
| Quantity display | Right-aligned teal "x2" | Inline gray "x2" |
| Nav title | Teal-tinted | White default |
| Status row | "4 active 2 done 6 total" text | Icon-based indicators |
| Dividers | `white.opacity(0.06)` thin | Default thick |
| Filter picker | Push nav with teal highlight | Modal sheet, gray highlight |

**Files:** `WatchListRowView.swift`, `WatchItemRowView.swift`, `WatchListView.swift`, `WatchFilterPicker.swift`

### Gap 5: Missing Item Detail View (iPhone, iPad)

Design shows a dedicated read-only Item Detail View with:
- Status badge ("Active" teal / "Completed" green capsule)
- Description text display
- Quantity and Images info cards
- "Mark as Completed" action button

Actual: No such view exists. Tapping chevron goes directly to Edit Item sheet.

**File:** New `ItemDetailView.swift` needed (spec Change 7)

### Gap 6: Filter/Sort UI Differences (iPhone, iPad, macOS)

| Element | Design | Actual |
|---------|--------|--------|
| Inline filter | "All / Active / Done" teal pills above items | No inline filter; hidden in sheet |
| Sheet title | "Sort & Filter" | "Organization" |
| Filter controls | Chip/pill buttons | Full list rows |
| Sort direction | Two pill buttons | Single button |
| Summary section | Inline stat cards | List format |

### Gap 7: Archived List Differences (iPhone, iPad)

- iPhone: No drill-down into archived list items (design shows separate view with orange "Archived" badge)
- iPad: Inline Restore/Delete buttons in sidebar rows (design keeps these in detail header only)
- Both: Missing orange "Archived" capsule badge styling

### Gap 8: Missing Templates in Create List (iPhone, iPad)

Design shows 4 templates (Shopping List, Travel Checklist, Books to Read, To-Do List) in Create List sheet. Actual shows only a text field.

---

## Implementation Task List (Prioritized)

### Priority 1: Brand Accent Color System (Highest Impact, Lowest Effort)

All platforms benefit from switching system blue to brand teal.

- [ ] **P1.1** Set AccentColor asset to brand teal across all targets (if not already)
- [ ] **P1.2** macOS Settings: toggle tints → `Theme.Colors.primary` (`MacSettingsView.swift`)
- [ ] **P1.3** iOS Settings: toggle tints → `Theme.Colors.primary` (`SettingsView.swift`)
- [ ] **P1.4** iOS Settings: Export/Import buttons → `Theme.Colors.primary`
- [ ] **P1.5** iOS Create List sheet: Cancel/Create buttons → teal accent
- [ ] **P1.6** iOS Edit Item sheet: Cancel/Save buttons → teal accent
- [ ] **P1.7** macOS No List Selected: CTA button → `.tint(Theme.Colors.primary)`
- [ ] **P1.8** watchOS: `.accentColor` for nav titles, back buttons

### Priority 2: macOS Sidebar (High Impact)

- [ ] **P2.1** Count format: `4 (6)` → `4/6` with `.monospacedDigit()`
- [ ] **P2.2** Selection: replace system highlight with 3px teal left border + tinted bg
- [ ] **P2.3** Selected text: teal color, weight 600
- [ ] **P2.4** Section headers: "LISTS" uppercase 9px, tracking 1.2px, 0.5 opacity

### Priority 3: Card-Based Item Rows (High Impact, High Effort)

- [ ] **P3.1** iOS `ItemRowView.swift`: Add card background (rounded rect, dark border / light shadow)
- [ ] **P3.2** iOS `ListView.swift`: `.listRowSeparator(.hidden)`, card insets
- [ ] **P3.3** iOS: Teal checkbox circles (active) + green checkmark circles (completed)
- [ ] **P3.4** iOS: Teal capsule quantity badges with `x` prefix
- [ ] **P3.5** iOS: `.opacity(0.5)` on completed rows (unified)
- [ ] **P3.6** iOS: `CardPressStyle` for press feedback
- [ ] **P3.7** macOS `MacMainView.swift`: Same card treatment (10px radius, 20px checkbox)
- [ ] **P3.8** macOS: Hover state on cards (`white.opacity(0.05)` on hover)
- [ ] **P3.9** iPad: Same card treatment as iOS (shared `ItemRowView`)

### Priority 4: iPad Sidebar Selection

- [ ] **P4.1** Selected row: teal left border + teal text + tinted bg (currently blue)
- [ ] **P4.2** Count format already `4/6 items` — just fix accent color to teal

### Priority 5: watchOS Polish (Medium Impact)

- [ ] **P5.1** `WatchListRowView`: Count format `4/6` + "items" muted + progress bar
- [ ] **P5.2** `WatchItemRowView`: Remove checkboxes, left-aligned text, teal quantity right-aligned
- [ ] **P5.3** `WatchListView`: Status counts as text labels ("4 active 2 done 6 total")
- [ ] **P5.4** List divider tint: `.listRowSeparatorTint(Color.white.opacity(0.06))`
- [ ] **P5.5** `WatchFilterPicker`: Push navigation with teal highlight (currently modal)

### Priority 6: Filter/Sort Accent Colors

- [ ] **P6.1** `ItemOrganizationView.swift`: `.tint(Theme.Colors.primary)` on picker
- [ ] **P6.2** Sort buttons: `Theme.Colors.primary.opacity(0.1)` bg, teal checkmarks
- [ ] **P6.3** macOS filter segmented control: teal active state

### Priority 7: Item Detail View (New Screen)

- [ ] **P7.1** Create `ItemDetailView.swift` with status badge, description, quantity/images cards
- [ ] **P7.2** "Mark as Completed" / "Mark as Active" teal/green capsule button
- [ ] **P7.3** Wire up navigation: chevron → detail view → edit button → edit sheet

### Priority 8: Archived List View Polish

- [ ] **P8.1** Orange "Archived" capsule badge on archived list detail
- [ ] **P8.2** Restore button: `Theme.Colors.primary` color
- [ ] **P8.3** Archived item rows: strikethrough + `.secondary` + `.opacity(0.6)`
- [ ] **P8.4** iPhone: Add drill-down into archived list items (currently missing)
- [ ] **P8.5** iPad: Remove inline Restore/Delete from sidebar rows (move to detail only)

### Priority 9: macOS Empty States Polish

- [ ] **P9.1** No List Selected: teal CTA button, teal list icon, updated subtitle
- [ ] **P9.2** No Items Yet: teal CTA "Add First Item", teal icon
- [ ] **P9.3** All Done: green circle checkmark, "6/6 items completed"
- [ ] **P9.4** Search empty: "No Results Found" with clear search button

### Out of Scope (Design Aspirational, Not in Spec)

These appear in mockups but are NOT in the design spec's 12 changes:
- Template suggestions in Create List sheet
- Inline filter pills on items list (design shows them but spec Change 6 only covers accent colors)
- "Sort & Filter" sheet redesign (layout changes beyond accent colors)
- Item Detail View as separate read-only screen (spec Change 7 only covers styling)

---

## Platform-Specific Detailed Findings

### iPhone (13 screens compared)

| Screen | Status | Key Differences |
|--------|--------|-----------------|
| 1. Lists Overview | PARTIAL | Count format correct (`4/6`); accent blue not teal; toolbar icons blue |
| 2. Items List | NOT DONE | Flat rows not cards; no inline filter pills; FAB gray not teal; checkboxes blue not teal |
| 3. Item Detail | MISSING | View doesn't exist — chevron goes to Edit sheet |
| 4. Welcome Empty | UNTESTED | Cannot test without deleting data; spec says "Already Done" |
| 5. No Items Empty | UNTESTED | Same as above |
| 6. All Done | UNTESTED | Same as above |
| 7a. Archived Lists | PARTIAL | Layout differs — inline Restore/Delete buttons visible |
| 7b. Archived List View | MISSING | No drill-down into archived list items |
| 8a. Settings Top | PARTIAL | Layout correct; toggle green not teal; section headers gray not teal |
| 8b. Settings Bottom | PARTIAL | Export/Import blue not teal; biometrics untestable |
| 9. Create List | PARTIAL | No templates; accent blue not teal |
| 10. Edit Item | PARTIAL | Labels differ slightly; accent blue not teal |
| 11. Sort/Filter | NOT DONE | Title "Organization" not "Sort & Filter"; list rows not pills |

### iPad (14 screens compared)

| Screen | Status | Key Differences |
|--------|--------|-----------------|
| 1. Sidebar+Items Dark | NOT DONE | Blue not teal selection; flat rows not cards; no filter pills |
| 2. Sidebar+Items Light | NOT DONE | Same issues in light mode |
| 3. No List Selected | PARTIAL | Title matches; missing subtitle and CTA button |
| 4. No Items Empty | UNTESTED | Cannot verify |
| 5. All Done Empty | UNTESTED | Cannot verify |
| 6. Item Detail | MISSING | View doesn't exist |
| 7. Welcome Empty | UNTESTED | Cannot verify |
| 8a. Archived Lists | PARTIAL | Different row layout with inline actions |
| 8b. Archived List View | PARTIAL | Orange badge text vs capsule; different action button styling |
| 9a. Settings Top | PARTIAL | Layout matches; accent colors off |
| 9b. Settings Bottom | PARTIAL | Same as iPhone |
| 10. Create List | PARTIAL | No templates; accent blue not teal |
| 11. Edit Item | PARTIAL | Labels differ; accent blue not teal |
| 12. Sort/Filter | NOT DONE | Different title, layout, controls |

### macOS (22 screens compared)

| Screen | Status | Key Differences |
|--------|--------|-----------------|
| 1-2. No Selection (D/L) | NOT DONE | Count `4(6)` not `4/6`; system highlight not teal border; CTA gray not teal |
| 3-4. Items List (D/L) | NOT DONE | Flat rows not cards; system segmented control not teal; gray badges |
| 5-6. Create List (D/L) | UNTESTED | Could not navigate to sheet |
| 7-8. Edit Item (D/L) | UNTESTED | Could not navigate to sheet |
| 9-10. Settings (D/L) | UNTESTED | Could not navigate to window |
| 11-14. Empty States (D/L) | UNTESTED | Could not reproduce states |
| 15-16. Welcome (D/L) | UNTESTED | Could not reproduce |
| 17-18. Search Empty (D/L) | UNTESTED | Could not reproduce |
| 19-22. iPad Views (D/L) | N/A | These are iPad mockups in desktop file set |

### watchOS (11 screens compared)

| Screen | Status | Key Differences |
|--------|--------|-----------------|
| 1. Lists Overview | NOT DONE | Count `4 (6)` not `4/6`; no progress bars; no teal nav; no teal counts |
| 2. Items + Filter | NOT DONE | Checkboxes present (should be removed); blue not teal; icons not text labels |
| 3. Completed Items | NOT DONE | Green checkmark circles present (should be removed); gray not teal quantity |
| 4-7. Empty States | UNTESTED | Cannot reproduce without data changes |
| 8-10. Loading/Sync/Error | UNTESTED | Transient states, not reproducible |
| 11. Filter Picker | NOT DONE | Modal sheet not push nav; gray highlight not teal |

---

## What Already Matches Design

- General layout structure (sidebar + detail on iPad/macOS, tab bar on iPhone)
- List row structure (name + count subtitle)
- iPhone count format `4/6 items` (correct format, just wrong color)
- iPad sidebar has left border selection indicator (just blue instead of teal)
- Item row content (title, description, quantity presence)
- Settings layout and sections
- Tab bar items (Lists + Settings)
- Dark/light mode support
- Completed items strikethrough
- Basic navigation flow
- Empty state infrastructure exists (per spec "Already Done")
