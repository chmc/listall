# 🚀 CI Pipeline Quick Reference

One-page cheat sheet for common CI tasks. Keep this handy!

---

## 📋 Before You Commit

```bash
# Fast check (1-2s) - Run every time
.github/scripts/test-pipeline-locally.sh --validate-only

# Quick test (10-15s) - Before pushing CI changes
.github/scripts/test-pipeline-locally.sh --quick

# Full test (60-90min) - Before major releases
.github/scripts/test-pipeline-locally.sh --full
```

**Install pre-commit hook** (optional, runs validate-only automatically):
```bash
ln -sf ../../.github/hooks/pre-commit .git/hooks/pre-commit
```

---

## 🎬 Trigger Pipeline

```bash
# Start screenshot generation
gh workflow run prepare-appstore.yml -f version=1.2.0

# Watch progress in real-time
gh run watch

# List recent runs
gh run list --workflow=prepare-appstore.yml --limit 5
```

---

## 🔍 When Pipeline Fails

```bash
# Auto-diagnose latest run
.github/scripts/analyze-ci-failure.sh --latest

# Auto-diagnose specific run
.github/scripts/analyze-ci-failure.sh 19667213668

# View in browser
gh run view 19667213668 --web

# Download logs
gh run view 19667213668 --log > run.log
```

**Common fixes:**
- Pre-flight failure → Check TROUBLESHOOTING.md#pre-flight-check-failures
- Simulator boot → Check TROUBLESHOOTING.md#simulator-boot-failures
- Timeout → Check TROUBLESHOOTING.md#screenshot-generation-timeouts
- Validation → Check TROUBLESHOOTING.md#screenshot-validation-failures

---

## 📸 Screenshot Management

### Download Screenshots
```bash
# Download all artifacts from run
gh run download 19667213668

# Download specific artifact
gh run download 19667213668 --name screenshots-iphone
```

### Validate Locally
```bash
# Validate iPhone screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone

# Validate iPad screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad

# Validate Watch screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

### Compare Runs (Regression Detection)
```bash
# Compare two runs (default 5% threshold)
.github/scripts/compare-screenshots.sh 19660858956 19667213668

# With custom threshold (10%)
.github/scripts/compare-screenshots.sh 19660858956 19667213668 --threshold 10
```

**Output:**
- Report: `screenshot-comparison-<run1>-vs-<run2>.md`
- Diffs: `screenshot-diffs-<run1>-vs-<run2>/`

---

## ⏱️ Performance Tracking

```bash
# Track latest run
.github/scripts/track-performance.sh --latest

# Track specific run
.github/scripts/track-performance.sh 19667213668

# View history (last 10 runs)
.github/scripts/track-performance.sh --history 10

# View history (last N runs)
.github/scripts/track-performance.sh --history 20
```

**Data stored in:** `.github/performance-history.csv`

---

## 📋 Release Checklist

```bash
# Generate for latest run
.github/scripts/release-checklist.sh --latest 1.2.0

# Generate for specific run
.github/scripts/release-checklist.sh 19667213668 1.2.0
```

**Output:** `release-checklist-v1.2.0.md`

---

## 🔧 Simulator Management

### Find Simulators
```bash
# Find iPhone
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS

# Find iPad
.github/scripts/find-simulator.sh "iPad Pro 13-inch (M4)" iOS

# Find Watch
.github/scripts/find-simulator.sh "Apple Watch Series 10 (46mm)" watchOS
```

### Clean Simulators
```bash
# Shutdown all
xcrun simctl shutdown all

# Delete unavailable
xcrun simctl delete unavailable

# Erase all data
xcrun simctl erase all

# List available
xcrun simctl list devices available
```

### Clean Watch Duplicates
```bash
.github/scripts/cleanup-watch-duplicates.sh
```

---

## 🏥 Environment Check

```bash
# Full pre-flight check
.github/scripts/preflight-check.sh

# Check Xcode version
xcodebuild -version

# Check Ruby/Bundler
ruby --version
bundle --version

# Check ImageMagick
magick --version

# Check disk space
df -h .
```

---

## 📊 Screenshot Info

### Check Dimensions
```bash
# Single file
identify -format '%wx%h' screenshot.png

# All files in directory
find fastlane/screenshots_compat -name "*.png" -exec identify -format '%f: %wx%h\n' {} \;
```

### Check File Size
```bash
ls -lh screenshot.png

