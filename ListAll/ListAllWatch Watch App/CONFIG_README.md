# Watch App Configuration

This directory contains configuration files for the watch app.

## Configuration Files

### Config.plist.template
- **Purpose**: Template showing available configuration options
- **Status**: Committed to git
- **Usage**: Copy to `Config.plist` and modify

### Config.plist
- **Purpose**: Your local configuration settings
- **Status**: Ignored by git (in `.gitignore`)
- **Usage**: Edit this file to change settings

## Setup Instructions

1. **First time setup** (if `Config.plist` doesn't exist):
   ```bash
   cp Config.plist.template Config.plist
   ```

2. **Edit configuration**:
   - Open `Config.plist` in Xcode or any text editor
   - Modify the values as needed
   - Save the file

3. **Build and run**:
   - Clean build folder (Cmd+Shift+K)
   - Build and run the watch app
   - Configuration is loaded at runtime

## Available Settings

### ScreenshotMode
- **Type**: Boolean
- **Default**: `false`
- **Description**: Enable screenshot mode with sample data for App Store screenshots
- **Values**:
  - `true`: Show pre-defined English "Shopping List" with sample items
  - `false`: Use normal functionality with real user data

## Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ScreenshotMode</key>
	<false/>
</dict>
</plist>
```

## Important Notes

- ⚠️ Never commit `Config.plist` - it's for local development only
- ⚠️ Always disable `ScreenshotMode` before production builds
- ✅ Each team member can have their own settings
- ✅ The template file shows all available options

## Troubleshooting

**Configuration not working?**
1. Verify `Config.plist` exists in the correct location
2. Check that the file is included in the Xcode project
3. Clean build folder (Cmd+Shift+K) and rebuild
4. Verify the XML syntax is correct

**Need to reset to defaults?**
```bash
cp Config.plist.template Config.plist
```

## For More Information

See [watch_screenshot_mode.md](../../../documentation/watch_screenshot_mode.md) for detailed documentation on screenshot mode.
