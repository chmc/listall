---
title: macOS Batch Screenshot Processing Script
date: 2026-01-02
severity: MEDIUM
category: macos
tags: [bash, imagemagick, batch-processing, shellcheck, locales]
symptoms: [need batch processing for multiple locales, atomic processing needed]
root_cause: Need automated processing of all screenshots across all locales
solution: Created process-macos-screenshots.sh with atomic temp directory pattern
files_affected:
  - .github/scripts/process-macos-screenshots.sh
related:
  - macos-screenshot-helper-implementation.md
  - macos-screenshot-integration.md
---

## Problem

Need batch processing script to process all macOS screenshots across all locales into App Store format.

## Solution

Created `.github/scripts/process-macos-screenshots.sh` with:

1. Argument parsing for input/output directories, dry-run, verbose modes
2. Dynamic locale discovery (finds all subdirectories except "processed")
3. Atomic processing using temp directory with trap cleanup
4. Continues after failures - processes all files even if some fail
5. Success/failure counting with summary

## Key Technical Details

### Proper Sourcing of Helper Library

```bash
# shellcheck source=lib/macos-screenshot-helper.sh
source "${SCRIPT_DIR}/lib/macos-screenshot-helper.sh"
```

### Avoid Mixing stdout and stderr in Functions

```bash
discover_locales() {
    # Log to stderr to avoid corrupting return value
    log_info "Discovered locales: ${locales[*]}" >&2

    # Output only data to stdout
    echo "${locales[@]}"
}
```

### Trap with Expanded Variables

```bash
temp_dir=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '${temp_dir}'" EXIT
```

SC2064 disabled because we intentionally expand at definition time.

### Declaring and Assigning Separately

```bash
# BAD: Masks return value (SC2155)
readonly SCRIPT_DIR="$(cd ... && pwd)"

# GOOD: Separate declaration
SCRIPT_DIR="$(cd ... && pwd)"
readonly SCRIPT_DIR
```

### Arithmetic Increment Safety

```bash
# BAD: Fails with set -e when count is 0
((count++))

# GOOD: Safe
((count++)) || true
```

## Output Example

```
[INFO] macOS Screenshot Processor
[INFO] Discovered locales: en-US fi
[INFO] Processing locale: en-US (4 files)
[OK] Processed: 01_MainWindow.png [800x652 -> 2880x1800]
[OK] Processed: 02_ListDetailView.png [800x652 -> 2880x1800]
...
[INFO] Processing complete:
[INFO]   Success: 8
[INFO]   Failed:  0
```

## Key Learnings

1. **Function return values via stdout** - never mix log messages with return data
2. **Trap timing** - double quotes for immediate expansion, single for deferred
3. **Separate declare and assign** - avoids masking return values
4. **Use `|| true` with arithmetic** - prevents errexit failures
