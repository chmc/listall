# App Store Screenshots Guide

This directory should contain screenshots for all required device sizes.

## Required Screenshot Sizes

### iPhone Screenshots (MANDATORY)

#### iPhone 6.9" Display (iPhone 16 Pro Max)
- Resolution: 1320x2868 pixels
- Filename format: `iPhone_6.9_1.png`, `iPhone_6.9_2.png`, etc.
- Required: 3-10 screenshots

#### iPhone 6.7" Display (iPhone 15 Pro Max, 14 Pro Max)
- Resolution: 1290x2796 pixels
- Filename format: `iPhone_6.7_1.png`, `iPhone_6.7_2.png`, etc.
- Required: 3-10 screenshots

#### iPhone 6.5" Display (iPhone 11 Pro Max, XS Max)
- Resolution: 1242x2688 pixels
- Filename format: `iPhone_6.5_1.png`, `iPhone_6.5_2.png`, etc.
- Required: 3-10 screenshots

#### iPhone 5.5" Display (iPhone 8 Plus)
- Resolution: 1242x2208 pixels
- Filename format: `iPhone_5.5_1.png`, `iPhone_5.5_2.png`, etc.
- Required: 3-10 screenshots

### iPad Screenshots (if supporting iPad)

#### iPad Pro 12.9" (6th Gen)
- Resolution: 2048x2732 pixels
- Filename format: `iPad_12.9_1.png`, `iPad_12.9_2.png`, etc.
- Required: 3-10 screenshots

### Apple Watch Screenshots (MANDATORY - you have watchOS app)

#### Apple Watch Series 11 (46mm)
- Filename format: `Watch_46mm_1.png`, `Watch_46mm_2.png`, etc.
- Required: 3-5 screenshots

#### Apple Watch Ultra 2
- Filename format: `Watch_Ultra_1.png`, `Watch_Ultra_2.png`, etc.
- Required: 3-5 screenshots

#### Apple Watch Series 10 (42mm)
- Filename format: `Watch_42mm_1.png`, `Watch_42mm_2.png`, etc.
- Required: 3-5 screenshots

## Suggested Screenshot Content

### iPhone Screenshots (in order):
1. **Main Lists View** - Show multiple lists with icons/emojis
2. **List Detail View** - Show items with quantities, some crossed out
3. **Item Detail with Photos** - Show an item with multiple photos attached
4. **Smart Suggestions** - Show autocomplete/suggestions in action
5. **Archive View** - Show archived lists feature
6. **Settings Screen** - Show Face ID lock and export options
7. **Export Options** - Show export formats and sharing

### Apple Watch Screenshots (in order):
1. **Watch Lists View** - Show list of lists on watch
2. **Watch Items View** - Show items in a list
3. **Item Completion** - Show completing an item
4. **Sync Indicator** - Show sync happening

## How to Capture Screenshots

### Using Xcode Simulator (iPhone)

```bash
# Launch simulator for specific device
xcrun simctl list devices

# Take screenshot (while simulator is focused)
# Cmd+S in simulator window
# Or use: xcrun simctl io booted screenshot screenshot.png

# For all required sizes, use:
# - iPhone 16 Pro Max (6.9")
# - iPhone 15 Pro Max (6.7")
# - iPhone 11 Pro Max (6.5")
# - iPhone 8 Plus (5.5")
```

### Using Xcode Simulator (Apple Watch)

```bash
# Launch paired watch simulator
# Take screenshot (Cmd+S)

# Required devices:
# - Apple Watch Series 11 (46mm)
# - Apple Watch Ultra 2
# - Apple Watch Series 10 (42mm)
```

### Tips for Great Screenshots

1. **Use Sample Data**: Add realistic, appealing sample data
2. **Show Features**: Each screenshot should highlight a key feature
3. **Clean UI**: No debug info, appropriate time (9:41 AM is Apple's standard)
4. **Good Lighting**: If using photos, use bright, clear images
5. **Consistent Theme**: Use same color scheme/theme across all screenshots
6. **Localization**: Take separate screenshots for each supported language

## Screenshot Order Matters

App Store shows screenshots in the order you upload them. The first 2-3 are most important as they appear in search results and app previews.

**Recommended Order:**
1. Most impressive/key feature
2. Second most important feature
3. Visual appeal (photos, watch integration)
4. Additional features (5-10)

## Optional: App Preview Videos

If creating app preview videos (recommended):
- Duration: 15-30 seconds
- Format: .mov or .mp4
- Same resolutions as screenshots
- Show app in action with smooth transitions
- No sound required (but recommended)

## Reference

Official Apple documentation:
https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications

