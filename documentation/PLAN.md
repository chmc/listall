# Fix iPad/iPhone Screenshot Framing in generate-screenshots-local.sh

## Context

Running `generate-screenshots-local.sh ipad` (or `iphone`) generates and normalizes screenshots correctly, but the framing step silently produces 0 framed screenshots. Only the `all` parameter works because it calls framing without a device filter. The root cause is a shell quoting bug that passes literal single-quote characters into the fastlane device_filter regex.

## Root Cause

In `.github/scripts/generate-screenshots-local.sh` lines 405-406:
```bash
iphone) filter_label="iPhone" ; fastlane_args="device_filter:'^iPhone'" ;;
ipad)   filter_label="iPad"   ; fastlane_args="device_filter:'^iPad'" ;;
```

The single quotes inside the double-quoted string are literal characters. When `${fastlane_args}` is expanded (unquoted) at line 434, bash does NOT strip quotes from variable expansions. Fastlane receives `device_filter:'^iPad'` with literal `'` characters, creates `Regexp.new("'^iPad'")`, which never matches filenames like `iPad Pro 13-inch (M4)-01_Welcome.png`.

The `all` path works because `frame_ios_screenshots_inplace` is called without arguments (line 811), so no filter is applied.

## Changes

### 1. Fix quoting bug — `generate-screenshots-local.sh` lines 405-406

Remove the extraneous single quotes. `^iPad` has no spaces or shell metacharacters.

```bash
# Before:
iphone) filter_label="iPhone" ; fastlane_args="device_filter:'^iPhone'" ;;
ipad)   filter_label="iPad"   ; fastlane_args="device_filter:'^iPad'" ;;

# After:
iphone) filter_label="iPhone" ; fastlane_args="device_filter:^iPhone" ;;
ipad)   filter_label="iPad"   ; fastlane_args="device_filter:^iPad" ;;
```

### 2. Fix misleading success message — line 465

The hardcoded message says "all iPhone/iPad" even when only one device was filtered.

```bash
# Before:
log_success "Device frames applied to all iPhone/iPad screenshots"

# After:
log_success "Device frames applied to ${filter_label} screenshots"
```

### 3. Add framing output validation — after line 437, before line 442

The function currently returns success even when 0 screenshots are framed. Add a check on the `screenshots_framed/ios/` directory.

```bash
# Verify that framing actually produced output
local framed_count
framed_count=$(find "${framed_dir}" -name "*.png" -type f 2>/dev/null | wc -l | tr -d ' ')
framed_count="${framed_count:-0}"
if [[ "${framed_count}" -eq 0 ]]; then
    log_error "Framing produced 0 screenshots — expected at least 1"
    log_error "Check that screenshots exist in fastlane/screenshots_compat/ and device_filter regex is correct"
    return "${EXIT_GENERATION_FAILED}"
fi
log_info "Framing produced ${framed_count} screenshots"
```

### 4. Add 0-match warning in fastlane lane — `fastlane/Fastfile` around line 4466

When a `device_filter` is specified but produces 0 framed screenshots, the lane should warn rather than silently report success.

```ruby
# After line 4463, before "Framed N screenshots" success line:
if total_framed == 0 && options[:device_filter]
  UI.important("Warning: device_filter '#{options[:device_filter]}' matched 0 screenshots")
end
```

## Files Modified

1. `.github/scripts/generate-screenshots-local.sh` — 3 changes (quoting fix, success message, framing validation)
2. `fastlane/Fastfile` — 1 change (0-match warning in `frame_screenshots_custom` lane)

## Verification

1. Run `generate-screenshots-local.sh ipad` — should frame 8 iPad screenshots (4 per locale × 2 locales)
2. Run `generate-screenshots-local.sh iphone` — should frame 8 iPhone screenshots
3. Verify framed dimensions differ from raw (framed includes device bezel): `magick identify fastlane/screenshots_compat/en-US/iPad*.png`
4. Verify `framed` mode still works: `generate-screenshots-local.sh framed`
5. Verify `all` still works (unchanged code path, no filter)
