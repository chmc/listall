# Feature Parity Verification

**Objective**: Discover feature gaps across all platforms and generate a report with technical details for TODO creation.

**Platforms**: macOS, iOS (iPhone), iPad, watchOS
**Categories**: 11 feature categories, 115+ features
**Output**: This file will contain the complete verification report when all tasks are completed.

---

## Task 0: Pre-Flight Checks

**Status**: pending

Run diagnostics and collect simulator UDIDs before starting verification.

### Checklist
- [ ] Run `listall_diagnostics` - verify MCP permissions
- [ ] Run `listall_list_simulators` - collect all UDIDs
- [ ] Select iPhone simulator UDID: _______________
- [ ] Select iPad simulator UDID: _______________
- [ ] Select Watch simulator UDID: _______________

### Results
```
iPhone UDID:
iPad UDID:
Watch UDID:
MCP Status:
```

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 1: Verify macOS - List Management

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Create List | | |
| Edit List | | |
| Delete List | | |
| Archive List | | |
| Restore Archived List | | |
| Duplicate List | | |
| Reorder Lists (drag-drop) | | |
| Multi-select Lists | | |
| Bulk Archive | | |
| Bulk Delete | | |
| Sample List Templates | | |
| Active/Archived Toggle | | |
| List Item Count Display | | |
| Archived Lists Read-only | | |

### Verification Steps
1. Launch macOS app with UITEST_MODE
2. Screenshot initial state
3. Create a new list → verify it appears
4. Edit list name → verify change
5. Archive list → verify moved to archived
6. Restore list → verify back in active
7. Delete list → verify removed
8. Screenshot final state

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 2: Verify macOS - Item Management

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Create Item | | |
| Edit Item | | |
| Delete Item | | |
| Toggle Completion | | |
| Item Title | | |
| Item Description | | |
| Item Quantity | | |
| Duplicate Item | | |
| Reorder Items (drag-drop) | | |
| Multi-select Items | | |
| Move/Copy to Another List | | |
| Bulk Delete | | |
| Undo Delete (5s) | | |
| Undo Complete (5s) | | |
| Strikethrough Animation | | |
| Keyboard Shortcuts | | |
| Context Menu | | |

### Verification Steps
1. Create item → verify appears
2. Edit item (title, description, quantity) → verify changes
3. Toggle completion → verify strikethrough
4. Delete item → verify undo banner
5. Screenshot results

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 3: Verify macOS - Images

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Add Images | | |
| View Images (gallery) | | |
| Delete Images | | |
| Reorder Images | | |
| Multi-image Support (10 max) | | |
| Thumbnail Caching | | |
| File Picker | | |
| Drag-and-Drop from Finder | | |
| Paste from Clipboard | | |
| Quick Look Preview (Space) | | |
| Thumbnail Size Slider | | |
| Multi-select Images | | |
| Copy to Clipboard | | |
| Collapsible Image Section | | |

### Verification Steps
1. Add image via file picker
2. Add image via drag-drop
3. Add image via paste
4. Quick Look preview
5. Adjust thumbnail size
6. Reorder images
7. Delete image
8. Screenshot gallery

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 4: Verify macOS - Filter/Sort/Search

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Sort by Order | | |
| Sort by Title (A-Z) | | |
| Sort by Title (Z-A) | | |
| Sort by Created Date | | |
| Sort by Modified Date | | |
| Sort by Quantity | | |
| Sort Direction Toggle | | |
| Filter: All Items | | |
| Filter: Active Only | | |
| Filter: Completed Only | | |
| Filter: Has Description | | |
| Filter: Has Images | | |
| Search Title | | |
| Search Description | | |
| Active Filter Indicator | | |
| Clear All Filters | | |

### Verification Steps
1. Apply each sort option → verify order changes
2. Apply each filter → verify items filtered
3. Search for item → verify results
4. Clear filters → verify reset
5. Screenshot filter UI

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 5: Verify macOS - Import/Export

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Export JSON | | |
| Export CSV | | |
| Export Plain Text | | |
| Copy to Clipboard | | |
| Export to File | | |
| Import JSON | | |
| Import Plain Text | | |
| Import Preview | | |
| Import Strategy: Merge | | |
| Import Strategy: Replace | | |
| Import Strategy: Append | | |
| Import Progress | | |
| Include Archived Lists | | |
| Include Images (base64) | | |
| Export All Lists | | |

