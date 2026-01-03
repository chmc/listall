# macOS Screenshot Pipeline Integration

**Date:** January 3, 2026
**Phase:** Phase 5 - App Store Pipeline Integration

## Problem

The App Store publishing workflow (`publish-to-appstore.yml`) needed to:
1. Verify macOS processed screenshots exist before upload
2. Validate screenshot counts per locale
3. Include macOS in the workflow summary alongside iPhone, iPad, and Watch

## Solution

Modified `.github/workflows/publish-to-appstore.yml` to add three key changes:

### 1. Added macOS to Existing Verification Step

Extended the "Verify screenshots exist in repository" step to also check macOS:

```yaml
echo "macOS screenshots (mac/processed):"
find fastlane/screenshots/mac/processed -name "*.png" -type f | wc -l | xargs echo "  Total files:"
ls -la fastlane/screenshots/mac/processed/en-US/ || { echo "Missing en-US macOS screenshots"; exit 1; }
ls -la fastlane/screenshots/mac/processed/fi/ || { echo "Missing fi macOS screenshots"; exit 1; }
```

### 2. New "Verify macOS screenshots exist" Step

Added a dedicated step with detailed validation:

```yaml
- name: Verify macOS screenshots exist
  run: |
    MACOS_DIR="fastlane/screenshots/mac/processed"

    if [[ ! -d "${MACOS_DIR}" ]]; then
      echo "::error::macOS processed screenshots directory not found: ${MACOS_DIR}"
      echo "::error::Run '.github/scripts/generate-screenshots-local.sh macos' locally first."
      exit 1
    fi

    EXPECTED_PER_LOCALE=4

    for locale_dir in "${MACOS_DIR}"/*/; do
      if [[ -d "${locale_dir}" ]]; then
        locale_name=$(basename "${locale_dir}")
        count=$(find "${locale_dir}" -name "*.png" -type f | wc -l | tr -d ' ')

        if [[ ${count} -ne ${EXPECTED_PER_LOCALE} ]]; then
          echo "::error::macOS locale ${locale_name}: expected ${EXPECTED_PER_LOCALE} screenshots, found ${count}"
          exit 1
        fi

        echo "macOS locale ${locale_name}: ${count} screenshots OK"
      fi
    done
```

### 3. New "Validate macOS screenshot count" Step

Added total count validation:

```yaml
- name: Validate macOS screenshot count
  run: |
    MACOS_DIR="fastlane/screenshots/mac/processed"
    TOTAL_COUNT=$(find "${MACOS_DIR}" -name "*.png" -type f | wc -l | tr -d ' ')
    EXPECTED_TOTAL=8  # 4 screenshots x 2 locales

    if [[ ${TOTAL_COUNT} -ne ${EXPECTED_TOTAL} ]]; then
      echo "::error::macOS screenshot count mismatch: expected ${EXPECTED_TOTAL}, found ${TOTAL_COUNT}"
      exit 1
    fi
```

### 4. Updated Summary to Include macOS

Changed summary format from list to table and added macOS:

```yaml
echo "| Platform | Locales | Screenshots |" >> $GITHUB_STEP_SUMMARY
echo "|----------|---------|-------------|" >> $GITHUB_STEP_SUMMARY
echo "| iPhone | en-US, fi | 4 per locale (1290x2796) |" >> $GITHUB_STEP_SUMMARY
echo "| iPad 13\" | en-US, fi | 4 per locale (2064x2752) |" >> $GITHUB_STEP_SUMMARY
echo "| Watch | en-US, fi | 10 per locale (396x484) |" >> $GITHUB_STEP_SUMMARY
echo "| macOS | en-US, fi | 4 per locale (2880x1800) |" >> $GITHUB_STEP_SUMMARY
```

## Key Technical Details

### GitHub Actions Error Annotations

Using `::error::` prefix creates visible error annotations in the GitHub Actions UI:

```bash
echo "::error::macOS processed screenshots directory not found: ${MACOS_DIR}"
```

This shows the error prominently in the workflow run summary and makes debugging easier.

### Whitespace Handling with wc

The `wc -l` command includes leading whitespace on macOS. Use `tr -d ' '` to remove it:

```bash
count=$(find "${locale_dir}" -name "*.png" -type f | wc -l | tr -d ' ')
```

### Step Placement

The macOS verification steps are placed BEFORE the upload step (`Upload metadata and screenshots to App Store Connect`), ensuring the workflow fails early if screenshots are missing.

## Expected Counts

| Platform | Per Locale | Total (2 locales) |
|----------|------------|-------------------|
| iPhone | 4 | 8 |
| iPad | 4 | 8 |
| Watch | 10 | 20 |
| macOS | 4 | 8 |

## Files Modified

- `.github/workflows/publish-to-appstore.yml` - Added macOS verification and updated summary

## Lessons Learned

1. **Use error annotations**: `::error::` makes failures visible in GitHub UI
2. **Handle wc whitespace**: macOS `wc` includes leading spaces
3. **Fail early**: Place verification steps before expensive operations
4. **Use tables in summaries**: Easier to read than lists for multi-platform data
5. **Provide actionable errors**: Tell users HOW to fix (run the local script)
