# App Store Prepare Pipeline Reliability Plan

**Created:** 2025-11-27
**Branch:** feature/pipeline-hardening-all
**Status:** Active Implementation
**Agents Used:** Apple Development Expert, Critical Reviewer, Integration Specialist, Pipeline Specialist, Shell Script Specialist, Testing Specialist

---

## Executive Summary

After comprehensive analysis by 6 specialized agents, we identified the root cause of 9 consecutive pipeline failures and created this reliability improvement plan.

### Root Cause (CRITICAL)
**Location:** `.github/scripts/cleanup-simulators-robust.sh`
**Issue:** `set -euo pipefail` combined with `grep` commands that return exit code 1 when finding no matches
**Impact:** 100% failure rate across all 5 parallel jobs

### Current Status
- **Run 19739152062:** In progress, iPhone Screenshots (fi) already COMPLETED
- **Fix Applied:** Commit 2f77f5e added `|| true` and `continue-on-error: true`
- **Prognosis:** Current run likely to succeed

---

## Phase 1: Immediate Fixes (Apply Now)

### 1.1 Shell Script Pipefail Issues (CRITICAL)

**File:** `.github/scripts/cleanup-simulators-robust.sh`

**Problem Lines:**
```bash
# Line 53, 65, 103, 116 - grep in pipeline with pipefail
HUNG_SIMS=$(ps aux | grep "Simulator\.app" | grep -v grep | wc -l | xargs || true)

# Line 110 - while read with broken || true placement
echo "$SIMCTL_LIST_OUTPUT" | grep "Booted" | grep -oE '\([A-F0-9-]{36}\)' | tr -d '()' | while read -r udid || true; do
```

**Root Issue:**
- `set -euo pipefail` causes ANY failed command in a pipeline to fail the script
- `grep` returns exit code 1 when it finds NO matches (not an error, just empty result)
- Fresh CI runners have no Simulator.app running, so grep finds nothing → exit 1 → script fails
- The `|| true` must wrap the ENTIRE pipeline, not just parts of it

**Fixes:**

```bash
# Line 53 - Use grep -c with proper fallback
HUNG_SIMS=$(pgrep -f "Simulator\.app/Contents/MacOS/Simulator" 2>/dev/null | wc -l || echo "0")

# Lines 103, 116, 178, 180, 182 - Use grep -c with fallback
BOOTED=$(echo "$SIMCTL_LIST_OUTPUT" | grep -c "Booted" 2>/dev/null || echo "0")

# Line 110 - Fix while read loop
if echo "$SIMCTL_LIST_OUTPUT" | grep -q "Booted" 2>/dev/null; then
  echo "$SIMCTL_LIST_OUTPUT" | grep "Booted" | grep -oE '\([A-F0-9-]{36}\)' | tr -d '()' | while read -r udid; do
    log_timestamp "  Shutting down $udid..."
    run_with_timeout 10 xcrun simctl shutdown "$udid" 2>&1 || log_timestamp "  Failed to shutdown $udid"
  done
fi
```

**Alternative (Simpler):** Remove `set -o pipefail` from diagnostic scripts entirely:
```bash
# Line 3 - Change from:
set -euo pipefail
# To:
set -eu  # pipefail causes more problems than it solves in cleanup scripts
```

### 1.2 Workflow Protection (Already Applied)

**File:** `.github/workflows/prepare-appstore.yml`

```yaml
# Line 103-104 - Already added
- name: Clean simulator state
  run: .github/scripts/cleanup-simulators-robust.sh
  continue-on-error: true  # Don't fail job if cleanup has issues
```

---

## Phase 2: Medium Priority Improvements (This Week)

### 2.1 Move Cleanup Inside Retry Wrapper

**Problem:** Cleanup runs BEFORE nick-fields/retry wrapper, so failures block retries.

**Current:**
```yaml
- name: Clean simulator state
  run: .github/scripts/cleanup-simulators-robust.sh
  continue-on-error: true

- name: Generate iPhone screenshots
  uses: nick-fields/retry@v3
  with:
    command: bundle exec fastlane ...
```

