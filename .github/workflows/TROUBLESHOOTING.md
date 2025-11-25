# App Store Screenshot Pipeline - Troubleshooting Guide

This guide helps diagnose and fix common issues in the screenshot generation pipeline. Based on 140+ failed attempts before successful hardening.

## 🚨 Quick Diagnosis

### Is the pipeline failing?

**Check the run logs:** https://github.com/chmc/listall/actions/workflows/prepare-appstore.yml

**Common failure stages:**
1. ❌ Pre-flight check → Environment issue
2. ❌ Simulator boot → Simulator availability
3. ❌ Screenshot generation → Test timeout or crash
4. ❌ Screenshot validation → Wrong dimensions or corrupt files
5. ❌ Upload → App Store Connect credentials

---

## 📋 Common Issues & Solutions

### 1. Pre-flight Check Failures

#### ❌ "ImageMagick not installed"
**Cause:** Pre-flight runs before ImageMagick installation (by design)
**Expected:** This should show as ℹ️ INFO, not ❌ ERROR
**Solution:** If showing as error, workflow step order is wrong

```bash
# Check workflow order:
1. Pre-flight check (ImageMagick optional)
2. Install ImageMagick
3. Generate screenshots
```

#### ❌ "Simulator not found: iPhone 16 Pro Max"
**Cause:** GitHub runner doesn't have required simulator
**Diagnosis:**
```bash
# In failing run, check logs for:
xcrun simctl list devices available | grep "iPhone 16 Pro Max"
```

**Solution:**
- Check if Xcode version changed on runner
- Update simulator names in workflow if needed
- File GitHub issue if simulator missing from `macos-14` image

#### ❌ "Ruby/Bundler not found"
**Cause:** Ruby setup step failed or wrong version
**Solution:**
```yaml
# Verify in workflow:
- uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.2'
    bundler-cache: true
```

---

### 2. Simulator Boot Failures

#### ❌ "Simulator failed to boot"
**Cause:** Simulator already in use, corrupted, or insufficient resources
**Diagnosis:** Check logs for:
```
Unable to boot device in current state: Booted
Unable to lookup in current state: Shutdown
```

**Solution 1: Clean simulator state**
```bash
xcrun simctl shutdown all
xcrun simctl delete unavailable
xcrun simctl erase all
```

**Solution 2: Force delete and recreate** (CI does this automatically)

#### ⚠️ "Multiple devices matched"
**Cause:** Duplicate Watch simulators (common issue)
**Diagnosis:**
```bash
xcrun simctl list devices | grep "Apple Watch Series 10 (46mm)"
# If multiple entries → duplicates exist
```

**Solution:** The `cleanup-watch-duplicates.sh` script handles this automatically
**Manual fix:**
```bash
.github/scripts/cleanup-watch-duplicates.sh
```

---

### 3. Screenshot Generation Timeouts

This was the #1 cause of 140 failures.

#### ❌ Test timeout at 300s or 600s
**Symptoms:**
```
⚠️  App launch attempt 1/2 failed, retrying...
⚠️  App launch attempt 2/2 failed, retrying...
❌ App failed to launch after 2 attempts
```

**Root causes found:**
1. **Simulator not pre-booted** (adds 30-60s)
2. **Too many launch retries** (3×60s = 180s consumed)
3. **iPad simulator slower** (2-4x slower than iPhone in CI)

**Current fixes (already applied):**
- ✅ Pre-boot simulators with `xcrun simctl bootstatus -b`
- ✅ Reduce retries from 3 to 2
- ✅ Increase test timeouts to 300s/600s
- ✅ iPad gets 120min job timeout (was 90min)

**If still timing out:**
```bash
# Check actual duration in logs:
Generate iPad screenshots: Duration: XX minutes

# If close to timeout:
1. Check if simulator pre-boot succeeded
2. Look for excessive retry attempts
3. Consider increasing timeout further (rare)
```

