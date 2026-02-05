# Plan: Add New iPhone/iPad/macOS App Store Screenshots

## Summary

Add richer screenshots showing the app in action across all platforms. Reorder for maximum App Store impact (most compelling first). Bundle realistic test photos.

- **iOS**: 7 screenshots per device per locale (reordered, compelling-first)
- **macOS**: 7 screenshots per locale (QuickEntry replaces Settings)

## New Screenshot Order (Both Platforms)

App Store shows first 3 without scrolling — lead with the strongest:

| # | iOS | macOS | What it shows |
|---|-----|-------|--------------|
| 01 | Main screen with lists | Main window + sidebar | Populated app overview |
| 02 | Open list (Grocery) | List detail (Grocery) | Items with details |
| 03 | Item edit with images | Item edit with images | Rich item details + photos |
| 04 | Completed items (Travel) | QuickEntry window | Completion/power features |
| 05 | Sort/filter options | Completed items + undo | Organization tools |
| 06 | Archived lists | Filters in action | Archive/filter |
| 07 | Welcome/empty state | Archived lists expanded | Templates/archive |

---

## Part A: iOS/iPad Screenshots

### Files to Modify

1. **`ListAll/ListAll/Views/MainView.swift`** — Add `accessibilityIdentifier("ArchiveToggleButton")`
2. **`ListAll/ListAll/Views/ListView.swift`** — Add `accessibilityIdentifier("SortFilterButton")`, `accessibilityIdentifier("AddItemButton")`, `accessibilityIdentifier("UndoCompleteBanner")`
3. **`ListAll/ListAllUITests/ListAllUITests_Simple.swift`** — Rewrite test 01/02 numbering + add 5 new tests
4. **`ListAll/ListAll/Services/UITestDataService.swift`** — Replace colored rectangles with bundled photo assets
5. **`fastlane/Snapfile`** — Update `only_testing` array (7 tests)
6. **`fastlane/Framefile.json`** — Reorder + add entries

### Step A1: Add Accessibility Identifiers

| File | Element | Identifier |
|------|---------|-----------|
| `MainView.swift:~181` | Archive toggle button | `"ArchiveToggleButton"` |
| `ListView.swift:~285` | Sort/filter toolbar button | `"SortFilterButton"` |
| `ListView.swift:~614` | Floating add item button | `"AddItemButton"` |
| `ListView.swift:~160` | Undo completion banner | `"UndoCompleteBanner"` |

### Step A2: Bundle Realistic Test Photos

Replace `generateTestImages()` in `UITestDataService.swift`:
- Add 2-3 small JPEG photos to the project as asset catalog or bundle resources
- Load from bundle instead of generating colored rectangles
- Keep photos small (~300x300, JPEG quality 0.7) to minimize test data size
- Same change needed for macOS `#elseif os(macOS)` section

### Step A3: Extend Undo Timer in Screenshot Mode

In `ListViewModel.swift`, check for `UITEST_SCREENSHOT_MODE` and extend `undoTimeout` from 5s to 30s. This prevents race condition where the undo banner auto-dismisses before the screenshot is captured.

### Step A4: iOS Test Methods (Reordered)

All tests reuse `launchAppWithRetry` + `waitForUIReady`. Each launches fresh.

#### `testScreenshots01_MainScreen` (was 02)
- Launch with test data (no SKIP_TEST_DATA)
- Wait for list cells to appear
- `snapshot("01_MainScreen")`

#### `testScreenshots02_OpenList`
- Launch with test data, wait for cells
- Tap first cell (Grocery Shopping / Ruokaostokset)
- Wait for items to load
- `snapshot("02_OpenList")`

#### `testScreenshots03_ItemWithImages`
- Navigate to Grocery Shopping list
- Tap the 3rd `ItemDetailButton` chevron (Eggs is at orderNumber 2, index 2)
- This opens ItemEditView directly as sheet (no intermediate detail view)
- Wait for `"SaveButton"` to confirm sheet appeared
- Dismiss keyboard to show image thumbnails
- `snapshot("03_ItemWithImages")`

