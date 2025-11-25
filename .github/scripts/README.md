# CI Helper Scripts

This directory contains shell scripts used by the App Store screenshot generation pipeline.

## 🚀 Quick Start

**Test the pipeline locally before pushing:**

```bash
# Fast validation (1-2s) - Run before every commit
.github/scripts/test-pipeline-locally.sh --validate-only

# Quick test (10-15s) - Run before pushing CI changes
.github/scripts/test-pipeline-locally.sh --quick

# Full test (60-90min) - Run before major releases
.github/scripts/test-pipeline-locally.sh --full
```

**For detailed usage, see:** [`.github/DEVELOPMENT.md`](../DEVELOPMENT.md)

---

## Scripts Overview

### `test-pipeline-locally.sh`
**Purpose:** Simulate the complete CI pipeline locally for validation before push

**Usage:**
```bash
.github/scripts/test-pipeline-locally.sh [--full|--quick|--validate-only]
```

**Modes:**
- `--validate-only` (1-2s): Syntax checks, environment validation
- `--quick` (10-15s): All validations + simulator boot test (default)
- `--full` (60-90min): Complete pipeline with screenshot generation

**Tests:**
- ✅ Helper script existence and syntax
- ✅ Pre-flight environment check
- ✅ Simulator discovery and boot
- ✅ Screenshot generation (full mode only)
- ✅ Screenshot validation (full mode only)
- ✅ Fastfile and workflow YAML syntax
- ✅ Documentation completeness

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Invalid arguments

---

### `find-simulator.sh`
**Purpose:** Reliably find and validate iOS/watchOS simulators

**Usage:**
```bash
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS
.github/scripts/find-simulator.sh "Apple Watch Series 10 (46mm)" watchOS
```

**Features:**
- Environment variable injection (prevents shell injection)
- Validates simulator exists and is bootable
- UUID format verification (case-insensitive)
- Clear error messages with troubleshooting hints

**Exit Codes:**
- `0` - Success, UDID printed to stdout
- `1` - Missing arguments
- `2` - Failed to list simulators
- `3` - JSON parsing error
- `4` - No matching simulator found
- `5` - Invalid UDID format
- `6` - Simulator not bootable

---

### `cleanup-watch-duplicates.sh`
**Purpose:** Remove duplicate Apple Watch simulators to prevent "multiple devices matched" errors

**Usage:**
```bash
.github/scripts/cleanup-watch-duplicates.sh
```

**Features:**
- Finds all Watch Series 10 (46mm) simulators
- Keeps oldest watchOS version (matches Xcode 16.1 bundled watchOS 11.1)
- Deletes newer duplicates
- Safe: Only deletes if multiple instances found

**Exit Codes:**
- `0` - Success (or no duplicates found)
- `1` - Failed to list simulators
- `2` - JSON parsing error

---

### `validate-screenshots.sh`
**Purpose:** Validate screenshot dimensions, format, and content before upload

**Usage:**
```bash
.github/scripts/validate-screenshots.sh <directory> <device_type>

# Examples:
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

**Validates:**
- ✅ Dimensions match App Store requirements:
  - iPhone: 1290x2796
  - iPad: 2064x2752
  - Watch: 396x484
- ✅ File size > 10KB (detects corrupt files)
- ✅ Valid PNG format
- ✅ Not blank (brightness analysis: <5% or >95%)

**Exit Codes:**
- `0` - All screenshots valid
- `1` - Invalid arguments
- `2` - Directory not found
- `3` - Unknown device type
- `4` - ImageMagick not found
- `5` - No screenshots found
- `6` - Validation failed

---

### `preflight-check.sh`
**Purpose:** Validate CI environment before starting 90+ minute screenshot generation

**Usage:**
```bash
.github/scripts/preflight-check.sh
```

**Checks:**
- ✅ Xcode 16.1 availability
- ✅ Required simulators exist:
  - iPhone 16 Pro Max
  - iPad Pro 13-inch (M4)
  - Apple Watch Series 10 (46mm)
- ℹ️ ImageMagick (optional - workflow installs it)
- ✅ Ruby 3.2 and Bundler
- ✅ Disk space (500MB min, 2GB recommended)
- ✅ Required files (Fastfile, Snapfile, Gemfile)
- ✅ Network connectivity to appstoreconnect.apple.com

**Exit Codes:**
- `0` - All checks passed (or warnings only)
- `1` - One or more checks failed

---

### `analyze-ci-failure.sh`
**Purpose:** Automatically diagnose GitHub Actions workflow failures by analyzing logs

**Usage:**
```bash
# Analyze specific run
.github/scripts/analyze-ci-failure.sh <run-id>

