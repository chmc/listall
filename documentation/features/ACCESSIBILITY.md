# Accessibility Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 9/9 | macOS 7/9

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| VoiceOver Labels | ✅ | ✅ | Platform UI |
| VoiceOver Hints | ✅ | ✅ | Platform UI |
| VoiceOver Values | ⚠️ | ✅ | Platform UI |
| VoiceOver Traits | ⚠️ | ✅ | Platform UI |
| Keyboard Navigation | ⚠️ | ✅ | macOS-focused |
| Dynamic Type | ✅ | N/A | iOS only |
| Reduce Motion | ✅ | ⚠️ | Platform UI |
| High Contrast | ✅ | ✅ | Platform UI |
| Dark Mode | ✅ | ✅ | Shared Assets |

---

## Notes

- macOS has better keyboard navigation by default
- iOS has Dynamic Type for text scaling
- Both platforms support VoiceOver
- Dark mode uses shared color assets

---

## Implementation

Accessibility modifiers applied throughout views:
- `.accessibilityLabel()`
- `.accessibilityHint()`
- `.accessibilityValue()`
- `.accessibilityAddTraits()`