**Better:**
```yaml
- name: Generate iPhone screenshots
  uses: nick-fields/retry@v3
  with:
    on_retry_command: .github/scripts/cleanup-simulators-robust.sh || true
    command: |
      .github/scripts/cleanup-simulators-robust.sh || true
      bundle exec fastlane ...
```

### 2.2 Reduce Excessive Timeouts

**Current Timeouts (Overkill):**
| Job | Job Timeout | Per-Attempt | Actual Need |
|-----|-------------|-------------|-------------|
| iPhone | 90 min | 40 min | ~10 min |
| iPad | 120 min | 50 min | ~15 min |
| Watch | 110 min | 50 min | ~25 min |

**Recommended:**
| Job | Job Timeout | Per-Attempt | Buffer |
|-----|-------------|-------------|--------|
| iPhone | 45 min | 20 min | 2x actual |
| iPad | 60 min | 25 min | 2x actual |
| Watch | 70 min | 30 min | 2x actual |

**Rationale:** Faster failure feedback, reduced CI costs, 2x buffer is sufficient.

### 2.3 Add Early Validation

**Add after line 230 in prepare-appstore.yml:**
```yaml
# Early failure detection (5 minutes instead of 40)
EARLY_CHECK_TIME=300  # 5 minutes
sleep $EARLY_CHECK_TIME
if [ $(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l) -eq 0 ]; then
  echo "::error::No screenshots after 5 minutes - failing fast"
  exit 1
fi
```

### 2.4 Simplify Background Monitor

**Remove the kill logic that can kill working processes:**

```yaml
# Current (dangerous):
if [ $ELAPSED -eq 900 ] && [ $CURRENT_COUNT -eq 0 ]; then
  pkill -9 -f "fastlane" || true  # CAN KILL WORKING PROCESS
  exit 1
fi

# Better (diagnostic only):
if [ $ELAPSED -eq 900 ] && [ $CURRENT_COUNT -eq 0 ]; then
  echo "::warning::No screenshots after 15 minutes - check simulator health"
  # Let nick-fields/retry handle timeout, don't kill manually
fi
```

---

## Phase 3: Long-term Improvements (Next Sprint)

### 3.1 UI Test Reliability Enhancements

**File:** `ListAll/ListAllUITests/ListAllUITests_Simple.swift`

**Add settling time after waitForUIReady():**
```swift
// After line 320 and 387
Thread.sleep(forTimeInterval: 0.3)  // Allow animations to fully settle
```

**Fix non-deterministic timestamps in test data:**
```swift
// UITestDataService.swift - Use fixed base date
private static let baseDate = Date(timeIntervalSince1970: 1700000000)  // Fixed date

// Replace all Date() with baseDate-relative dates
let creationDate = baseDate.addingTimeInterval(-Double(index * 86400))
```

**Add screenshot verification:**
```swift
snapshot("01_Welcome", timeWaitingForIdle: 0)
// Verify screenshot was captured
let screenshotDir = ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS_PATH"] ?? ""
let expectedPath = "\(screenshotDir)/01_Welcome.png"
// Log for debugging (can't assert in snapshot helper)
print("Screenshot expected at: \(expectedPath)")
```

### 3.2 Circuit Breaker Pattern

**Add to workflow:**
```yaml
- name: Verify runner health
  run: |
    START=$(date +%s)
    xcrun simctl boot "iPhone 16 Pro Max" 2>/dev/null || true
    BOOT_TIME=$(($(date +%s) - START))
    if [ $BOOT_TIME -gt 60 ]; then
      echo "::error::Runner is slow (boot took ${BOOT_TIME}s) - request new runner"
      exit 1
    fi
    xcrun simctl shutdown all 2>/dev/null || true
  timeout-minutes: 3
```

### 3.3 Incremental Progress Preservation

**Upload partial results on failure:**
```yaml
- name: Upload partial screenshots on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: partial-screenshots-${{ matrix.locale }}
    path: fastlane/screenshots_compat/
    if-no-files-found: ignore
```

### 3.4 Structured Logging

**Create `.github/scripts/log-helper.sh`:**
```bash
#!/usr/bin/env bash
log_phase() { echo "::group::$1"; }
log_end() { echo "::endgroup::"; }
log_metric() { echo "::notice title=$1::$2"; }
log_warn() { echo "::warning::$1"; }
log_error() { echo "::error::$1"; }
```