# Find small files (<10KB)
find fastlane/screenshots_compat -name "*.png" -size -10k
```

### Check Brightness (blank detection)
```bash
# Returns 0.0 (black) to 1.0 (white)
magick screenshot.png -colorspace Gray -format "%[fx:mean]" info:
```

**Expected dimensions:**
- iPhone 16 Pro Max: 1290x2796
- iPad Pro 13": 2064x2752
- Apple Watch Series 10: 396x484

---

## 🐛 Debug Mode

### Fastlane Verbose
```bash
bundle exec fastlane ios screenshots_iphone --verbose
```

### Capture Logs
```bash
# Simulator logs
tail -f ~/Library/Logs/CoreSimulator/*/system.log

# Fastlane logs
ls -lt ~/Library/Logs/snapshot/

# xcresult files
find . -name "*.xcresult" -type d
```

### Manual Screenshot Generation
```bash
# iPhone
bundle exec fastlane ios screenshots_iphone

# iPad
bundle exec fastlane ios screenshots_ipad

# Watch
bundle exec fastlane ios watch_screenshots
```

---

## 📱 App Store Connect

### Upload Manually
```bash
# Full upload (metadata + screenshots)
bundle exec fastlane release version:1.2.0

# Validate only (no upload)
bundle exec fastlane ios validate_delivery_screenshots
```

### Check Secrets
```bash
# Verify environment variables are set
echo $ASC_KEY_ID
echo $ASC_ISSUER_ID
echo $ASC_KEY_BASE64

# In GitHub (requires admin access)
gh secret list
```

---

## 🔄 Git Operations

### Feature Branch Workflow
```bash
# Create branch
git checkout -b feature/my-changes

# Make changes, test locally
.github/scripts/test-pipeline-locally.sh --quick

# Commit
git add .
git commit -m "Description"

# Push
git push origin feature/my-changes

# Merge to main (after CI passes)
git checkout main
git pull origin main
git merge feature/my-changes
git push origin main
```

### Tag Release
```bash
# Create annotated tag
git tag -a v1.2.0 -m "Release version 1.2.0"

# Push tag
git push origin v1.2.0

# List tags
git tag -l
```

---

## 🆘 Emergency Fixes

### Pipeline Stuck
```bash
# Cancel run
gh run cancel 19667213668

# List running
gh run list --workflow=prepare-appstore.yml --status in_progress
```

### Cleanup Old Artifacts
```bash
# List artifacts
gh api repos/:owner/:repo/actions/artifacts | jq '.artifacts[] | {id, name, created_at}'

# Delete specific artifact (requires run ID)
gh api repos/:owner/:repo/actions/artifacts/<artifact-id> -X DELETE
```

### Re-run Failed Jobs
```bash
# Re-run failed jobs only
gh run rerun 19667213668 --failed

# Re-run entire workflow
gh run rerun 19667213668
```

---

## 📚 Documentation Quick Links

| Need | Document | Path |
|------|----------|------|
| **Getting started** | Development Guide | `.github/DEVELOPMENT.md` |
| **Pipeline failing** | Troubleshooting | `.github/workflows/TROUBLESHOOTING.md` |
| **Script reference** | Scripts README | `.github/scripts/README.md` |
| **Overview** | Main README | `.github/README.md` |
| **This guide** | Quick Reference | `.github/QUICK_REFERENCE.md` |

---

## 💡 Pro Tips

1. **Always test locally first**
   ```bash
   .github/scripts/test-pipeline-locally.sh --quick
   ```

2. **Use the analyzer for any failure**
   ```bash
   .github/scripts/analyze-ci-failure.sh --latest
   ```

3. **Track performance after every release**
   ```bash
   .github/scripts/track-performance.sh --latest
   ```

4. **Compare screenshots before major changes**
   ```bash
   .github/scripts/compare-screenshots.sh <before> <after>
   ```

5. **Keep simulators clean**
   ```bash
   xcrun simctl shutdown all
   xcrun simctl delete unavailable
   ```

6. **Monitor timeout usage** (alert at >60%)
   - iPhone: 90min limit
   - iPad: 120min limit
   - Watch: 90min limit

7. **Check performance history trends**
   ```bash
   .github/scripts/track-performance.sh --history 10
   ```

---

## 🎯 Common Workflows

### Workflow: "I want to release v1.2.0"
```bash
# 1. Trigger pipeline
gh workflow run prepare-appstore.yml -f version=1.2.0

# 2. Watch progress
gh run watch

# 3. Track performance
.github/scripts/track-performance.sh --latest

# 4. Generate checklist
.github/scripts/release-checklist.sh --latest 1.2.0

# 5. Follow checklist
cat release-checklist-v1.2.0.md
```

### Workflow: "Pipeline failed, what now?"
```bash
# 1. Auto-diagnose
.github/scripts/analyze-ci-failure.sh --latest

# 2. Check linked troubleshooting section
# (analyzer provides direct links)

# 3. Fix locally and test
.github/scripts/test-pipeline-locally.sh --quick

# 4. Push fix
git add . && git commit -m "Fix: <issue>" && git push

# 5. Retry or wait for CI
gh run rerun --failed
```

### Workflow: "Did my change break anything?"
```bash
# 1. Get baseline run ID (before changes)
BASELINE=$(gh run list --workflow=prepare-appstore.yml --limit 5 --json databaseId,createdAt --jq '.[1].databaseId')

# 2. Get current run ID (after changes)
CURRENT=$(gh run list --workflow=prepare-appstore.yml --limit 1 --json databaseId --jq '.[0].databaseId')

# 3. Compare screenshots
.github/scripts/compare-screenshots.sh $BASELINE $CURRENT

# 4. Compare performance
.github/scripts/track-performance.sh $BASELINE
.github/scripts/track-performance.sh $CURRENT

# 5. Review reports
cat screenshot-comparison-*.md
```

---

## 🔢 Exit Codes Reference

All scripts return standard exit codes:
- `0` = Success
- `1` = Invalid arguments or general error
- `2` = Failed to download/access resources
- `3` = Validation/comparison failed
- `4+` = Script-specific errors (see script docs)

**Check exit code:**
```bash
.github/scripts/some-script.sh
echo $?  # Prints exit code
```

---

## 📞 Get Help

1. Check this quick reference
2. Run analyzer: `.github/scripts/analyze-ci-failure.sh --latest`
3. Check TROUBLESHOOTING.md for detailed solutions
4. Check DEVELOPMENT.md for local testing
5. File issue with analyzer output if problem persists

---

**Last Updated:** 2025-11-25
**Print this:** `cat .github/QUICK_REFERENCE.md`
**Keep handy:** Bookmark this file in your editor

🚀 Happy shipping!
