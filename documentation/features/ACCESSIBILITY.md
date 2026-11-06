# Accessibility Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 2/9 | iPad 2/9 | macOS 6/8 | watchOS 4/7

*Count = ✅ / applicable rows (N/A excluded). Statuses re-checked 2026-11-06 against explicit SwiftUI accessibility API use in each target.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| VoiceOver Labels | ✅ | ✅ | ✅ | ✅ | `.accessibilityLabel` (iOS 13 uses, macOS 86); watch `WatchListsView.swift:69`, `WatchItemRowView.swift:54` |
| VoiceOver Hints | ⚠️ | ⚠️ | ✅ | ✅ | iOS target has a single `.accessibilityHint`; watch `WatchListsView.swift:70`, `WatchItemRowView.swift:55`, `WatchFilterPicker.swift:57` |
| VoiceOver Values | ❌ | ❌ | ✅ | ❌ | `.accessibilityValue` used only in macOS (e.g. `MacMainView.swift:3150`) |
| VoiceOver Traits | ❌ | ❌ | ✅ | ✅ | No explicit `.accessibilityAddTraits` in iOS (only SwiftUI's implicit traits); macOS `MacSettingsView.swift:98`; watch `WatchItemRowView.swift:56` |
| Keyboard Navigation | ⚠️ | ⚠️ | ✅ | N/A | macOS-focused; iPad has 4 hardware-keyboard shortcuts (see UI_NAVIGATION.md) |
| Dynamic Type | ⚠️ | ⚠️ | N/A | ✅ | iOS mostly uses text styles but has 34 fixed `.font(.system(size:))` uses (not audited); watch text uses `.body` / `.caption` styles |
| Reduce Motion | ❌ | ❌ | ❌ | ❌ | No `accessibilityReduceMotion` / reduce-motion checks in any target |
| High Contrast | ⚠️ | ⚠️ | ⚠️ | ⚠️ | Only what system semantic colors give automatically; no `colorSchemeContrast` handling |
| Dark Mode | ✅ | ✅ | ✅ | N/A | Semantic colors (`Theme.swift:15-16`); watchOS is always dark |

---

## Notes

- macOS has the most explicit accessibility work (values, traits, header traits in Settings).
- iOS relies largely on SwiftUI defaults; explicit hints, values and traits are mostly absent.
- No target adapts animations to Reduce Motion.
- Dark mode uses system semantic colors.

---

## Implementation

Accessibility modifiers applied in views:
- `.accessibilityLabel()`
- `.accessibilityHint()`
- `.accessibilityValue()` (macOS only)
- `.accessibilityAddTraits()` (macOS, watchOS)