---

## Anti-Patterns Identified (Do NOT Repeat)

| Anti-Pattern | Why It's Bad | Current Status |
|--------------|--------------|----------------|
| `set -euo pipefail` + `grep` | grep returns 1 on no match | Being fixed |
| Kill logic in background monitor | Can kill working processes | Should remove |
| 4 layers of timeouts | Complexity without benefit | Should simplify |
| Cleanup BEFORE retry wrapper | Failures bypass retry | Should move |
| `|| true` inside `$(...)` | Doesn't protect pipeline | Fixed |
| `ps aux \| grep \| grep -v grep` | Unreliable, use `pgrep` | Should fix |

---

## Success Metrics

### Current (Before Fixes)
- Success Rate: ~0% (9 consecutive failures)
- Average Run Time: N/A (all timeout)
- CI Cost per Run: ~$15-20 (wasted)

### Target (After Phase 1)
- Success Rate: 60-70%
- Average Run Time: 45-60 minutes
- CI Cost per Run: ~$8-10

### Target (After Phase 2)
- Success Rate: 85-90%
- Average Run Time: 30-45 minutes
- CI Cost per Run: ~$5-7

### Target (After Phase 3)
- Success Rate: 95%+
- Average Run Time: 25-35 minutes
- CI Cost per Run: ~$4-5

---

## Files to Modify

### Phase 1 (Critical)
- [ ] `.github/scripts/cleanup-simulators-robust.sh` - Fix grep/pipefail issues

### Phase 2 (High Priority)
- [ ] `.github/workflows/prepare-appstore.yml` - Move cleanup inside retry, reduce timeouts
- [ ] `.github/scripts/cleanup-simulators-robust.sh` - Remove `set -o pipefail`

### Phase 3 (Medium Priority)
- [ ] `ListAll/ListAllUITests/ListAllUITests_Simple.swift` - Add settling time
- [ ] `ListAll/ListAll/Services/UITestDataService.swift` - Fix timestamps
- [ ] `.github/scripts/log-helper.sh` - Create structured logging

---

## Testing the Fixes

### Local Testing
```bash
# 1. Syntax check
bash -n .github/scripts/cleanup-simulators-robust.sh

# 2. Simulate fresh CI (no simulator running)
pkill -9 Simulator 2>/dev/null || true
bash -euo pipefail .github/scripts/cleanup-simulators-robust.sh

# 3. Full pipeline test
.github/scripts/test-pipeline-locally.sh --quick
```

### CI Testing
1. Apply fixes to cleanup-simulators-robust.sh
2. Commit and push to feature branch
3. Trigger workflow: `gh workflow run prepare-appstore.yml -f version=1.0.0`
4. Monitor: `gh run watch`

---

## Agent Analysis Summary

| Agent | Key Finding | Recommendation |
|-------|-------------|----------------|
| **Apple Dev Expert** | Pipeline architecture is sound, pipefail bug was root cause | Current run should succeed |
| **Critical Reviewer** | Over-engineering created fragility; simplify aggressively | Remove 766 lines of defensive code |
| **Integration Specialist** | Cleanup script failure cascades to all 5 jobs | Move cleanup inside retry wrapper |
| **Pipeline Specialist** | Timeouts are 4-8x actual need | Reduce to 2x actual for faster feedback |
| **Shell Script Specialist** | 8 grep-related bugs in cleanup script | Use `grep -c` with fallbacks |
| **Testing Specialist** | Race conditions in waitForUIReady() | Add 0.3s settling time |

---

## Monitoring Current Run

```bash
# Watch current run
gh run watch 19739152062

# Check job status
gh run view 19739152062 --json jobs --jq '.jobs[] | "\(.name): \(.status) \(.conclusion)"'

# Download logs on failure
gh run view 19739152062 --log-failed
```

---

## References

- `.github/workflows/TROUBLESHOOTING.md` - 22 common failure scenarios
- `.github/COMPREHENSIVE_RELIABILITY_AUDIT.md` - Previous audit findings
- `IMPLEMENTATION_SUMMARY.md` - Recent hardening changes
- `.github/scripts/README.md` - Script documentation