### Verification Steps
1. Export list as JSON → verify file
2. Export as CSV → verify format
3. Copy to clipboard → verify content
4. Import JSON → verify preview and import
5. Screenshot export/import dialogs

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 6: Verify macOS - Settings

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Language Selection | | |
| Default Sort Order | | |
| Feature Tips Reset | | |
| Biometric Auth Toggle | | |
| Auth Timeout Duration | | |
| Export Data Button | | |
| Import Data Button | | |
| App Version Display | | |
| Preferences Window (Cmd+,) | | |
| Tab-based Layout | | |
| Website Link | | |

### Verification Steps
1. Open Preferences (Cmd+,)
2. Navigate each tab
3. Toggle settings → verify persistence
4. Screenshot each tab

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 7: Verify macOS - Sharing

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Share List as Text | | |
| Share List as JSON | | |
| Share All Data | | |
| Copy to Clipboard | | |
| Format Picker UI | | |
| Options: Crossed-out Items | | |
| Options: Descriptions | | |
| Options: Quantities | | |
| Options: Dates | | |
| Options: Images | | |

### Verification Steps
1. Share single list → verify format picker
2. Toggle share options → verify content changes
3. Share all data → verify export
4. Screenshot share dialog

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 8: Verify macOS - Suggestions

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Title Matching | | |
| Fuzzy Matching | | |
| Frequency Scoring | | |
| Recency Scoring | | |
| Combined Scoring | | |
| Cross-list Search | | |
| Exclude Current Item | | |
| Recent Items List | | |
| Collapse/Expand Toggle | | |
| Score Indicators | | |
| Hot Item Indicator | | |
| Fill Title on Select | | |
| Fill Quantity on Select | | |

### Verification Steps
1. Create several items with similar names
2. Start new item → type 2+ characters
3. Verify suggestions appear
4. Select suggestion → verify auto-fill
5. Screenshot suggestions UI

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 9: Verify macOS - Sync/Cloud

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| iCloud Sync (automatic) | | |
| Multi-device Sync | | |
| Sync Status Display | | |
| Manual Sync Button | | |
| Conflict Resolution | | |
| Offline Queue | | |
| Handoff Support | | |
| Sync Tab in Settings | | |

### Verification Steps
1. Check sync status indicator in toolbar
2. Click manual sync → verify animation
3. Check Settings > Sync tab
4. Screenshot sync UI

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 10: Verify macOS - UI/Navigation

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| NavigationSplitView (3-column) | | |
| Sidebar Navigation | | |
| Menu Bar Commands | | |
| Keyboard Shortcuts | | |
| Focus States | | |
| Multi-window Support | | |
| Context Menus | | |
| Sheet Presentations | | |
| Alerts/Confirmations | | |
| Empty State Views | | |
| Loading Indicators | | |
| Quick Entry Window | | |
| Services Menu Integration | | |
| Dark Mode Support | | |

### Verification Steps
1. Navigate via sidebar
2. Test keyboard shortcuts (Cmd+N, Cmd+Shift+N, etc.)
3. Right-click context menus
4. Open Quick Entry (Cmd+Option+Space)
5. Screenshot navigation patterns

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 11: Verify macOS - Accessibility

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| VoiceOver Labels | | |
| VoiceOver Hints | | |
| VoiceOver Values | | |
| VoiceOver Traits | | |
| Keyboard Navigation | | |
| High Contrast | | |
| Reduce Motion | | |
| Dark Mode | | |
| Focus Indicators | | |

### Verification Steps
1. Query UI for accessibility labels
2. Verify key elements have identifiers
3. Test keyboard-only navigation
4. Screenshot with VoiceOver hints

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 12: Cleanup macOS, Start iOS

**Status**: pending

