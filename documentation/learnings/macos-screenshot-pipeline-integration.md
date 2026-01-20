---
title: macOS Screenshot App Store Pipeline Integration
date: 2026-01-03
severity: MEDIUM
category: ci-cd
tags: [github-actions, app-store, publish, screenshots, validation]
symptoms: [macOS screenshots not verified in publish workflow, missing from summary]
root_cause: publish-to-appstore.yml workflow didn't include macOS screenshot verification
solution: Add macOS verification steps and update summary to include macOS in table format
files_affected:
  - .github/workflows/publish-to-appstore.yml
related:
  - macos-screenshot-ci-validation.md
  - macos-batch-screenshot-processing.md
---

## Problem

The App Store publishing workflow needed to:
1. Verify macOS processed screenshots exist before upload
2. Validate screenshot counts per locale
3. Include macOS in workflow summary alongside iPhone, iPad, and Watch

## Solution

### 1. Added macOS to Verification Step

```yaml
echo "macOS screenshots (mac/processed):"
find fastlane/screenshots/mac/processed -name "*.png" -type f | wc -l | xargs echo "  Total files:"
ls -la fastlane/screenshots/mac/processed/en-US/ || { echo "Missing en-US macOS screenshots"; exit 1; }
```

### 2. Dedicated "Verify macOS screenshots exist" Step

```yaml
- name: Verify macOS screenshots exist
  run: |
    MACOS_DIR="fastlane/screenshots/mac/processed"

    if [[ ! -d "${MACOS_DIR}" ]]; then
      echo "::error::macOS processed screenshots directory not found"
      echo "::error::Run '.github/scripts/generate-screenshots-local.sh macos' locally first."
      exit 1
    fi

    EXPECTED_PER_LOCALE=4

    for locale_dir in "${MACOS_DIR}"/*/; do
      locale_name=$(basename "${locale_dir}")
      count=$(find "${locale_dir}" -name "*.png" -type f | wc -l | tr -d ' ')
      if [[ ${count} -ne ${EXPECTED_PER_LOCALE} ]]; then
        echo "::error::macOS locale ${locale_name}: expected ${EXPECTED_PER_LOCALE}, found ${count}"
        exit 1
      fi
    done
```

### 3. Updated Summary to Table Format

```yaml
echo "| Platform | Locales | Screenshots |" >> $GITHUB_STEP_SUMMARY
echo "|----------|---------|-------------|" >> $GITHUB_STEP_SUMMARY
echo "| iPhone | en-US, fi | 4 per locale (1290x2796) |" >> $GITHUB_STEP_SUMMARY
echo "| iPad 13\" | en-US, fi | 4 per locale (2064x2752) |" >> $GITHUB_STEP_SUMMARY
echo "| Watch | en-US, fi | 10 per locale (396x484) |" >> $GITHUB_STEP_SUMMARY
echo "| macOS | en-US, fi | 4 per locale (2880x1800) |" >> $GITHUB_STEP_SUMMARY
```

## Expected Counts

| Platform | Per Locale | Total (2 locales) |
|----------|------------|-------------------|
| iPhone | 4 | 8 |
| iPad | 4 | 8 |
| Watch | 10 | 20 |
| macOS | 4 | 8 |

## Key Learnings

1. **Use error annotations** - `::error::` makes failures visible in GitHub UI
2. **Handle wc whitespace** - macOS `wc` includes leading spaces, use `tr -d ' '`
3. **Fail early** - place verification steps before expensive operations
4. **Use tables in summaries** - easier to read than lists for multi-platform data
5. **Provide actionable errors** - tell users HOW to fix (run the local script)
