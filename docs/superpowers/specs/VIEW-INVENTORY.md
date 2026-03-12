# ListAll — Complete View Inventory

Every screen the user can see, organized by platform.
Design mockups: `.superpowers/brainstorm/57429-1773298544/design-*.html`

## iPhone (11 views)

| # | View | File | Needs Redesign |
|---|------|------|---------------|
| 1 | Lists overview | `Views/MainView.swift` | Count format already done. Toolbar icons use accentColor. |
| 2 | Items list | `Views/ListView.swift` | YES: Card-based rows, checkboxes, quantity badges |
| 3 | Item detail | `Views/ItemDetailView.swift` | YES: Card styling, status badge, brand colors |
| 4 | Lists empty (welcome) | `Components/ListsEmptyStateView.swift` | Already done (gradient CTA) |
| 5 | Items empty (no items) | `Components/ItemsEmptyStateView.swift` | Already done (gradient CTA) |
| 6 | Items empty (all done) | `Components/ItemsEmptyStateView.swift` | Already done (green celebration) |
| 7 | Archived list | `Views/ArchivedListView.swift` | YES: Brand teal accents, card styling |
| 8 | Settings | `Views/SettingsView.swift` | Minor: Accent color consistency |
| 9 | Create list sheet | `Views/CreateListView.swift` | Minor: Button styling |
| 10 | Edit item sheet | `Views/ItemEditView.swift` | Minor: Accent colors, stepper styling |
| 11 | Sort/filter sheet | `Components/ItemOrganizationView.swift` | YES: Brand teal active states |

## iPad (3 additional layouts)

| # | View | File | Needs Redesign |
|---|------|------|---------------|
| 12 | Sidebar + items | `Views/MainView.swift` (iPad path) | YES: Teal sidebar selection |
| 13 | Sidebar + no list | `Views/MainView.swift` | YES: Empty state styling |
| 14 | Sidebar + archived | `Views/MainView.swift` | YES: Archived row styling |

## macOS (13 views)

| # | View | File | Needs Redesign |
|---|------|------|---------------|
| 15 | Sidebar + no list | `MacMainView.swift` | YES: Count format, selection state |
| 16 | Sidebar + items | `MacMainView.swift` | YES: Selection, cards, checkboxes |
| 17 | Create list sheet | `MacMainView.swift` | Minor: Template styling |
| 18 | Edit item sheet | `MacMainView.swift` | Minor: Accent colors |
| 19 | Settings window | `MacSettingsView.swift` | Minor: Tab styling |
| 20 | Welcome empty | `MacListsEmptyStateView.swift` | Already done (gradient CTA) |
| 21 | No items empty | `MacItemsEmptyStateView.swift` | Already done (gradient CTA) |
| 22 | All done empty | `MacItemsEmptyStateView.swift` | Already done (green celebration) |
| 23 | No list selected | `MacNoListSelectedView.swift` | YES: Brand styling |
| 24 | Search empty | `MacSearchEmptyStateView.swift` | Minor: Accent colors |
| 25 | Feature tips | `MacAllFeatureTipsView.swift` | Minor: Accent colors |
| 26 | Edit list sheet | `MacMainView.swift` | Minor: Button styling |
| 27 | Share format picker | `MacMainView.swift` | Minor: Accent colors |

## watchOS (8 views)

| # | View | File | Needs Redesign |
|---|------|------|---------------|
| 28 | Lists overview | `WatchListsView.swift` | YES: Count format, progress bar |
| 29 | Items list + filter | `WatchListView.swift` | YES: Teal checkboxes, qty badges |
| 30 | Filter picker | `WatchFilterPicker.swift` | YES: Teal active state |
| 31 | Empty (no lists) | `WatchEmptyStateView.swift` | Minor: Brand styling |
| 32 | Empty (no items) | `WatchListView.swift` | Minor: Brand styling |
| 33 | Loading state | `WatchLoadingView.swift` | Minor: Accent color |
| 34 | Sync indicator | `WatchSyncLoadingView.swift` | Minor: Teal instead of blue |
| 35 | Error state | Various | Minor: Accent colors |

**Total: 35 distinct views/states across 4 platforms**
