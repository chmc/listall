# Section 8: Code Fixes Learning

**Date:** December 20, 2025
**Task:** Apply 4 critical code fixes from MACOS_PLAN.md Section 8
**Status:** Successfully Completed

## Problem Statement

Apply the following code fixes to improve macOS screenshot automation reliability:
1. **Fix 8.1:** Keep Shell Hiding (Defense in Depth)
2. **Fix 8.2:** Fix AppleScript Case Comparison
3. **Fix 8.3:** Fix TCC Error Detection in Shell
4. **Fix 8.4:** Fix Process Termination in Fastfile

## Implementation Details

### Fix 8.1: Shell Hiding (Already in Place)

The `hide_and_quit_background_apps_macos()` function was already correctly implemented in `generate-screenshots-local.sh`. It:
- Closes non-essential applications using AppleScript
- Hides remaining visible apps
- Minimizes Finder windows
- Is called before `bundle exec fastlane ios screenshots_macos`

**Status:** Already done, verified working.

### Fix 8.2: AppleScript Case Comparison (Already in Place)

The `AppHidingScriptGenerator.swift` was already using native AppleScript case comparison:
- Uses `if appName is in {...}` for exact matches (case-insensitive)
- Uses `if appName contains "X" or appName contains "x"` for patterns
- No `tr '[:upper:]' '[:lower:]'` shell subprocess calls

**Status:** Already done, verified with tests.

### Fix 8.3: TCC Error Detection in Shell

**Problem:** Original code used `2>/dev/null || true` which silently discarded TCC errors.

**Solution:** Implemented `check_tcc_error()` helper function that:
1. Captures osascript stderr with `$(...) 2>&1`
2. Checks for TCC error patterns: `"not authorized"`, `"(-1743)"`
3. Logs actionable fix instructions when TCC errors detected
4. Continues execution (defense in depth - Swift layer is backup)

**Key Implementation:**
```bash
check_tcc_error() {
    local output="$1"
    local exit_code="$2"
    if [[ ${exit_code} -ne 0 ]]; then
        if [[ "${output}" == *"not authorized"* ]] || [[ "${output}" == *"(-1743)"* ]]; then
            log_warn "TCC Automation permissions may not be granted"
            log_warn "Fix: System Settings > Privacy & Security > Automation > Terminal/Xcode"
            log_warn "Continuing - Swift layer may still work (defense in depth)"
            return 1
        fi
    fi
    return 0
}
```

### Fix 8.4: Process Termination in Fastfile

Added `terminate_macos_app_verified()` helper method to Fastfile:
- Security: Input validation with regex `/\A[a-zA-Z0-9_-]+\z/`
- SIGTERM first (graceful), then SIGKILL (force)
- Polls for up to 10 seconds to confirm termination
- Filters zombie processes (state 'Z') from the count
- Returns true only when process confirmed dead

## Issues Encountered

### Bash Heredoc Quote Parsing Issue

**Problem:** Apostrophe inside heredoc within `$()` command substitution caused bash parse error:
```
unexpected EOF while looking for matching `'
```

**Root Cause:** Bash has trouble parsing single quotes inside `<<'DELIMITER'` heredocs when they're wrapped in `$()` command substitution.

**Solution:** Changed "doesn't" to "does not" in the AppleScript comment:
```bash
# Before (causes parse error)
-- (the "name is not in {list}" one-liner syntax doesn't work)

# After (works correctly)
-- (the "name is not in {list}" one-liner syntax does not work)
```

**Lesson:** Avoid contractions with apostrophes inside heredocs within command substitution.

## Test Results

**Unit Tests:** 703 tests, 0 failures
- TCC Permission Detection: 7 tests
- App Hiding Logic: 15 tests
- Screenshot Validation: 10 tests
- Window Capture Strategy: 12 tests
- Integration Tests: 20 tests

**Screenshot Tests:** 4/4 passing with defense-in-depth fallback

## Files Modified

1. `.github/scripts/generate-screenshots-local.sh`
   - Added `check_tcc_error()` helper function
   - Changed heredoc pattern from `2>/dev/null || true` to stderr capture
   - Fixed apostrophe in AppleScript comment

2. `fastlane/Fastfile`
   - Added `terminate_macos_app_verified()` method

3. `documentation/MACOS_PLAN.md`
   - Marked all Section 8 fixes as completed
   - Updated Phase Completion Checklist with verified metrics

## Lessons Learned

1. **Defense in Depth Works:** Having Shell + Swift + Fallback layers means even when one fails, the system continues working.

2. **TCC Errors Need Visibility:** Silent failure (`2>/dev/null`) makes debugging impossible. Always capture and check stderr for system permission errors.

3. **Bash Heredoc Quirks:** Avoid apostrophes/single-quotes inside heredocs within `$()`. Use alternative wording or escape sequences.

4. **Test Infrastructure Investment Pays Off:** 703 unit tests enabled rapid verification that code fixes didn't break anything.

5. **Process Termination is Complex:** Need SIGTERM + SIGKILL + polling + zombie filtering for reliable app termination.

## Metrics

- **Time to Complete:** ~1 hour (including debugging heredoc issue)
- **Fixes Applied:** 2 new (8.3, 8.4), 2 verified existing (8.1, 8.2)
- **Tests Passing:** 703 unit tests, 4/4 screenshot tests
- **Build Verification:** bash -n, shellcheck, ruby -c all passed
