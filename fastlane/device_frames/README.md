# Device Frame Assets

This directory contains device frame assets and metadata for the custom screenshot framing solution.

## Directory Structure

```
device_frames/
├── iphone/
│   ├── metadata.json                     # iPhone frame specifications
│   └── iphone_16_pro_max_black.png       # iPhone frame asset (placeholder)
├── ipad/
│   ├── metadata.json                     # iPad frame specifications
│   └── ipad_pro_13_m4_black.png         # iPad frame asset (placeholder)
└── watch/
    ├── metadata.json                     # Apple Watch frame specifications
    └── apple_watch_series_10_46mm_black.png  # Watch frame asset (placeholder)
```

## Metadata Format

Each `metadata.json` file contains:

- **device**: Human-readable device name
- **screen_area**: Coordinates where screenshot is placed within frame
  - `x`, `y`: Top-left corner offset in pixels
  - `width`, `height`: Expected screenshot dimensions
- **frame_dimensions**: Total size of the framed output
  - `width`, `height`: Frame image dimensions
- **variants**: Available frame color/finish options
- **default_variant**: Default variant to use if not specified
- **corner_radius**: Device screen corner radius (for validation)

## Supported Devices

### iPhone 16 Pro Max
- **Screen Size**: 1290 x 2796 pixels (6.7-inch display)
- **App Store Requirement**: Primary iPhone size class
- **Frame Type**: Black Titanium, Natural Titanium, White Titanium

### iPad Pro 13-inch M4
- **Screen Size**: 2064 x 2752 pixels (13-inch Ultra Retina XDR)
- **App Store Requirement**: 2024+ iPad Pro size class
- **Frame Type**: Space Black, Silver
- **Note**: This device was NOT supported by Frameit

### Apple Watch Series 10 46mm
- **Screen Size**: 396 x 484 pixels (Always-On Retina)
- **App Store Requirement**: Large watch size class
- **Frame Type**: Black Aluminum, Silver Aluminum, Natural Titanium
- **Note**: Apple Watch was NEVER supported by Frameit

## Acquiring Frame Assets

### Option 1: Apple Design Resources (Recommended)

1. Visit [Apple Design Resources](https://developer.apple.com/design/resources/)
2. Download device mockup PSDs for iOS, iPadOS, and watchOS
3. Open in Photoshop or Figma
4. Export the device bezel layer as PNG with transparent background
5. Measure the screen area coordinates using the ruler tool
6. Update `metadata.json` with exact measurements
7. Replace placeholder PNG files with exported frames

### Option 2: MockUPhone (Quick Start)

1. Visit [MockUPhone](https://mockuphone.com/)
2. Upload a sample screenshot
3. Select appropriate device model
4. Download the framed result
5. Extract frame using image editing tools
6. Measure screen area coordinates
7. Update metadata and replace placeholder

### Option 3: Custom Creation

Use Figma or Sketch to create custom device frames following Apple's design guidelines.

## Frame Requirements

- **Format**: PNG with alpha transparency
- **Color Space**: sRGB
- **Background**: Transparent (alpha channel)
- **Quality**: High resolution (2x or 3x)
- **Accuracy**: Screen area must precisely match device specifications

## Metadata Accuracy

The screen area coordinates must be pixel-perfect. Incorrect measurements will result in:
- Screenshot misalignment
- Visible gaps or overlaps
- Failed validation checks

Use ImageMagick to verify:

```bash
# Check frame dimensions
identify -format '%wx%h' iphone_16_pro_max_black.png

# Verify transparency
identify -format '%[channels]' iphone_16_pro_max_black.png
# Should include: srgba
```

## Integration with DeviceFrameRegistry

The `DeviceFrameRegistry` module automatically:
1. Detects device type from screenshot filenames
2. Loads the appropriate metadata.json
3. Validates screenshot dimensions
4. Selects the correct frame variant
5. Provides coordinates for ImageMagick composite operations

## Placeholder Status

**CURRENT STATUS**: All PNG files are placeholders (0 bytes)

These need to be replaced with actual device frame images before the framing functionality will work. The metadata files contain realistic measurements based on actual device dimensions.

## License & Attribution

Device frame assets must comply with:
- **Apple Design Resources License Agreement**
- **Apple Marketing Guidelines**
- Usage restricted to App Store marketing materials

Frame assets are NOT included in this repository. Developers must acquire them separately from Apple's official resources.

## See Also

- `/Users/aleksi/source/ListAllApp/documentation/todo.framed_screenshots.md` - Full implementation plan
- `/Users/aleksi/source/ListAllApp/fastlane/lib/device_frame_registry.rb` - Registry implementation
- `/Users/aleksi/source/ListAllApp/fastlane/lib/framing_helper.rb` - Framing logic (to be implemented)