#### ❌ "Failed to terminate" error (iPad specific)
**Symptoms:**
```
Failed to terminate com.apple.test.ListAll-Runner
Domain: FBSOpenApplicationServiceErrorDomain
```

**Cause:** App process from previous test still running
**Solution:** Retry logic handles this automatically (max 2 attempts)
**If persists:** File Xcode bug report, this is a simulator issue

---

### 4. Screenshot Validation Failures

#### ❌ "Wrong dimensions"
**Symptoms:**
```
❌ Wrong dimensions: iPhone-01-Welcome.png
   Expected: 1290x2796 (iPhone 16 Pro Max)
   Actual: 2048x2732
```

**Causes:**
1. **Wrong device generated screenshot** (iPad dimensions on iPhone)
2. **Normalization failed** (ImageMagick error)
3. **Artifacts mixed up** (download step error)

**Diagnosis:**
```bash
# Check artifact contents in logs:
Download iPhone screenshots
Download iPad screenshots

# Verify no mixing:
ls -lR fastlane/screenshots_compat/
```

**Solution:**
- Ensure jobs complete fully (no early termination)
- Check ImageMagick version: `magick --version` should be 7.x
- Verify normalization logs for errors

#### ❌ "No PNG screenshots found"
**Cause:** Screenshot generation failed silently
**Diagnosis:** Check for:
```
✅ iPhone screenshot generation failed: No screenshots captured
```

**Solution:**
- Check if tests actually ran: `xcodebuild test` command output
- Verify `snapshot()` calls in test code
- Check for test crashes before screenshot capture

#### ⚠️ "Possibly blank (white/black)"
**Cause:** Screenshot captured before UI loaded
**Diagnosis:**
```bash
# Check brightness values in logs:
⚠️ Possibly blank (white): test.png (brightness: 0.99)
⚠️ Possibly blank (black): test.png (brightness: 0.01)
```

**Solution:**
- Increase UI wait time in test code
- Add `waitForExistence` calls before `snapshot()`
- Check if app actually launched successfully

---

### 5. ImageMagick Issues

#### ❌ "ImageMagick conversion failed"
**Symptoms:**
```
❌ ImageMagick conversion failed for screenshot.png (exit code: 1)
```

**Causes:**
1. Out of memory (rare)
2. Corrupt input file
3. Wrong ImageMagick version

**Diagnosis:**
```bash
# Check ImageMagick version:
magick --version | head -1
# Should be: Version: ImageMagick 7.x.x

# Test manually:
magick convert input.png -resize 1290x2796! output.png
```

**Solution:**
```bash
# Reinstall ImageMagick:
brew reinstall imagemagick

# Verify commands available:
command -v magick identify convert
```

---

### 6. Upload to App Store Connect Failures

#### ❌ "Authentication failed"
**Cause:** API credentials expired or invalid
**Solution:**
1. Verify secrets are set in GitHub:
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_BASE64`
2. Regenerate API key if expired (90 days max)
3. Re-encode to base64: `base64 -i AuthKey_XXX.p8 | pbcopy`

#### ❌ "Screenshot upload failed"
**Cause:** Screenshots don't meet App Store requirements
**Check:** Manual validation should have caught this earlier
**Solution:**
```bash
# Run validation locally:
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad
.github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch
```

---

## 🔧 Debugging Commands

### Check CI Environment
```bash
# Xcode version
xcodebuild -version

# Available simulators
xcrun simctl list devices available

# Ruby/Bundler
ruby --version
bundle --version

# ImageMagick
magick --version
identify --version
```

### Simulator Debugging
```bash
# Boot simulator manually
UDID=$(xcrun simctl list devices | grep "iPhone 16 Pro Max" | grep -oE '[0-9A-F-]{36}' | head -1)
xcrun simctl bootstatus "$UDID" -b

# Check simulator state
xcrun simctl list devices "$UDID"

