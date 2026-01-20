---
title: Camera Not Opening on Real Device Debug Guide
date: 2025-06-01
severity: MEDIUM
category: ios
tags: [camera, uiimagepickercontroller, permissions, debugging, real-device]
symptoms: [camera not opening on physical device, button tappable but nothing happens, camera button grayed out]
root_cause: Multiple possible causes - permissions, UIImagePickerController availability, SwiftUI sheet issues
solution: Follow systematic debug flow checking permissions, console output, and device settings
files_affected: [ListAll/Views/ImagePicker.swift]
related: [macos-test-permission-fix.md, macos-app-groups-test-dialogs.md]
---

## Debug Decision Tree

```
Camera Button State?
       |
  +----+----+
  |         |
Disabled   Enabled
  |         |
  v         v
Check:    Tap it
isSourceTypeAvailable  |
returns false    +-----+-----+
  |              |           |
Causes:        Nothing    Camera opens
- Camera in use   |         |
- Restrictions    v         v
- Hardware fail  Check      SUCCESS
                 sheets
```

## Console Debug Messages

Expected log sequence on device:
```
DEBUG: Camera button - isSourceTypeAvailable: true
DEBUG: Camera button - disabled: false
DEBUG: Camera button tapped
DEBUG: Image source set to: camera
DEBUG: showingImagePicker set to: true
DEBUG: makeCameraController called
DEBUG: Camera available: true
DEBUG: Creating UIImagePickerController for camera
```

## Common Issues

| Symptom | Debug Output | Fix |
|---------|--------------|-----|
| Button disabled | `isSourceTypeAvailable: false` | Check restrictions, other apps using camera |
| Button works, no camera | No `makeCameraController` | SwiftUI sheet presentation issue |
| Controller created, no UI | All messages appear | UIImagePickerController presentation issue |

## Permission Checklist

1. **Info.plist**: `NSCameraUsageDescription` present
2. **Settings > Privacy > Camera**: App toggle ON
3. **Screen Time**: No Content & Privacy Restrictions

## Device vs Simulator

| Platform | Camera Button | Expected Behavior |
|----------|--------------|-------------------|
| Simulator | Disabled | Falls back to photo library |
| Real Device | Enabled | Opens camera interface |

## Quick Troubleshooting

1. Restart app completely
2. Restart device
3. Test camera in native Camera app
4. Check iOS version compatibility
5. Try different device if available