1. Quit macOS app
2. Boot iPhone simulator
3. Launch iOS app with UITEST_MODE

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 13: Verify iOS - List Management

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Create List | | |
| Edit List | | |
| Delete List | | |
| Archive List | | |
| Restore Archived List | | |
| Duplicate List | | |
| Reorder Lists (drag-drop) | | |
| Multi-select Lists | | |
| Bulk Archive | | |
| Bulk Delete | | |
| Sample List Templates | | |
| Swipe-to-Archive | | |
| Swipe Actions Menu | | |
| Pull-to-Refresh | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 14: Verify iOS - Item Management

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Create Item | | |
| Edit Item | | |
| Delete Item | | |
| Toggle Completion | | |
| Item Title/Description/Quantity | | |
| Duplicate Item | | |
| Reorder Items | | |
| Swipe-to-Delete | | |
| Swipe Actions | | |
| Tap to Toggle | | |
| Strikethrough Animation | | |
| Haptic Feedback | | |
| Undo Delete/Complete | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 15: Verify iOS - Images

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Add Images (Photo Library) | | |
| Add Images (Camera) | | |
| View Images (gallery) | | |
| Delete Images | | |
| Reorder Images | | |
| Multi-image (10 max) | | |
| Pinch-to-Zoom | | |
| Double-tap Zoom | | |
| Swipe Between Images | | |
| Thumbnail Caching | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 16: Verify iOS - Filter/Sort/Search

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| All Sort Options | | |
| All Filter Options | | |
| Search Title/Description | | |
| Filter Indicator | | |
| Clear Filters | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 17: Verify iOS - Import/Export

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Export JSON/CSV/Text | | |
| UIActivityViewController | | |
| Import JSON/Text | | |
| Import Preview | | |
| Import Strategies | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 18: Verify iOS - Settings

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Language Selection | | |
| Default Sort Order | | |
| Add Button Position | | |
| Haptic Feedback Toggle | | |
| Biometric Auth (Face ID/Touch ID) | | |
| Auth Timeout | | |
| Feature Tips Reset | | |
| App Version | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 19: Verify iOS - Sharing/Suggestions/Sync

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Share via UIActivityViewController | | |
| Share Format Options | | |
| Smart Suggestions | | |
| iCloud Sync | | |
| Sync Status | | |
| Watch Sync Indicator | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 20: Verify iOS - UI/Navigation/Accessibility

**Status**: pending

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Tab Bar Navigation | | |
| Pull-to-Refresh | | |
| Swipe Gestures | | |
| Haptic Feedback | | |
| VoiceOver Support | | |
| Dynamic Type | | |
| Dark Mode | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 21: Cleanup iOS, Start iPad

**Status**: pending

1. Shutdown iPhone simulator
2. Boot iPad simulator
3. Launch iOS app (iPad mode) with UITEST_MODE

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 22: Verify iPad - All Categories

**Status**: pending

iPad uses same iOS codebase. Focus on iPad-specific differences:

### Features to Verify
| Feature | Status | Notes |
|---------|--------|-------|
| Split View Layout | | |
| Sidebar Navigation | | |
| Keyboard Shortcuts | | |
| Pointer/Trackpad Support | | |
| All iOS Features (spot check) | | |

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 23: Cleanup iPad, Start watchOS

**Status**: pending

1. Shutdown iPad simulator
2. Boot Watch simulator
3. Launch watchOS app with UITEST_MODE

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 24: Verify watchOS - Applicable Features

**Status**: pending

watchOS is read-only companion. Only verify applicable features:

### Features to Verify (Expected to Work)
| Feature | Status | Notes |
|---------|--------|-------|
| View Lists | | |
| View Items | | |
| Toggle Item Completion | | |
| Filter: All Items | | |
| Filter: Active | | |
| Filter: Completed | | |
| Sync Indicator | | |
| Navigation | | |
| VoiceOver Support | | |
| Haptic Feedback | | |

### Features N/A (By Design)
- Create/Edit/Delete Lists ❌
- Create/Edit/Delete Items ❌
- Images ❌
- Import/Export ❌
- Settings ❌
- Sharing ❌
- Suggestions ❌

### Gaps Found
| Gap | Severity | Implementation Hint |

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

## Task 25: Cleanup and Generate Report

**Status**: pending

1. Shutdown Watch simulator
2. Compile all gaps into executive summary
3. Generate TODO section
4. Calculate parity percentages

**Task Rule**: When starting this task, change "Status: pending" to "Status: in-progress". When completed, change to "Status: completed". If encountering problems, retry up to 3 times before marking as failed and proceeding to next task.

---

# Executive Summary

**Generated**: _pending_

## Platform Parity Matrix

| Platform | Verified | Full Parity | Partial | Missing | N/A | Unverified |
|----------|----------|-------------|---------|---------|-----|------------|
| macOS | | | | | | |
| iOS | | | | | | |
| iPad | | | | | | |
| watchOS | | | | | | |

## Critical Gaps (Priority 1)

_To be filled after verification_

## High Priority Gaps (Priority 2)

_To be filled after verification_

## Medium Priority Gaps (Priority 3)

_To be filled after verification_

---

# TODO: Implementation Tasks

_Generated from verification gaps. Copy to TODO.md when ready._

### Priority 1 (Critical)
_None yet_

### Priority 2 (High)
_None yet_

### Priority 3 (Medium)
_None yet_

### Priority 4 (Low)
_None yet_
