# iPad UX Redesign Plan

## Context

The ListAll iPad experience is a blown-up iPhone UI. On a 13" iPad Pro, the app shows a full-width single-column list with ~75% empty white space, a bottom tab bar (iPhone pattern), and no multi-column layout. It uses the deprecated `NavigationView` instead of `NavigationSplitView`, has zero `horizontalSizeClass` usage, and no context menus. The deployment target is iOS 16.0 (confirmed in `project.pbxproj`; the comment at `MainView.swift:138` saying "iOS 15" is stale). `NavigationSplitView` is available. The macOS version already implements this pattern at `MacMainView.swift:117`.

## Target Layout: Two-Column (Like Apple Reminders)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Sidebar (280pt)       │  Content (remaining ~750pt)               │
│                        │                                            │
│  LISTAT                │  Ruokaostokset  ✏️        🔗  🔽  👁  ✎  │
│  ━━━━━━━━━━━━━━━━━━━  │  4/6 items                                │
│  ▸ Ruokaostokset  4/6 │                                            │
│    Viikonlopun p. 2/3 │  ┌─────────────────────────────────────┐   │
│    Luettavat k.   2/3 │  │ □ Maito                             │   │
│    Matkapakkaus   3/4 │  │   Kevyt- tai täysmaito         2x   │   │
│                        │  ├─────────────────────────────────────┤   │
│  ───────────────────  │  │ □ Leipä                             │   │
│  ⊘ Arkistoidut        │  │   Täysjyväleipä tai sämpylät       │   │
│  ───────────────────  │  ├─────────────────────────────────────┤   │
│  ⚙ Asetukset          │  │ □ Omenat                            │   │
│                        │  │   Tuoreet kotimaiset           6x   │   │
│                        │  ├─────────────────────────────────────┤   │
│                        │  │ □ Broilerin rintafile               │   │
│                        │  │   Luomu, luuton                2x   │   │
│                        │  └─────────────────────────────────────┘   │
│                        │                                            │
│                        │              Tap item → push to detail     │
│                        │                                  [+ Add]   │
└─────────────────────────────────────────────────────────────────────┘
```

On iPhone: unchanged (stack navigation with tab bar).

**Portrait behavior**: Sidebar is always visible in both portrait and landscape (`columnVisibility: .all`). This ensures the list sidebar is never hidden behind a swipe gesture — critical for a list management app.

## Design Decisions

- **Layout**: Two-column (sidebar + content). Item detail via push navigation.
- **Code strategy**: Adapt MainView using `@Environment(\.horizontalSizeClass)` — no separate iPad views.
- **iPad screenshots**: Landscape orientation (not portrait-locked) to show two-column layout.
- **All phases**: Same branch (`feature/new-ipad-ux`), separate commits per phase. No separate PRs.
- **Phase order**: Pre-work → Phase 1 (NavigationSplitView) → Phase 2 (Pipeline) → Phase 3 (Context Menus) → Phase 4 (Toolbar + Polish).

## Pre-work: Extract Sub-Views (Commit 1 — No Behavioral Change) ✅

Before the navigation rewrite, extract MainView body into sub-views to reduce diff complexity:

1. Extract sidebar/list content into `MainListContent` view struct (lines ~105-130)
2. Extract toolbar actions into reusable helper methods
3. This commit has **zero behavioral change** — pure refactor for readability

## Phase 1: NavigationSplitView Migration (Commit 2) ✅

### Step 1.1: Audit and migrate all NavigationLink usages

**Current NavigationLink inventory** (must all be migrated):

| Location | Pattern | Migration |
|----------|---------|-----------|
| `MainView.swift:140-167` | Hidden `NavigationLink(destination:isActive:)` with `selectedListForNavigation` binding | Replace with NavigationSplitView `detail:` column binding |
| `ListRowView.swift:120` | `NavigationLink(destination: ArchivedListView(...))` | Use `.navigationDestination(for:)` in detail column |
| `ListRowView.swift:126` | `mainViewModel.selectedListForNavigation = list` (Button tap) | On iPad: set sidebar selection binding. On iPhone: keep as push. |
| `CreateListView.swift:80` | `mainViewModel.selectedListForNavigation = newList` | On iPad: set sidebar selection. On iPhone: keep current. |
| `ListView.swift:391,421` | `mainViewModel.selectedListForNavigation = refreshedDestination` (after duplicate/delete) | On iPad: update sidebar selection. On iPhone: keep current. |
| `MainViewModel.swift:34` | `@Published var selectedListForNavigation: List?` | Keep property, but on iPad it drives the NavigationSplitView selection binding |

### Step 1.2: Add size class + selection state to MainView

**File**: `MainView.swift`

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@State private var columnVisibility: NavigationSplitViewVisibility = .all
```