**Key insight from critic**: Tapping content area toggles completion. The chevron button (`accessibilityIdentifier("ItemDetailButton")`) opens edit sheet directly. All chevrons share the same identifier — use `app.buttons.matching(identifier: "ItemDetailButton").element(boundBy: 2)` since Eggs is deterministically the 3rd item.

#### `testScreenshots04_CompletedItems`
- Navigate to **Travel Packing** / **Matkapakkaus** (4th list, orderNumber 3)
- This list already has natural mix: Passport completed, 3 active items
- Tap first item content to toggle it as completed
- Wait for `"UndoCompleteBanner"` to appear
- `snapshot("04_CompletedItems")`

**Different list from 02/03** to avoid visual duplication.

#### `testScreenshots05_SortFilter`
- Navigate to first list
- Tap `"SortFilterButton"` → ItemOrganizationView sheet appears
- Wait for sheet navigation bar
- `snapshot("05_SortFilter")`

#### `testScreenshots06_ArchivedLists`
- Stay on main screen, tap `"ArchiveToggleButton"`
- Wait for archived list to appear
- `snapshot("06_ArchivedLists")`

#### `testScreenshots07_WelcomeScreen` (was 01)
- Launch with `SKIP_TEST_DATA` (empty state)
- `snapshot("07_WelcomeScreen")`

### Step A5: Update Snapfile

```ruby
only_testing([
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots01_MainScreen",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots02_OpenList",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots03_ItemWithImages",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots04_CompletedItems",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots05_SortFilter",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots06_ArchivedLists",
  "ListAllUITests/ListAllUITests_Screenshots/testScreenshots07_WelcomeScreen"
])
```

### Step A6: Update Framefile.json (Reordered)

| Screenshot | English Title | Finnish Title |
|-----------|--------------|---------------|
| 01_MainScreen | "All Your Lists at a Glance" | "Kaikki Listat Yhdellä Silmäyksellä" |
| 02_OpenList | "Everything in One Place" | "Kaikki Yhdessä Paikassa" |
| 03_ItemWithImages | "Capture Every Detail" | "Tallenna Jokainen Yksityiskohta" |
| 04_CompletedItems | "Check Off as You Go" | "Merkitse Valmiiksi Lennossa" |
| 05_SortFilter | "Find Anything Instantly" | "Löydä Mikä Tahansa Hetkessä" |
| 06_ArchivedLists | "Done Lists, Out of Sight" | "Valmiit Listat Pois Näkyvistä" |
| 07_WelcomeScreen | "Organize Anything Instantly" | "Järjestä Kaikki Hetkessä" |

---

## Part B: macOS Screenshots

### Current → New

| # | Current | New |
|---|---------|-----|
| 01 | MainWindow | **Keep** |
| 02 | ListDetailView | **Keep** |
| 03 | ItemEditSheet (empty) | **Modify**: Edit Eggs item (shows images) |
| 04 | SettingsWindow | **Replace**: QuickEntry window |
| 05 | — | **New**: CompletedItems + undo banner |
| 06 | — | **New**: Filters (Done selected) |
| 07 | — | **New**: ArchivedLists (expanded) |

### Files to Modify

1. **`ListAll/ListAllMacUITests/MacScreenshotTests.swift`** — Modify test 03, replace test 04, add tests 05-07
2. **`fastlane/Fastfile`** — Update expected count from 4 to 7 (~line 4220)

### macOS Accessibility IDs (Already Exist)

- `"ListsSidebar"`, `"ItemsList"`, `"AddItemButton"`, `"SortButton"`
- `"FilterSegmentedControl"`, `"UndoCompleteBanner"`
- `"QuickEntryView"`, `"QuickEntryTitleField"`, `"QuickEntryListPicker"`
- Archived section: `accessibilityLabel("Archived lists")`

### Step B1: Modify `testScreenshot03_ItemEditSheet`

**Use doubleClick() — single click does NOT open edit sheet on macOS.**