# Analyze latest run
.github/scripts/analyze-ci-failure.sh --latest

# Analyze from piped logs
gh run view <run-id> --log | .github/scripts/analyze-ci-failure.sh --stdin
```

**Analyzes:**
- ✅ Pre-flight check failures (Xcode, simulators, dependencies)
- ✅ Simulator boot issues (duplicates, state corruption)
- ✅ Screenshot generation timeouts and app launch failures
- ✅ Screenshot validation failures (dimensions, blank images)
- ✅ ImageMagick conversion errors
- ✅ App Store Connect upload authentication issues
- ✅ Performance metrics and warnings

**Output:**
- Color-coded issue categories (errors, warnings, suspicious patterns)
- Direct links to troubleshooting guide sections
- Performance analysis with job durations
- Summary with error/warning counts
- Next steps recommendations

**Exit Codes:**
- `0` - Analysis completed (check output for issues)
- `1` - Invalid arguments or gh command failed

**Requirements:**
- GitHub CLI (`gh`) must be installed and authenticated

---

### `compare-screenshots.sh`
**Purpose:** Compare screenshots between two CI runs to detect visual regressions

**Usage:**
```bash
# Compare two runs
.github/scripts/compare-screenshots.sh <run-id-1> <run-id-2>

# With custom threshold
.github/scripts/compare-screenshots.sh 19660858956 19667213668 --threshold 10
```

**Features:**
- ✅ Downloads screenshots from both runs automatically
- ✅ Pixel-by-pixel comparison using ImageMagick
- ✅ Configurable difference threshold (default 5%)
- ✅ Generates diff images highlighting changes
- ✅ Creates markdown report with statistics
- ✅ Categorizes changes (identical, similar, different, missing, new)

**Output:**
- Markdown report: `screenshot-comparison-<run1>-vs-<run2>.md`
- Diff images directory: `screenshot-diffs-<run1>-vs-<run2>/`
- Console summary with color-coded results

**Use Cases:**
- Pre-release validation (compare before/after changes)
- Detect unintended UI regressions
- Code review assistance (visual changes)
- Quality assurance

**Requirements:**
- GitHub CLI (`gh`) must be installed
- ImageMagick must be installed

**Exit Codes:**
- `0` - Comparison completed (check report for details)
- `1` - Invalid arguments or missing dependencies
- `2` - Failed to download artifacts
- `3` - Comparison failed

---

### `track-performance.sh`
**Purpose:** Track CI pipeline performance metrics over time to detect degradation

**Usage:**
```bash
# Track specific run
.github/scripts/track-performance.sh <run-id>

# Track latest run
.github/scripts/track-performance.sh --latest

# View history
.github/scripts/track-performance.sh --history [N]
```

**Features:**
- ✅ Extracts timing data for all jobs
- ✅ Stores historical data in CSV format
- ✅ Calculates statistics (avg, min, max)
- ✅ Detects performance degradation (>20% slower)
- ✅ Warns when approaching timeout limits
- ✅ Tracks trends across multiple runs

**Metrics Tracked:**
- iPhone screenshot generation duration
- iPad screenshot generation duration
- Watch screenshot generation duration
- Upload duration
- Total pipeline duration
- Job conclusions (success/failure)

**Output:**
- Performance data saved to: `.github/performance-history.csv`
- Console report with job durations and analysis
- Warnings for timeout risks (>60% usage)
- Performance degradation alerts

**Use Cases:**
- Monitor pipeline health over time
- Detect performance regressions
- Capacity planning (timeout adjustments)
- Optimization impact measurement

**Requirements:**
- GitHub CLI (`gh`) must be installed

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments or gh command failed

---

### `release-checklist.sh`
**Purpose:** Generate comprehensive App Store release checklist after pipeline completion

**Usage:**
```bash
# Generate checklist for specific run
.github/scripts/release-checklist.sh <run-id> <version>