The existing `selectedListForNavigation` in `MainViewModel` will serve as the selection binding for NavigationSplitView on iPad (it already tracks which list is selected).

### Step 1.3: Replace NavigationView with conditional NavigationSplitView

**File**: `MainView.swift:68`

```swift
if horizontalSizeClass == .regular {
    NavigationSplitView(columnVisibility: $columnVisibility) {
        // Sidebar: list of lists, archived toggle, settings
        sidebarContent
    } detail: {
        // Detail: ListView for selected list, or placeholder
        if let list = viewModel.selectedListForNavigation {
            ListView(list: list, mainViewModel: viewModel)
        } else {
            ContentUnavailableView("Select a List", systemImage: "list.bullet")
        }
    }
} else {
    NavigationStack {
        // iPhone: keep current stack-based layout
        currentMainViewBody
    }
}
```

**Critical**: Check for NavigationPath animation bug (see `MacMainView.swift:72-77`). If NavigationSplitView breaks animations on iPadOS, apply the same `NavigationStack(path:)` workaround inside the detail column.

### Step 1.4: Build sidebar content

Extract into `sidebarContent` computed property:
- Active lists section with `List` + `.onMove` (reorder) + `.onDelete` (archive)
- "Archived Lists" toggle/section (currently `showingArchivedLists` state in MainViewModel)
- "Settings" navigation link
- Toolbar: + button, sync button, share button

**ArchivedListView strategy**: On iPad sidebar, archived lists appear as a separate section (toggled by tapping "Archived" in sidebar). Tapping an archived list shows `ArchivedListView` in the detail column via `.navigationDestination(for:)`. Remove the old `NavigationLink(destination: ArchivedListView(...))` from `ListRowView.swift:120`.

### Step 1.5: Update ListRowView for split view

**File**: `ListRowView.swift:110-136`

Current logic branches on `isInSelectionMode` and `showingArchivedLists`:
- Selection mode: Button for toggle — **keep as-is**
- Archived list: `NavigationLink(destination: ArchivedListView(...))` — **replace**: set selection binding, let detail column handle presentation
- Normal mode: Button setting `selectedListForNavigation` — **keep**, already drives the sidebar selection

### Step 1.6: Remove tab bar on iPad

**File**: `MainView.swift:630` — `CustomBottomToolbar`

Hide when `horizontalSizeClass == .regular`. Sidebar replaces tab bar navigation on iPad.

### Step 1.7: Remove NavigationStyleModifier

**File**: `MainView.swift:674-700`

Delete entirely. The conditional NavigationSplitView/NavigationStack branching replaces it.

### Step 1.8: Update portrait lock for iPad screenshots

**File**: `ListAllApp.swift:179-183`

Change UITEST_MODE orientation lock to allow **landscape on iPad**:
```swift
if UITestDataService.isUITesting || env["UITEST_FORCE_PORTRAIT"] == "1" {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return .allButUpsideDown  // Allow landscape for split view screenshots
    }
    return .portrait  // iPhone stays portrait
}
```

### Step 1.9: State restoration

Keep `@SceneStorage("selectedListId")` for restoring list selection. The existing restoration logic at `MainView.swift:418-433` can drive the `selectedListForNavigation` property on both iPhone and iPad.

### Step 1.10: Mark phase complete

Update this document: add ✅ to the Phase 1 heading.

## Phase 2: Screenshot Pipeline Updates (Commit 3) ✅

Pipeline updates before context menus/polish so visual verification is available for later phases.

### Step 2.1: Update UITEST_MODE navigation behavior

Covered by Steps 1.3 (NavigationSplitView on iPad) and 1.8 (landscape for iPad screenshots). UITEST_MODE no longer forces stack navigation on iPad.

### Step 2.2: Update iPad screenshot tests

**File**: `ListAllUITests/ListAllUITests_Simple.swift`

Key changes:
- `launchAndNavigateToGroceryList()`: Detect device with `UIDevice.current.userInterfaceIdiom`. On iPad: sidebar cells may be in different hierarchy; after tap, verify detail column shows items (sidebar stays visible). On iPhone: keep current stack navigation.
- Remove `UITEST_FORCE_PORTRAIT` from iPad test launch args (allow landscape).
- `testScreenshots02_MainFlow()`: On iPad, screenshot shows sidebar + selected list.
- `testScreenshots03_GroceryItems()`: Same — sidebar visible with grocery items in content area.
- **Same test class handles both devices** — Snapfile runs iPhone then iPad sequentially. Tests must branch on device type.

### Step 2.3: Verify pipeline

Run `./generate-screenshots-local.sh ipad en-US` and verify output shows sidebar + content layout in landscape.

### Step 2.4: Mark phase complete

Update this document: add ✅ to the Phase 2 heading.