1. Select first list in sidebar
2. Find Eggs/Kananmunat in items table using NSPredicate: `app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Eggs' OR label CONTAINS 'Kananmunat'")).firstMatch`
3. **doubleClick()** on the item row to trigger `onEdit()` → opens edit sheet
4. Wait for sheet element to appear
5. `snapshot("03_ItemEditSheet")`

### Step B2: Replace `testScreenshot04_SettingsWindow` → QuickEntry

1. Launch, prepare window
2. Open QuickEntry via `app.typeKey(" ", modifierFlags: [.command, .option])` (Cmd+Option+Space)
3. Wait for `"QuickEntryView"` to appear
4. `snapshot("04_QuickEntry")`

### Step B3: Add `testScreenshot05_CompletedItems`

**Cannot click checkbox — use keyboard Space key instead.**

macOS item rows use `.accessibilityElement(children: .combine)` which merges all children. Cannot traverse into checkbox button.

1. Select first list, wait for items
2. Click on the first item row to focus it
3. Press Space key: `app.typeKey(" ", modifierFlags: [])` → toggles completion
4. Wait for `"UndoCompleteBanner"` to appear
5. `snapshot("05_CompletedItems")`

### Step B4: Add `testScreenshot06_Filters`

**Use Cmd+3 keyboard shortcut — filter segment labels are locale-dependent.**

1. Select first list
2. Press `Cmd+3`: `app.typeKey("3", modifierFlags: .command)` → sets "Completed Only" filter
3. Wait for list to update (only completed items visible)
4. `snapshot("06_Filters")`

### Step B5: Add `testScreenshot07_ArchivedLists`

1. Launch, prepare window
2. Scroll sidebar down if needed
3. Find archived section header: `app.buttons.matching(NSPredicate(format: "label == 'Archived lists'")).firstMatch`
4. Click to expand
5. Wait for archived list row to appear (0.15s animation)
6. Click on archived list
7. `snapshot("07_ArchivedLists")`

### Step B6: Update Fastfile Validation

Line ~4220: Change expected count from 4 to 7.

---

## Test Data Changes

### Bundle Realistic Photos

Replace `generateTestImages()` in `UITestDataService.swift` (both iOS and macOS sections):
- Add 2-3 small photos to asset catalog or app bundle (e.g., `TestImage1.jpg`, `TestImage2.jpg`)
- Load via `UIImage(named:)` / `NSImage(named:)`
- Keep at ~300x300px, JPEG 0.7 quality
- Photos should look like real items (food, household items) — not colored rectangles

### Extend Undo Timer

In `ListViewModel.swift`, when `UITEST_SCREENSHOT_MODE` launch arg is present, set `undoTimeout = 30.0` instead of `5.0`.

---

## Verification

### iOS
1. Build and run individual tests on iPhone simulator
2. Boot simulator via MCP, launch with UITEST_MODE, take screenshots visually
3. Run with Finnish locale
4. Test on iPad simulator
5. Run `fastlane ios screenshots`

### macOS
1. Run `xcodebuild test -scheme ListAllMac -destination 'platform=macOS' -only-testing:ListAllMacUITests/MacScreenshotTests`
2. Run `fastlane ios screenshots_macos`
3. Verify with MCP `listall_screenshot_macos`
4. Run with Finnish locale

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| iOS chevron index fragility (Test 03) | Eggs is deterministically 3rd item (orderNumber 2). Use `buttons["ItemDetailButton"].element(boundBy: 2)` |
| macOS doubleClick() may not work on all rows | Existing test 03 avoided item clicks. Fallback: use `AddItemButton` then navigate to Eggs edit from there |
| Archived section below scroll fold (macOS) | Add scroll-down before finding header button |
| Locale-dependent text queries | Use NSPredicate with OR conditions for en/fi |
| Undo banner timing | Extended to 30s in screenshot mode |
| QuickEntry window may be behind main window | Use `app.windows["Quick Entry"]` to bring to front |

Note: Screenshots are generated locally only, not in CI.
