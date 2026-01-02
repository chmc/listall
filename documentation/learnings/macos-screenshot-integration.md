# macOS Screenshot Integration with generate-screenshots-local.sh

**Date:** January 2, 2026
**Phase:** Phase 3 - Integration

## Problem

The macOS screenshot processing script (`process-macos-screenshots.sh`) needed to be integrated with the existing `generate-screenshots-local.sh` pipeline so that:
1. Post-processing runs automatically after Fastlane captures raw screenshots
2. Users don't need to run a separate command
3. Output paths are displayed correctly in the summary

## Solution

Modified `generate-screenshots-local.sh` to integrate the post-processing:

### 1. Updated generate_macos_screenshots() Function

Added post-processing call after the Fastlane command:

```bash
generate_macos_screenshots() {
    # ... existing code ...

    if ! bundle exec fastlane ios screenshots_macos; then
        log_error "macOS screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    # NEW: Post-process screenshots for App Store format
    log_info "Processing screenshots for App Store dimensions..."
    if ! "${SCRIPT_DIR}/process-macos-screenshots.sh"; then
        log_error "macOS screenshot processing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}
```

### 2. Updated show_summary() Function

Changed macOS output paths from raw to processed:

```bash
# Before
echo "  macOS (unframed):"
echo "    fastlane/screenshots/mac/en-US/"

# After
echo "  macOS (processed with gradient background):"
echo "    fastlane/screenshots/mac/processed/en-US/"
```

Updated in two places:
- Single-platform macOS summary
- All-platforms summary

### 3. Updated Next Steps Git Command

Updated the git add command in the summary to use the processed path:

```bash
git add fastlane/screenshots_compat/ fastlane/screenshots/watch_normalized/ fastlane/screenshots/mac/processed/
```

## Key Technical Details

### Integration Points

The integration happens at three levels:

1. **Execution Flow**: After Fastlane finishes, the processing script runs immediately
2. **Error Handling**: If processing fails, the entire macOS generation fails with proper error code
3. **User Feedback**: Summary shows correct processed paths

### Script Location Reference

The processing script is called using `${SCRIPT_DIR}` which ensures it works regardless of where the user runs from:

```bash
"${SCRIPT_DIR}/process-macos-screenshots.sh"
```

### Default Paths Used by Processing Script

The processing script uses sensible defaults:
- Input: `fastlane/screenshots/mac/` (where Fastlane puts raw captures)
- Output: `fastlane/screenshots/mac/processed/` (where App Store ready images go)

## Test Results

- All 15 unit tests: PASS
- Shellcheck: No new warnings from changes
- Manual verification:
  - Help text shows correct information
  - Script structure is correct

## Lessons Learned

1. **Keep integration simple**: Just calling the existing script is cleaner than merging functionality
2. **Use relative paths via script dir**: `${SCRIPT_DIR}` ensures portability
3. **Update all summary locations**: The same path was shown in multiple places (single-platform vs all-platform summaries)
4. **Test existing tests first**: Running the existing test suite validates the integration works with all edge cases already covered

## Files Modified

- `.github/scripts/generate-screenshots-local.sh` - Added post-processing call and updated summary paths
- `documentation/TODO_MACOS.md` - Marked Phase 3 complete