# Generate for latest run
.github/scripts/release-checklist.sh --latest <version>
```

**Features:**
- ✅ Validates pipeline completed successfully
- ✅ Generates detailed markdown checklist
- ✅ Includes all release steps (pre-release to post-release)
- ✅ Provides troubleshooting commands
- ✅ Links to relevant documentation
- ✅ Customized for the specific version

**Checklist Sections:**
1. **Pre-Release Verification** - Pipeline status, screenshots, quality
2. **App Store Connect** - Version creation, build selection, metadata
3. **Final Verification** - Technical checks, legal compliance
4. **Submission** - Submit for review, post-submission monitoring
5. **Post-Release** - After approval, monitoring, documentation

**Output:**
- Markdown file: `release-checklist-v<version>.md`
- Console summary with next steps
- Interactive checklist with checkboxes

**Use Cases:**
- Standardize release process
- Ensure nothing is forgotten
- Onboard new team members
- Document release history
- Quality assurance

**Requirements:**
- GitHub CLI (`gh`) must be installed

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments or gh command failed

---

### `cleanup-artifacts.sh`
**Purpose:** Cleanup old GitHub Actions artifacts to save storage space

**Usage:**
```bash
# Delete artifacts older than 30 days (default)
.github/scripts/cleanup-artifacts.sh

# Delete artifacts older than 60 days
.github/scripts/cleanup-artifacts.sh --older-than 60

# Preview what would be deleted
.github/scripts/cleanup-artifacts.sh --older-than 7 --dry-run
```

**Features:**
- ✅ Automatically deletes old artifacts
- ✅ Configurable age threshold (days)
- ✅ Dry-run mode for preview
- ✅ Shows storage savings
- ✅ Provides retention recommendations
- ✅ Checks against GitHub storage limits

**Use Cases:**
- Monthly maintenance to free up storage
- Prevent hitting 2GB storage limit
- Clean up after major testing periods
- Audit artifact retention policies

**Requirements:**
- GitHub CLI (`gh`) must be installed

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments or gh command failed

---

### `track-ci-cost.sh`
**Purpose:** Track GitHub Actions CI costs and usage over time

**Usage:**
```bash
# Current month summary
.github/scripts/track-ci-cost.sh

# Specific month
.github/scripts/track-ci-cost.sh --month 2025-11

# Detailed per-run breakdown
.github/scripts/track-ci-cost.sh --detailed
```

**Features:**
- ✅ Calculates total CI minutes used
- ✅ Estimates cost at macOS runner rate ($0.08/min)
- ✅ Tracks successful vs failed runs
- ✅ Projects monthly cost based on usage
- ✅ Checks against free tier limits
- ✅ Provides optimization recommendations
- ✅ Calculates cost per successful release

**Metrics:**
- Total minutes used (all jobs combined)
- Total cost at macOS rate
- Success/failure rate
- Daily average and projections
- Free tier utilization
- Cost per successful release

**Use Cases:**
- Budget planning and forecasting
- Cost optimization analysis
- Justify CI spending
- Track efficiency improvements

**Requirements:**
- GitHub CLI (`gh`) must be installed

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments or API error

---

### `generate-dashboard.sh`
**Purpose:** Generate visual CI pipeline health dashboard

**Usage:**
```bash
# Generate HTML dashboard
.github/scripts/generate-dashboard.sh

# Generate markdown dashboard
.github/scripts/generate-dashboard.sh --format markdown

# Custom output location
.github/scripts/generate-dashboard.sh --output reports/dashboard.html
```

**Features:**
- ✅ Visual HTML dashboard with charts
- ✅ Markdown format option
- ✅ Shows current pipeline status
- ✅ Recent runs table
- ✅ Success rate metrics
- ✅ Performance history (if available)
- ✅ Quick links to documentation
- ✅ Auto-refreshable

**Output Formats:**
- **HTML:** Beautiful interactive dashboard with styling
- **Markdown:** Text-based for README/docs

**Use Cases:**
- Team status updates
- Project documentation
- README badges
- Executive reporting
- Historical tracking

**Requirements:**
- GitHub CLI (`gh`) must be installed

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments

---

### `completions.bash`
**Purpose:** Bash completion for all CI helper scripts

**Usage:**
```bash
# Load completions for current session
source .github/scripts/completions.bash