# Delete all unavailable
xcrun simctl delete unavailable
```

### Screenshot Debugging
```bash
# Check dimensions
identify -format '%wx%h' screenshot.png

# Check file size
ls -lh screenshot.png

# Check brightness (0.0=black, 1.0=white)
magick screenshot.png -colorspace Gray -format "%[fx:mean]" info:
```

### Test Locally
```bash
# Run pre-flight check
.github/scripts/preflight-check.sh

# Find simulator
.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS

# Validate screenshots
.github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone

# Run screenshot generation
bundle exec fastlane ios screenshots_iphone
```

---

## 📊 Performance Benchmarks

Based on successful run (after fixes):

| Job | Duration | Timeout | Buffer | Status |
|-----|----------|---------|--------|--------|
| iPhone | 20-24 min | 90 min | 4x | ✅ Healthy |
| iPad | 18-20 min | 120 min | 6x | ✅ Healthy |
| Watch | 16 min | 90 min | 5.6x | ✅ Healthy |

**Historical context:**
- Before pre-boot: iPad took 84 minutes (93% of timeout) ⚠️
- After pre-boot: iPad takes 20 minutes (17% of timeout) ✅
- **76% improvement** from pre-boot optimization

---

## 🚀 Quick Fixes Checklist

When pipeline fails, try these in order:

### 1. Check Pre-flight Logs (2 minutes)
- [ ] All simulators available?
- [ ] Ruby/Bundler working?
- [ ] Enough disk space?

### 2. Check Simulator Boot (5 minutes)
- [ ] Pre-boot succeeded?
- [ ] Any "Failed to terminate" errors?
- [ ] Duplicate Watch simulators?

### 3. Check Screenshot Generation (10 minutes)
- [ ] Tests actually ran?
- [ ] Any timeout errors?
- [ ] Screenshot count matches expected?

### 4. Check Screenshot Validation (2 minutes)
- [ ] All dimensions correct?
- [ ] No blank screenshots?
- [ ] File sizes reasonable (>10KB)?

### 5. Check Upload (2 minutes)
- [ ] Credentials valid?
- [ ] Network connectivity?
- [ ] App Store Connect reachable?

---

## 🆘 When to Escalate

Contact maintainer if:
- ❌ Pre-flight fails with all checks passing
- ❌ Simulator boots but tests never start
- ❌ Screenshots validate but upload fails
- ❌ Issue persists after 3+ retry attempts
- ❌ New error not covered in this guide

Include in escalation:
1. Link to failing GitHub Actions run
2. Relevant error messages from logs
3. What you've already tried
4. Environment differences (if local testing works)

---

## 📚 Related Documentation

- **Scripts:** `.github/scripts/README.md`
- **Workflow:** `.github/workflows/prepare-appstore.yml`
- **Test Code:** `ListAll/ListAllUITests/ListAllUITests_Simple.swift`
- **Fastfile:** `fastlane/Fastfile`

---

## 🔄 Change Log

### 2025-11-25 - Major Reliability Improvements
- ✅ Fixed 140-attempt failure streak
- ✅ Added pre-flight validation
- ✅ Implemented screenshot dimension validation
- ✅ Fixed simulator discovery issues
- ✅ Added comprehensive error handling
- ✅ 76% performance improvement (pre-boot optimization)

### Common Issues Resolved
- ❌ Shell injection vulnerabilities → ✅ Environment variables
- ❌ Silent failures → ✅ Explicit validation
- ❌ Timeout at 180s → ✅ Increased to 300s/600s
- ❌ iPad slow (84 min) → ✅ Pre-boot (20 min)
- ❌ Screenshot failures masked → ✅ Fail-fast validation

---

**Last Updated:** 2025-11-25
**Maintainer:** @chmc
**Pipeline Status:** ✅ Stable (post-hardening)

🤖 This guide was created by analyzing 140 failed pipeline attempts and documenting the fixes.
