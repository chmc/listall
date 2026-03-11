---
name: professional-ui-polish
description: Visual refinement patterns that make SwiftUI apps feel premium. Covers materials, spacing rhythm, dark mode polish, and content transition APIs. Use when UI is correct but needs to feel professional-grade.
---

# Professional UI Polish

Visual refinement patterns for SwiftUI. Complements `apple-hig` (structure, navigation, accessibility) and `apple-ux-patterns` (state communication, gestures, animation timing) with the **finish layer** — materials, spacing rhythm, dark mode techniques, and content transitions.

## Apple App Visual References

Inline "(see: AppName)" tags reference observable behavior in Apple's own apps. These describe visual results, not confirmed implementation details.

| App | Visually Exemplifies |
|-----|---------------------|
| **Weather** | Translucent layered cards over gradient backgrounds, material depth |
| **Reminders** | Spacing rhythm — section headers vs item rows vs group gaps |
| **Notes** | Bold title + regular body weight pairing, dark mode surface elevation, toolbar material |
| **Maps** | Floating translucent sheets, subtle dual-shadow cards |
| **Health** | Rounded design font for metrics, fixed-width digits on changing values |

---

## 1. Materials & Visual Depth
*(see: Weather, Maps)*

**When to use each material:**
- `.ultraThinMaterial` — floating overlays, popovers over rich backgrounds
- `.regularMaterial` — toolbars, navigation bars, tab bars
- `.thickMaterial` — sheets, sidebars that need readability over busy content

**Dual shadows** for floating elements (tight contact + diffuse ambient):
```swift
.shadow(color: .black.opacity(0.08), radius: 2, y: 1)   // contact
.shadow(color: .black.opacity(0.06), radius: 12, y: 4)   // ambient
```

**Platform-conditional:** Materials work best on macOS; prefer subtle shadows on iOS where backgrounds are simpler.

**Antipatterns:**
- Materials on list rows or every surface (over-polished, reduces readability)
- Single harsh shadow (`radius: 10, opacity: 0.3`)
- Materials on surfaces that already have semantic background colors

---

## 2. Spacing Rhythm
*(see: Reminders, Notes)*

**4pt grid rule:** All spacing values = multiples of 4 (4, 8, 12, 16, 20, 24, 32).

**Hierarchy rule:** outer padding > inner gaps > item spacing.
```
Section padding:  16-20pt (outer)
Group gaps:       24-32pt (between sections)
Item gaps:        8-12pt  (between items in a group)
Inner padding:    8-12pt  (inside a card/cell)
```

**Section breaks** (24-32pt) should be visually distinct from **item gaps** (8-12pt). Use consistent values throughout a screen.

**watchOS:** Scale all spacing by ~50% (8pt outer, 4pt inner, 12-16pt section breaks).

**Antipatterns:**
- Random values with no relationship (13, 17, 22)
- Equal spacing everywhere (all gaps 16pt — loses hierarchy)
- Inner padding > outer padding (items feel cramped in a spacious container)

---

## 3. Dark Mode Polish
*(see: Notes, Weather)*

**Shadows are invisible in dark mode.** Replace with hairline borders:
```swift
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
)
```

**Elevated surfaces:** Use `.regularMaterial` or system grouped colors to create depth — never flat identical surfaces.

**Color rules:**
- Use `.primary` / `.background` instead of `Color.white` / `Color.black`
- Dividers: `.primary.opacity(0.1)` works in both modes
- Avoid `Color(white: 0.95)` — use semantic colors that adapt

**Antipatterns:**
- Shadows rendering in dark mode (invisible but still calculated)
- Hardcoded `Color.white` / `Color.black` (breaks in opposite mode)
- Flat dark surfaces with no separation between layers

---

## 4. Content Transitions & Symbol Effects (iOS 17+)
*(see: Weather, Health)*

**Numeric transitions** — prevent hard-cut number changes:
```swift
Text("\(count)")
    .contentTransition(.numericText())
    .animation(.default, value: count)
```

**Symbol effects** — SF Symbol feedback on state change:
```swift
Image(systemName: "checkmark.circle")
    .symbolEffect(.bounce, value: isComplete)
```

**Press feedback** on custom tappable views:
```swift
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

**macOS hover:** Use `.onHover` with subtle background highlight for interactive elements.

**Antipatterns:**
- No press feedback on custom tappable views
- Hard cuts between numeric states
- Using `.opacity` transitions for everything

---

## 5. Typography Micro-refinements
*(see: Health, Notes)*

**Monospaced digits** on changing numbers (prevents layout jitter):
```swift
Text("\(value)").monospacedDigit()
```

**Line spacing** — consider `.lineSpacing(2-4)` on long-form multi-line body text. System defaults are correct for short text; only add for readability in paragraphs.

**All-caps labels** need tracking:
```swift
Text("SECTION").font(.caption).tracking(0.5)
```

**Weight pairing:** Bold titles + regular body. Avoid uniform weight throughout a screen.

**Rounded design** for badges/counters:
```swift
Text("\(count)").font(.system(.body, design: .rounded))
```

**Antipatterns:**
- Proportional digits in changing numbers (layout jitters on each update)
- All-caps text without tracking adjustment
- Same font weight for everything (flat visual hierarchy)

---

## 6. Polish Smell Test

Quick checklist of polish-specific tells (items NOT covered by `apple-hig` or `apple-ux-patterns`):

1. Random spacing values with no mathematical relationship
2. Heavy card shadows instead of subtle layering
3. No content transitions — hard-cut state changes
4. Center-aligned text that should be leading-aligned
5. Flat toolbar with no material separation from content
6. Shadows still rendering in dark mode
7. Materials/blur on every surface (over-polished)

---

## Debug Checklist

When reviewing for polish:

1. Materials on overlays/floating elements only (not list rows)?
2. Spacing on 4pt grid, outer > inner?
3. Dark mode: borders instead of shadows, elevated surfaces?
4. Content transitions on changing numeric values?
5. Press feedback on all tappable custom views?
6. None of the 7 smell test items present?