# Add to ~/.bashrc for persistent completions
echo "source $(pwd)/.github/scripts/completions.bash" >> ~/.bashrc
```

**Features:**
- ✅ Tab completion for all script commands
- ✅ Suggests recent run IDs from GitHub
- ✅ Device name suggestions for simulators
- ✅ Common version number suggestions
- ✅ Flag and option completion
- ✅ Context-aware suggestions

**Supported Scripts:**
- test-pipeline-locally.sh (--full, --quick, --validate-only)
- analyze-ci-failure.sh (recent run IDs, --latest)
- compare-screenshots.sh (recent run IDs, --threshold)
- track-performance.sh (recent run IDs, --latest, --history)
- release-checklist.sh (recent run IDs, version suggestions)
- find-simulator.sh (device names, OS types)
- validate-screenshots.sh (directories, device types)

**Benefits:**
- Faster command entry
- Fewer typos
- Discover available options
- Better developer experience

---

## Development Guidelines

### Testing Scripts Locally

```bash
# Syntax check
bash -n .github/scripts/script-name.sh

# Run with test data
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS

# Test error cases
.github/scripts/find-simulator.sh "NonExistent Device" iOS || echo "Exit: $?"
```

### Adding New Scripts

1. Make executable: `chmod +x .github/scripts/new-script.sh`
2. Use shebang: `#!/bin/bash`
3. Use strict mode: `set -euo pipefail`
4. Document in this README
5. Add comprehensive error messages
6. Test locally before committing

### Shell Script Best Practices

**DO:**
- ✅ Quote all variables: `"$VAR"`
- ✅ Use explicit error checks: `if ! command; then`
- ✅ Provide clear error messages
- ✅ Use `>&2` for error output
- ✅ Exit with meaningful exit codes
- ✅ Test edge cases (empty input, missing files, etc.)

**DON'T:**
- ❌ Use `$?` after multiple commands
- ❌ Suppress errors with `|| true` unless intentional
- ❌ Mix stdout and stderr
- ❌ Use bare `rescue` in error handling
- ❌ Assume file existence without checking

### Security Considerations

These scripts handle:
- User input (device names)
- System commands (xcrun simctl)
- File operations (screenshots)

**Security measures:**
- Environment variable injection (not string interpolation)
- Input validation (UUID format, device names)
- No eval or arbitrary code execution
- Shellwords.escape in Ruby code

---

## Troubleshooting

### "Simulator not found"
```bash
# List available simulators
xcrun simctl list devices available

# Check specific device
xcrun simctl list devices available | grep "iPhone 16 Pro Max"
```

### "ImageMagick not found"
```bash
# Install ImageMagick
brew install imagemagick

# Verify installation
magick --version
```

### "Screenshot validation failed"
```bash
# Check dimensions
identify -format '%wx%h' screenshot.png

# Check file size
ls -lh screenshot.png

# Check brightness
magick screenshot.png -colorspace Gray -format "%[fx:mean]" info:
```

---

## Pipeline Integration

These scripts are called by `.github/workflows/prepare-appstore.yml`:

```yaml
# Pre-flight checks
- run: .github/scripts/preflight-check.sh

# Find and boot simulator
- run: |
    DEVICE_UDID=$(.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS)
    xcrun simctl bootstatus "$DEVICE_UDID" -b

# Validate screenshots after generation
- run: .github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
```

---

## Change Log

### 2025-11-25 - Comprehensive Hardening
- Created all four helper scripts
- Fixed 11 CRITICAL/HIGH bugs
- Fixed 4 MEDIUM priority issues
- Comprehensive testing and validation

---

## Contributing

When modifying these scripts:
1. Test locally with real scenarios
2. Run critical code review
3. Update this README if behavior changes
4. Test in CI before merging to main

🤖 This README generated by Claude Code
