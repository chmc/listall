# Professional UI Polish — "Refined Depth + Brand Colors"

## Context

ListAll is a functional, well-structured SwiftUI app (iOS 16+, macOS 14+, watchOS 9+) that currently looks "standard" — like a default SwiftUI app. The goal is to make it feel like a premium paid app through visual polish: brand colors from the app icon, card-based item rows, polished completion states, content transitions, materials on floating elements, and dark mode refinements.

**Design mockups**: `.superpowers/brainstorm/48279-1773230819/` (recommended-direction.html, full-polish-overview.html, fixed-sidebar-and-watchos.html)

## Brand Color System

| Token | Light | Dark | Hex | Usage |
|-------|-------|------|-----|-------|
| AccentColor (primary) | `(0, 0.706, 0.863)` | `(0.491, 0.847, 0.941)` | `#00B4DC` / `#7DD8F0` | Interactive elements, badges, checkboxes |
| completedGreen | — | — | `#10B981` | Completion checkmarks, "all done" states |
| Swipe `.tint(.blue/.red/.green/.orange)` | keep as-is | keep as-is | — | Semantic swipe actions (don't change) |

## Critical Constraints (from critic review + research)

1. **iOS 16+ deployment target**: `.contentTransition(.numericText())` and `.symbolEffect(.replace)` require iOS 17+. Must wrap in `if #available(iOS 17, *)` with fallback.
2. **Theme.swift is NOT shared with watchOS**: watchOS views use raw SwiftUI values (0 `Theme.` references). Use inline colors/fonts for watchOS, not Theme references.
3. **50+ hardcoded `.blue` references**: Most are semantic (settings, restore buttons, tooltips). Only change those that represent the *brand accent*; keep semantic uses as-is.
4. **Card backgrounds in List rows** (RESEARCHED): Swipe actions and `.onDelete`/`.onMove` DO work with card backgrounds. Use `listRowBackground(RoundedRectangle(...))` (NOT inner `.background()`). Card slides during swipe — this is expected iOS behavior and acceptable. Inner `.background()` causes white flash during drag.
5. **OLED dark mode**: Use `Color.white.opacity(0.05)` minimum for card backgrounds (not `0.03`).
6. **macOS sidebar overlay** (RESEARCHED): `.overlay(alignment: .leading)` for left border WORKS alongside system selection highlight. Must add `.allowsHitTesting(false)`. Do NOT use `.listRowBackground()` on sidebar — it destructively overrides system selection. `.onHover` has known bug (FB11988707) — needs near-invisible non-clear background workaround.
7. **watchOS ProgressView** (RESEARCHED): Linear style available on watchOS 7+. `.monospacedDigit()` available on watchOS 8+. Use custom `ProgressViewStyle` for compact 3px height, or `Gauge(.accessoryLinearCapacity)` for native thin bar (watchOS 9+).

---

## Phase 1: Brand Color Foundation + Hardcoded Color Audit

**Goal**: Update accent color from blue to brand teal. Audit all hardcoded `.blue`/`.green` to classify what changes.

### AccentColor assets — update all 3:

1. **`ListAll/ListAll/Assets.xcassets/AccentColor.colorset/Contents.json`**
   - Light: `red: 0.000, green: 0.706, blue: 0.863` (was `0, 0, 1`)
   - Dark: `red: 0.491, green: 0.847, blue: 0.941` (was `0.2, 0.4, 1`)

2. **`ListAll/ListAllMac/Assets.xcassets/AccentColor.colorset/Contents.json`**
   - Same values as iOS

3. **`ListAll/ListAllWatch Watch App/Assets.xcassets/AccentColor.colorset/Contents.json`**
   - Currently empty. Add full light/dark teal structure.

### Hardcoded color audit — CHANGE to `.accentColor` or Theme equivalent:
| File | Line | Current | Change to | Reason |
|------|------|---------|-----------|--------|
| `ListRowView.swift` | 68, 71 | `.foregroundColor(.blue)`, `Color.blue.opacity(0.1)` | `.accentColor`, `.accentColor.opacity(0.1)` | Restore button — brand accent |
| `ListRowView.swift` | 104 | `.foregroundColor(.blue)` (selection checkbox) | `Theme.Colors.primary` | Brand accent |
| `ItemRowView.swift` | 50 | `linkColor: .blue` | `Theme.Colors.primary` | Brand accent for links |
| `ItemRowView.swift` | 101 | `.foregroundColor(isSelected ? .blue : .gray)` | `Theme.Colors.primary` | Selection |
| `MainView.swift` | 895, 898 | `.foregroundColor(.blue)` | `.accentColor` | Selection mode |
| `ContentView.swift` | 131, 161 | `.foregroundColor(.blue)`, `Color.blue` | `.accentColor` | Navigation |
| `TooltipView.swift` | 80, 87 | `.fill(Color.blue)` | `.fill(Color.accentColor)` | Tooltip background = brand |
| `TooltipOverlay.swift` | 60, 72 | `Color.blue` / `.foregroundColor(.blue)` | `.accentColor` | Tooltip = brand |
| `ArchivedListView.swift` | 91 | `.foregroundColor(.blue)` | `.accentColor` | Restore action = brand |

### KEEP as-is (semantic blue/green — not brand):
- All `.tint(.blue/.green/.red/.orange)` on swipe actions
- `Theme.Colors.info = Color.blue` — semantic info color, keep blue
- `SettingsView.swift` — all `.blue`/`.green` are semantic (sync status, strategy selection, checkmarks)
- `ItemOrganizationView.swift` — `.blue`/`.green` are filter/sort state indicators
- Test files — don't touch

### Theme.swift update:
- `Theme.Colors.success`: Change `Color.green` → `Color(red: 0.063, green: 0.725, blue: 0.506)` (#10B981)
- **Note**: test at `ListAllMacTests.swift:9533` asserts `successColor == SwiftUIColor.green` — must update this test too

### Verification:
- Build all 3 schemes
- Screenshot macOS, iPhone, Watch — confirm teal accent in nav bars, buttons, tint colors
- Run tests: `xcodebuild test` for iOS and macOS schemes

---

## Phase 2: Theme.swift Extensions

**Goal**: Add new Theme constants for components to use.

### File: `ListAll/ListAll/Utils/Theme.swift`

**Add to Colors**:
```swift
static let completedGreen = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
static let brandGradient = LinearGradient(
    colors: [Color("AccentColor"), Color("AccentColor").opacity(0.8)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
```

**Add to Typography**:
```swift
static let monoDigit = Font.body.monospacedDigit()
static let monoDigitCaption = Font.caption.monospacedDigit()
static let monoDigitCaption2 = Font.caption2.monospacedDigit()
```

**Add CardRowModifier** (dark mode: borders + OLED-safe bg, light mode: shadows):
```swift
struct CardRowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
                radius: 2, x: 0, y: 1
            )
    }
}
extension View {
    func cardRowStyle() -> some View { modifier(CardRowModifier()) }
}
```

**Update existing `cardStyle()`** to use same dark-mode-aware pattern.

**Reuse**: `ScaleButtonStyle` at `EmptyStateView.swift:198` — already exists, keep it.

### Verification: Compile-only (no visual changes yet)

---

## Phase 3: iOS List Row Count Format

**Goal**: Change `4 (6) items` to compact `4/6 items` with `.monospacedDigit()` and brand teal.

**Note**: ListView.swift header (line 68) already uses `"4/6 items"` format. Only `ListRowView.swift` still uses old format.

### File: `ListAll/ListAll/Views/Components/ListRowView.swift`

**`listContent` (line 41-44)** — Replace:
```swift
Text("\(list.activeItemCount) (\(list.itemCount)) items")
```
With:
```swift
HStack(spacing: 2) {
    Text("\(list.activeItemCount)/\(list.itemCount)")
        .font(Theme.Typography.monoDigitCaption)
        .foregroundColor(Theme.Colors.primary)
    Text("items")
        .font(Theme.Typography.caption)
        .foregroundColor(Theme.Colors.secondary)
}
```

**No `.contentTransition` here** — iOS 16 doesn't support it. Add conditionally in Phase 9.

### Verification: Screenshot iPhone lists view

---

## Phase 4: iOS Item Row Polish

**Goal**: Card-based rows, visible checkbox, teal/green colors, quantity capsule.

### File: `ListAll/ListAll/Views/Components/ItemRowView.swift`

1. **Add visible checkbox** in non-selection mode body (before `itemContent`, ~line 118):
   ```swift
   Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
       .font(.title3)
       .foregroundColor(item.isCrossedOut ? Theme.Colors.completedGreen : Theme.Colors.primary)
   ```
   (**No `.symbolEffect`** — requires iOS 17. Simple icon swap is fine.)

2. **Quantity badge** (inside `itemContent`, ~line 65-70) — Replace plain text:
   ```swift
   Text("×\(item.quantity)")
       .font(Theme.Typography.monoDigitCaption)
       .foregroundColor(Theme.Colors.primary)
       .padding(.horizontal, 7)
       .padding(.vertical, 2)
       .background(Theme.Colors.primary.opacity(0.12))
       .clipShape(Capsule())
   ```

3. **Completed opacity** (~line 41): Change `0.7` to `0.5`

4. **Card styling** — On the outer HStack (~line 94), add padding + card:
   ```swift
   .padding(.vertical, 11)
   .padding(.horizontal, 14)
   .cardRowStyle()
   ```

5. **Selection checkbox** (line 101): `.foregroundColor(isSelected ? Theme.Colors.primary : .gray)`

6. **Link color** (line 50): `linkColor: Theme.Colors.primary`

### File: `ListAll/ListAll/Views/ListView.swift`

**Use `listRowBackground` for card appearance** (NOT inner `.background()` — inner causes white flash during drag):
```swift
// On each ItemRowView in the ForEach (after line 111):
.listRowBackground(
    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.vertical, 2)
)
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
```
**Note**: Card will slide with row during swipe — this is standard iOS behavior and visually acceptable. `.onDelete`, `.swipeActions`, and `.onMove` all work correctly with `listRowBackground`.

**Remove `.cardRowStyle()` from ItemRowView.swift** — the card appearance is applied via `listRowBackground` in ListView, not as inner background.

### Verification: Screenshot iPhone light + dark mode, test swipe actions interactively

---

## Phase 5: macOS Sidebar Polish

**Goal**: Brand teal left border on selected row, `4/6` format, hover states.

### File: `ListAll/ListAllMac/Views/MacMainView.swift`

Use **function names** as anchors (not line numbers — file is 4245 lines):

1. **`itemCountText(for:)` function**: Change `"\(activeCount) (\(totalCount))"` to `"\(activeCount)/\(totalCount)"`

2. **Count display** at call sites in `normalModeRow(for:)` and `selectionModeRow(for:)`: Add `.monospacedDigit()` and `.foregroundColor(.accentColor.opacity(0.6))`

3. **Selected row indicator** in `normalModeRow(for:)` — overlay coexists with system selection highlight:
   ```swift
   .overlay(alignment: .leading) {
       if selectedList?.id == list.id {
           RoundedRectangle(cornerRadius: 1.5)
               .fill(Color.accentColor)
               .frame(width: 3)
               .padding(.vertical, 2)
               .allowsHitTesting(false) // Don't block NavigationLink clicks
       }
   }
   ```
   **Do NOT use `.listRowBackground()`** on sidebar rows — it destructively overrides the system selection highlight (confirmed via FB14195920).

4. **Section headers**: Add `.textCase(.uppercase)`, `.font(.caption.weight(.semibold))`, `.tracking(0.5)` where applicable

5. **Hover states** — Known `.onHover` bug (FB11988707) in sidebar. Use near-invisible background:
   ```swift
   struct HoverHighlightModifier: ViewModifier {
       @State private var isHovering = false
       func body(content: Content) -> some View {
           content
               // Near-invisible bg fixes onHover bug in translucent sidebars
               .background(Color(nsColor: NSColor(deviceWhite: 1, alpha: 0.001)))
               .background(isHovering ? Color.primary.opacity(0.04) : Color.clear)
               .cornerRadius(Theme.CornerRadius.sm)
               .onHover { isHovering = $0 }
       }
   }
   ```

### Verification: Screenshot macOS light + dark, verify left border, hover

---

## Phase 6: macOS Item Row Polish

**Goal**: Teal checkboxes, quantity capsules, completed opacity.

### File: `ListAll/ListAllMac/Views/MacMainView.swift`

Find **`MacItemRowView`** struct (search by name, not line number):

1. **Checkbox colors**: `.foregroundColor(item.isCrossedOut ? Theme.Colors.completedGreen : Theme.Colors.primary)`
2. **Quantity badge**: `.monospacedDigit()`, `.background(Theme.Colors.primary.opacity(0.12))`, `.clipShape(Capsule())`
3. **Completed opacity**: `.opacity(item.isCrossedOut ? 0.5 : 1.0)` on item content

### Verification: Screenshot macOS with quantities and completions

---

## Phase 7: watchOS Polish

**Goal**: Brand teal throughout, progress bars, separated quantity.

**Important**: watchOS does NOT use Theme.swift. Use inline color values.

### Inline color constants for watchOS:
```swift
// Use .accentColor (reads from AccentColor asset — updated in Phase 1)
// For completed green, use inline: Color(red: 0.063, green: 0.725, blue: 0.506)
```

### Files:

1. **`WatchListRowView.swift`**:
   - Change `itemCountText` from `"\(activeCount) (\(totalCount)) items"` to `"\(activeCount)/\(totalCount)"`
   - Display count with `.monospacedDigit()` and `.foregroundColor(.accentColor)`
   - Add mini progress bar using custom compact style (3px height):
     ```swift
     // Custom style for compact watchOS progress bar
     struct CompactProgressStyle: ProgressViewStyle {
         func makeBody(configuration: Configuration) -> some View {
             GeometryReader { geo in
                 ZStack(alignment: .leading) {
                     Capsule().fill(Color.secondary.opacity(0.3)).frame(height: 3)
                     Capsule().fill(Color.accentColor)
                         .frame(width: geo.size.width * (configuration.fractionCompleted ?? 0), height: 3)
                 }
             }.frame(height: 3)
         }
     }
     // Usage:
     ProgressView(value: Double(completedCount), total: Double(max(totalCount, 1)))
         .progressViewStyle(CompactProgressStyle())
     ```
   - Note: `ProgressView` linear style available watchOS 7+, `.monospacedDigit()` available watchOS 8+

2. **`WatchItemRowView.swift`**:
   - Checkbox (line 16-17): `.foregroundColor(item.isCrossedOut ? Color(red: 0.063, green: 0.725, blue: 0.506) : .accentColor)`
   - Quantity (line 30-33): Separate from title with `Spacer()`, right-align, `.monospacedDigit()`, `.foregroundColor(.accentColor)`
   - Completed opacity: `0.6` → `0.5`

3. **`WatchListView.swift`**:
   - Active count: `.foregroundColor(.accentColor)` (was `.blue`)
   - Completed count: `.foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506))` (was `.green`)
   - Sync indicator: `Color.accentColor` (was `Color.blue`)

4. **`WatchListsView.swift`**:
   - Sync indicator: `Color.accentColor` (was `Color.blue`)

5. **`WatchLoadingView.swift`**:
   - Loading dots: `Color.accentColor` (was `Color.blue`)

6. **`WatchPullToRefreshView.swift`**:
   - Refresh indicator: `.accentColor` (was `.blue`)

### Verification: Screenshot watchOS lists + items view

---

## Phase 8: Empty States Polish

**Goal**: Gradient CTA buttons, polished celebration state.

### File: `ListAll/ListAll/Views/Components/EmptyStateView.swift`

1. **CTA button background** (line 78): Replace `Theme.Colors.primary` with `Theme.Colors.brandGradient`
2. **Celebration circle** (line 228-235): gradient fill + shadow:
   ```swift
   Circle()
       .fill(LinearGradient(
           colors: [Theme.Colors.completedGreen.opacity(0.2), Theme.Colors.completedGreen.opacity(0.1)],
           startPoint: .topLeading, endPoint: .bottomTrailing
       ))
       .shadow(color: Theme.Colors.completedGreen.opacity(0.2), radius: 12)
   ```
3. **Checkmark color** (line 234): `Theme.Colors.completedGreen`
4. **Welcome icon opacity** (line 16): Change `.opacity(0.7)` to `.opacity(0.15)` for subtler appearance
5. **"All Done" checkmark**: Use `Theme.Colors.completedGreen` instead of `Theme.Colors.success`

### macOS empty states: Apply same gradient CTA and green celebration changes

### Verification: Screenshot empty list + "all done" states on iOS + macOS

---

## Phase 9: Conditional Transitions & Materials (iOS 17+ enhancements)

**Goal**: Add content transitions and symbol effects behind availability checks.

### Pattern for all content transitions:
```swift
if #available(iOS 17, macOS 14, watchOS 10, *) {
    text.contentTransition(.numericText())
} else {
    text
}
```

### Locations to add `.contentTransition(.numericText())`:
- ListRowView.swift — count text
- ListView.swift — header count (line 68)
- ItemRowView.swift — quantity badge
- macOS count displays

### Locations to add `.symbolEffect`:
- ItemRowView.swift checkbox — `.symbolEffect(.replace)` on iOS 17+

### Materials:
- Audit toolbar SF Symbols: ensure `.symbolRenderingMode(.monochrome)` for future Liquid Glass compat
- Keep existing material choices (`.ultraThinMaterial` on banners works well)

### Verification: Screenshot on iOS 18 simulator to confirm transitions work

---

## Phase 10: Final Verification

Run the **professional-ui-polish** checklist on all platforms:

1. Materials on overlays/floating only (not list rows)?
2. Spacing on 4pt grid, outer > inner?
3. Dark mode: borders not shadows, elevated surfaces at `0.05` opacity min?
4. Content transitions on numeric values (iOS 17+ only)?
5. Press feedback on tappable custom views?
6. No jarring hardcoded blue/green remaining in brand-accent positions?
7. Swipe actions still work on iOS item rows?

### Platform coverage:
- [ ] macOS light mode — `listall_screenshot_macos`
- [ ] macOS dark mode — `listall_screenshot_macos`
- [ ] iPhone light mode — `listall_screenshot` (iPhone 16 Pro, 126F8D56)
- [ ] iPhone dark mode — `listall_screenshot`
- [ ] watchOS — `listall_screenshot` (Apple Watch Series 10, EAE9023D)

### Tests to run:
- `xcodebuild test -scheme ListAll` (iOS)
- `xcodebuild test -scheme ListAllMac` (macOS)
- `xcodebuild test -scheme "ListAllWatch Watch App"` (watchOS)
- Update test assertions: `ListAllMacTests.swift:9533` (success color) and `:9554` (info color stays blue)

### Cleanup:
```
listall_quit_macos(app_name: "ListAll")
listall_shutdown_simulator(udid: "all")
```

---

## Risk Mitigation

| Risk | Status | Mitigation |
|------|--------|-----------|
| MacMainView.swift is 4245 lines | Mitigated | Use function name search, not line numbers |
| AccentColor ripple effects | Mitigated | Explicit audit table classifies every `.blue`/`.green` |
| Card rows break swipe actions | **RESOLVED** | Research confirms: use `listRowBackground(RoundedRectangle)`, NOT inner `.background()`. Swipe/delete/move all work. Card slides during swipe = expected. |
| macOS sidebar left border | **RESOLVED** | `.overlay(alignment: .leading)` coexists with system selection. Add `.allowsHitTesting(false)`. Do NOT use `listRowBackground` on sidebar. |
| macOS `.onHover` in sidebar | **RESOLVED** | Known bug FB11988707. Fix: near-invisible non-clear background `NSColor(deviceWhite: 1, alpha: 0.001)` |
| watchOS ProgressView compact | **RESOLVED** | Custom `ProgressViewStyle` for 3px bar. Linear style available watchOS 7+, `.monospacedDigit()` watchOS 8+. |
| watchOS has no Theme.swift | Mitigated | Use inline colors + `.accentColor` (reads from asset) |
| `.contentTransition` needs iOS 17+ | Mitigated | Wrap in `if #available` — degrades gracefully |
| OLED dark mode card visibility | Mitigated | Use `0.05` opacity minimum (not `0.03`) |
| Test assertions on color values | Mitigated | Update `ListAllMacTests` success/info color assertions |
| 50+ hardcoded `.blue`/`.green` | Mitigated | Only change brand-accent uses; keep semantic colors |

## Dependency Graph

```
Phase 1 (AccentColor + audit) → Phase 2 (Theme.swift)
    ↓
    ├── Phase 3 (iOS list counts) → Phase 4 (iOS item rows) ──┐
    ├── Phase 5 (macOS sidebar) → Phase 6 (macOS item rows) ──┤
    ├── Phase 7 (watchOS) ─────────────────────────────────────┤
    └── Phase 8 (Empty states) ────────────────────────────────┤
                                                                ↓
                                                    Phase 9 (Transitions)
                                                                ↓
                                                    Phase 10 (Verification)
```

Phases 3-8 can run in parallel after Phase 2.
