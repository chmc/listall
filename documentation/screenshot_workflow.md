# Screenshot Workflow Guide

Complete automation workflow for generating and delivering App Store screenshots.

## Overview

The screenshot pipeline consists of four stages:

1. **Raw Capture** → Automated UI tests capture screenshots on simulators
2. **Normalization** → Resize to Frameit-supported dimensions
3. **Framing** → Add device frames and captions
4. **Delivery** → Filter framed variants and upload to App Store Connect

## Quick Reference

### Generate All Screenshots (Raw + Framed)

```bash
bundle exec fastlane screenshots_framed
```

This single command:
- Captures raw screenshots via UI tests (iPhone + iPad, EN + FI)
- Normalizes sizes for Frameit compatibility
- Adds device frames and captions
- Outputs to `fastlane/screenshots/framed/`

### Verify Screenshots Before Upload

```bash
bundle exec fastlane release_dry_run
```

Shows what would be uploaded:
- Lists all framed screenshots by locale
- Displays dimensions to verify sizing
- No actual upload (requires ASC API key for auth only)

### Upload to App Store Connect

```bash
bundle exec fastlane release
```

Uploads framed screenshots to App Store Connect:
- Automatically filters to framed variants only
- Overwrites existing screenshots
- Skips binary upload (metadata/screenshots only)
- Does NOT submit for review (manual step)

## Directory Structure

```
fastlane/
├── screenshots/              # Raw captures from snapshot
│   ├── en-US/
│   │   ├── iPhone 17 Pro Max-01-WelcomeScreen.png
│   │   ├── iPad Pro 13-inch (M4)-01-WelcomeScreen.png
│   │   └── ...
│   └── fi/
├── screenshots_compat/       # Normalized sizes for Frameit
│   ├── en-US/               # (1290x2796 iPhone, 2048x2732 iPad)
│   └── fi/
├── screenshots/framed/       # Framed outputs (mixed)
│   ├── en-US/
│   │   ├── *-01-*.png                    # Raw normalized
│   │   ├── *-01-*_framed.png            # Framed (UPLOAD THESE)
│   │   └── ...
│   └── fi/
└── screenshots/delivery/     # Framed only (temporary)
    ├── en-US/               # (1421x2909 iPhone, 2286x3168 iPad)
    │   ├── *_framed.png     # 10 files (5 iPhone + 5 iPad)
    │   └── ...
    └── fi/
```

## Screenshot Scenes (5 per device/locale)

1. **01-WelcomeScreen** — Empty state with template list suggestions
2. **02-ListsHome** — Main view with 4 test lists
3. **03-ListDetail** — Grocery Shopping list with items
4. **04-ItemDetail** — Individual item editing view
5. **05-Settings** — App settings screen

## Devices

- **iPhone 17 Pro Max** (6.7" → 1290x2796 raw, 1421x2909 framed)
- **iPad Pro 13-inch (M4)** (2048x2732 raw, 2286x3168 framed)

## Locales

- **en-US** (English - United States)
- **fi** (Finnish)

## Total Screenshot Count

- **20 raw captures** (2 devices × 5 scenes × 2 locales)
- **20 framed variants** (same breakdown)
- **20 delivery files** (framed only, 10 per locale)

## Framing Details

Device frames and captions configured in `fastlane/Framefile.json`:

- **Background**: Dark (#0E1117)
- **Font**: SF Pro Display Semibold
- **Captions**: Per-scene, localized for EN and FI
- **Frame library**: Frameit built-in device frames

## Fastlane Lanes

### Core Screenshot Lanes

| Lane | Purpose | Output |
|------|---------|--------|
| `screenshots` | Raw captures only | `fastlane/screenshots/` |
| `screenshots_framed` | Full pipeline (raw → normalized → framed) | `fastlane/screenshots/framed/` |
| `verify_framed` | Validate framed screenshots exist | Exit code (0 = success) |

### Delivery Lanes

| Lane | Purpose | Requires ASC Key |
|------|---------|------------------|
| `release_dry_run` | Verify screenshots ready for upload | Yes (auth only) |
| `release` | Upload metadata/screenshots to ASC | Yes (full access) |

## Prerequisites

### Local Development

1. **Ruby 3.0+** with Bundler
2. **ImageMagick** for image manipulation
   ```bash
   brew install imagemagick
   ```
3. **Xcode 16+** with iOS 18+ simulators
4. **App Store Connect API Key** (`.env` file)
   ```
   ASC_KEY_ID=ABC123XYZ
   ASC_ISSUER_ID=12345678-1234-1234-1234-123456789012
   ASC_KEY_BASE64=LS0tLS1CRUd...
   ```

### CI/CD (GitHub Actions)

Repository secrets configured:
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_BASE64`

## Common Tasks

### Regenerate Screenshots After UI Changes

```bash
# Full regeneration (recommended)
bundle exec fastlane screenshots_framed

# Verify before upload
bundle exec fastlane release_dry_run

# Upload when ready
bundle exec fastlane release
```

### Update Captions Only

1. Edit `fastlane/Framefile.json`
2. Re-run framing (uses existing normalized screenshots):
   ```bash
   cd fastlane/screenshots_compat
   frameit --config ../Framefile.json
   # Then copy framed variants to ../screenshots/framed/
   ```

### Test Screenshot Generation Locally

```bash
# Build for testing first
xcodebuild build-for-testing \
  -project ListAll/ListAll.xcodeproj \
  -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ListAll/build

# Run snapshot
bundle exec fastlane screenshots
```

## Troubleshooting

### Screenshots Missing or Wrong Size

- Check `Snapfile` device names match available simulators: `xcrun simctl list devices`
- Verify UI test launch arguments in `ListAllUITests.swift`
- Ensure `UITEST_MODE` and `UITEST_SEED=1` are set

### Framing Fails

- Verify ImageMagick installed: `magick --version`
- Check normalized sizes in `screenshots_compat/` (should be 1290x2796 or 2048x2732)
- Validate `Framefile.json` syntax

### Deliver Upload Fails

- Verify ASC API key has App Manager or Developer role
- Check app exists in App Store Connect
- Ensure screenshot dimensions match App Store requirements
- Use `release_dry_run` to preview before upload

## Future Enhancements (Phase 4)

- **watchOS screenshots** (automated via simctl)
- **Dark mode variants** (remove `FORCE_LIGHT_MODE` flag)
- **Additional locales** (add to `Snapfile` languages array)

## References

- [Fastlane Snapshot Docs](https://docs.fastlane.tools/actions/snapshot/)
- [Fastlane Frameit Docs](https://docs.fastlane.tools/actions/frameit/)
- [Fastlane Deliver Docs](https://docs.fastlane.tools/actions/deliver/)
- [App Store Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