## Phase 3: Context Menus (Commit 4)

### Step 3.1: Add context menus to ListRowView

**File**: `ListRowView.swift`

Add `.contextMenu` with extracted shared action methods (reuse from swipe action closures at lines 141-173):
- Edit (rename)
- Share
- Duplicate
- Archive / Delete

### Step 3.2: Add context menus to ItemRowView

**File**: `ItemRowView.swift`

Add `.contextMenu`:
- Toggle crossed out
- Edit
- Duplicate
- Delete

### Step 3.3: Use popovers instead of sheets on iPad

**File**: `MainView.swift`

Convert to `.popover()` on regular width:
- `CreateListView` — anchor to + button
- `ShareFormatPickerView` — anchor to share button

Keep as `.sheet()`:
- `SyncConflictResolutionView` (complex, full-width content needed)
- `ItemEditView` (rich form with images)

### Step 3.4: Mark phase complete

Update this document: add ✅ to the Phase 3 heading.

## Phase 4: Toolbar + Polish (Commit 5)

### Step 4.1: Move "Add Item" to toolbar on iPad

**File**: `ListView.swift:194`

On iPad: add to `.toolbar`. Remove floating button overlay.
On iPhone: keep floating button.

### Step 4.2: Settings in sidebar

On iPad, settings is a sidebar destination (navigation link in sidebar), not a modal sheet from tab bar.

### Step 4.3: Mark phase complete

Update this document: add ✅ to the Phase 4 heading.

## Key Files to Modify

| File | Changes |
|------|---------|
| `ListAll/ListAll/Views/MainView.swift` | NavigationSplitView, sidebar, remove tab bar, remove NavigationStyleModifier |
| `ListAll/ListAll/Views/Components/ListRowView.swift` | Migrate NavigationLink for ArchivedListView, context menu (Phase 2) |
| `ListAll/ListAll/Views/ListView.swift` | Toolbar add button on iPad (Phase 3) |
| `ListAll/ListAll/Views/Components/ItemRowView.swift` | Context menu (Phase 2) |
| `ListAll/ListAll/Views/CreateListView.swift` | selectedListForNavigation works on both paths (verify) |
| `ListAll/ListAll/ViewModels/MainViewModel.swift` | selectedListForNavigation kept but may need type changes |
| `ListAll/ListAll/ListAllApp.swift` | Portrait lock — allow landscape on iPad in UITEST_MODE |
| `ListAll/ListAllUITests/ListAllUITests_Simple.swift` | iPad screenshot navigation for split view |

## Existing Code to Reuse

- `MacMainView.swift:117` — NavigationSplitView pattern with columnVisibility
- `MacMainView.swift:72-77` — NavigationPath animation bug workaround (check if needed on iPadOS)
- `ListRowView.swift:141-173` — Swipe action closures (extract for context menus)
- `MainView.swift:13` — `@SceneStorage("selectedListId")` already exists
- `MainView.swift:297` — Keyboard shortcuts (Cmd+N etc.) — keep as-is
- `MainViewModel.swift:34` — `selectedListForNavigation` serves as selection binding

## Known Risks

1. **NavigationSplitView animation bug** (`MacMainView.swift:72-77`): Apple-confirmed bug where NavigationSplitView breaks all animations including sheet presentation. Monitor for this; apply NavigationPath workaround if needed.
2. **iPad multitasking**: In 1/3 width Split View, `horizontalSizeClass` becomes `.compact` → falls back to stack navigation. This is correct automatic behavior.
3. **Stale comment**: `MainView.swift:138` says "deployment target is iOS 15" — this is wrong, actual target is iOS 16.0. Clean up during migration.

## Verification Plan

1. **Pre-work commit**: Build and verify zero behavioral change on iPhone
2. **Phase 1 on iPad (landscape)**: Boot iPad Pro 13" simulator, launch with UITEST_MODE, verify:
   - Sidebar + content two-column layout in landscape
   - Selecting a list shows items in content area (sidebar stays)
   - Creating a new list selects it in sidebar
   - Archived lists section works in sidebar → shows ArchivedListView in detail
   - Settings accessible from sidebar
3. **Phase 1 on iPad (portrait)**: Verify sidebar overlay behavior works
4. **Phase 1 on iPhone**: Boot iPhone 16, verify stack navigation + tab bar unchanged
5. **Phase 1 multitasking**: Test iPad Split View at 50/50 and 33/66
6. **Run existing unit tests**: Ensure no regressions
7. **Screenshot pipeline**: Run `./generate-screenshots-local.sh ipad en-US` — verify landscape two-column output
8. **iPhone screenshot pipeline**: Run `./generate-screenshots-local.sh iphone en-US` — verify no regression
9. Cleanup: quit app, shutdown simulators
