# Test Execution Best Practices for ListAll

## Executive Summary

This document provides shell/xcodebuild best practices for stable test execution in the ListAll project, based on analysis of current CI/CD workflows, Fastlane configuration, and shell scripts.

**Current Status:**
- iOS + watchOS test execution via `xcodebuild`
- Tests run on `macos-14` runners with Xcode 16.1
- Fastlane provides test lanes but CI uses direct xcodebuild
- No parallel testing configured
- Builds use `clean build` before testing
- Simulator management handled in screenshot generation scripts

---

## 1. Simulator Management Best Practices

### Current Approach
The project has simulator cleanup in `/Users/aleksi/source/ListAllApp/.github/scripts/generate-screenshots-local.sh`:

```bash
cleanup_simulators() {
    xcrun simctl shutdown all 2>/dev/null || true
    sleep 2
    xcrun simctl delete unavailable 2>/dev/null || true
    pkill -9 -f "Simulator.app" 2>/dev/null || true
    pkill -9 -f "simctl" 2>/dev/null || true
}
```

### Issues with Current Approach

1. **Hard-coded sleep**: `sleep 2` is non-deterministic
2. **Force kill with -9**: Can corrupt simulator state
3. **No verification**: Doesn't check if cleanup succeeded
4. **Missing cleanup**: Doesn't clear simulator caches

### Recommended Simulator Management Script

Create `/Users/aleksi/source/ListAllApp/.github/scripts/cleanup-simulators.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# Simulator Cleanup Script
# =============================================================================
# Purpose: Safely clean up simulator state before test execution
# Usage:   ./cleanup-simulators.sh [--aggressive]
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_SIMULATOR_CLEANUP_FAILED=1

# Timeouts
readonly SHUTDOWN_TIMEOUT=30
readonly BOOT_VERIFICATION_TIMEOUT=10

# Logging functions
log_info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log_warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }

# Gracefully shutdown simulators with timeout
shutdown_simulators() {
    log_info "Shutting down all simulators..."

    if ! xcrun simctl shutdown all 2>/dev/null; then
        log_warn "Shutdown command returned non-zero, continuing..."
    fi

    # Wait for shutdown with timeout
    local elapsed=0
    while [[ ${elapsed} -lt ${SHUTDOWN_TIMEOUT} ]]; do
        local booted_count
        booted_count=$(xcrun simctl list devices 2>/dev/null | grep -c "Booted" || true)

        if [[ ${booted_count} -eq 0 ]]; then
            log_info "All simulators shut down successfully"
            return 0
        fi

        sleep 1
        ((elapsed++)) || true
    done

    log_warn "Timeout waiting for graceful shutdown after ${SHUTDOWN_TIMEOUT}s"
    return 1
}

# Force terminate simulator processes (last resort)
force_terminate_simulators() {
    log_warn "Force terminating simulator processes..."

    # First try SIGTERM (allows cleanup)
    pkill -TERM -f "Simulator.app" 2>/dev/null || true
    pkill -TERM -f "com.apple.CoreSimulator.CoreSimulatorService" 2>/dev/null || true

    sleep 2

    # Then SIGKILL if still running
    if pgrep -f "Simulator.app" >/dev/null 2>&1; then
        log_warn "Simulators still running, using SIGKILL..."
        pkill -KILL -f "Simulator.app" 2>/dev/null || true
        pkill -KILL -f "com.apple.CoreSimulator.CoreSimulatorService" 2>/dev/null || true
        sleep 1
    fi

    log_info "Simulator processes terminated"
}

# Clean up unavailable/invalid simulators
cleanup_unavailable_simulators() {
    log_info "Removing unavailable simulators..."

    if xcrun simctl delete unavailable 2>/dev/null; then
        log_info "Unavailable simulators removed"
    else
        log_warn "No unavailable simulators to remove (or command failed)"
    fi
}

# Clear simulator caches and data
cleanup_simulator_data() {
    local aggressive="${1:-false}"

    if [[ "${aggressive}" == "true" ]]; then
        log_info "Clearing simulator device caches..."

        # Clear CoreSimulator caches (safe when all simulators are shut down)
        local sim_cache_dir="${HOME}/Library/Developer/CoreSimulator/Caches"
        if [[ -d "${sim_cache_dir}" ]]; then
            rm -rf "${sim_cache_dir:?}"/* 2>/dev/null || true
            log_info "Simulator caches cleared"
        fi
    fi
}

# Verify simulators are in clean state
verify_simulator_state() {
    log_info "Verifying simulator state..."

    # Check no simulators are booted
    local booted_count
    booted_count=$(xcrun simctl list devices 2>/dev/null | grep -c "Booted" || true)

    if [[ ${booted_count} -gt 0 ]]; then
        log_error "Found ${booted_count} booted simulator(s)"
        xcrun simctl list devices | grep "Booted" || true
        return 1
    fi

    # Check no simulator processes running
    if pgrep -f "Simulator.app" >/dev/null 2>&1; then
        log_error "Simulator processes still running"
        return 1
    fi

    log_info "Simulator state verified: all shut down"
    return 0
}

# Main cleanup orchestration
main() {
    local aggressive=false

    if [[ "${1:-}" == "--aggressive" ]]; then
        aggressive=true
        log_info "Running aggressive cleanup (clears caches)"
    fi

    log_info "Starting simulator cleanup..."

    # Step 1: Graceful shutdown
    if ! shutdown_simulators; then
        # Step 2: Force termination if graceful failed
        force_terminate_simulators
    fi

    # Step 3: Clean up invalid simulators
    cleanup_unavailable_simulators

    # Step 4: Clear caches if aggressive mode
    cleanup_simulator_data "${aggressive}"

    # Step 5: Verify clean state
    if ! verify_simulator_state; then
        log_error "Simulator cleanup verification failed"
        exit ${EXIT_SIMULATOR_CLEANUP_FAILED}
    fi

    log_info "Simulator cleanup completed successfully"
    exit ${EXIT_SUCCESS}
}

main "$@"
```

**Key Improvements:**
1. ✅ Deterministic timeout instead of fixed sleep
2. ✅ Graceful shutdown (SIGTERM) before force kill (SIGKILL)
3. ✅ Verification of cleanup success
4. ✅ Optional cache clearing for aggressive cleanup
5. ✅ Proper error handling and exit codes

---

## 2. Build and Test Separation

### Current CI Approach

```yaml
# .github/workflows/ci.yml (current)
- name: Build iOS app
  run: |
    cd ListAll
    xcodebuild clean build \
      -project ListAll.xcodeproj \
      -scheme ListAll \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'

- name: Run iOS tests
  run: |
    cd ListAll
    xcodebuild test \
      -project ListAll.xcodeproj \
      -scheme ListAll \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
```

### Issues

1. **Separate clean + build**: Runs clean twice (build step + test step)
2. **No build reuse**: Test step rebuilds everything
3. **Inefficient**: Duplicates compilation work

### Recommended Approach

**Option A: Build-for-Testing + Test-Without-Building (Fastest)**

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCHEME="ListAll"
readonly PROJECT="ListAll.xcodeproj"
readonly DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=latest"
readonly DERIVED_DATA_PATH="./build"

# Build once for testing
xcodebuild build-for-testing \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee build.log

# Run tests without rebuilding
xcodebuild test-without-building \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -resultBundlePath TestResults.xcresult \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee test.log
```

**Option B: Single Test Command (Simpler)**

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCHEME="ListAll"
readonly PROJECT="ListAll.xcodeproj"
readonly DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=latest"
readonly DERIVED_DATA_PATH="./build"

# Single command: clean, build, and test
xcodebuild clean test \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -resultBundlePath TestResults.xcresult \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee test.log
```

**Recommendation:** Use Option A (build-for-testing) for CI to enable:
- Artifact caching of compiled binaries
- Separate build/test failure analysis
- Parallel test execution across multiple destinations

---

## 3. Derived Data Management

### Current Issues

1. **No explicit derived data path**: Uses Xcode default location
2. **Cache strategy unclear**: CI caches `~/Library/Developer/Xcode/DerivedData` but path varies
3. **No cleanup between runs**: Can accumulate stale build artifacts

### Recommended Strategy

**For CI (GitHub Actions):**

```yaml
- name: Set Derived Data Path
  run: echo "DERIVED_DATA_PATH=${{ github.workspace }}/DerivedData" >> $GITHUB_ENV

- name: Cache Derived Data
  uses: actions/cache@v4
  with:
    path: ${{ env.DERIVED_DATA_PATH }}
    key: ${{ runner.os }}-derived-data-${{ hashFiles('**/ListAll.xcodeproj/project.pbxproj', '**/Package.resolved') }}
    restore-keys: |
      ${{ runner.os }}-derived-data-

- name: Clean Stale Build Data
  run: |
    if [[ -d "$DERIVED_DATA_PATH" ]]; then
      # Remove module cache (can become corrupted)
      rm -rf "$DERIVED_DATA_PATH/ModuleCache.noindex"
      # Remove index data (safe to rebuild)
      rm -rf "$DERIVED_DATA_PATH/Index.noindex"
    fi

- name: Build for Testing
  run: |
    cd ListAll
    xcodebuild build-for-testing \
      -project ListAll.xcodeproj \
      -scheme ListAll \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -configuration Debug
```

**For Local Development:**

Create `/Users/aleksi/source/ListAllApp/.github/scripts/clean-build-cache.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Clean Build Cache Script
# =============================================================================
# Purpose: Clean Xcode build artifacts and derived data
# Usage:   ./clean-build-cache.sh [--all|--module-cache|--index]
# =============================================================================

readonly DERIVED_DATA_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"
readonly PROJECT_NAME="ListAll"

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }

clean_module_cache() {
    log_info "Cleaning module cache..."
    find "${DERIVED_DATA_ROOT}" -name "ModuleCache.noindex" -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Module cache cleaned"
}

clean_index() {
    log_info "Cleaning index data..."
    find "${DERIVED_DATA_ROOT}" -name "Index.noindex" -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Index data cleaned"
}

clean_all_derived_data() {
    log_info "Removing all derived data for ${PROJECT_NAME}..."
    find "${DERIVED_DATA_ROOT}" -name "${PROJECT_NAME}-*" -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "All derived data removed"
}

main() {
    local mode="${1:-module-cache}"

    case "${mode}" in
        --all)
            clean_all_derived_data
            ;;
        --module-cache)
            clean_module_cache
            ;;
        --index)
            clean_index
            ;;
        *)
            echo "Usage: $0 [--all|--module-cache|--index]"
            echo ""
            echo "Options:"
            echo "  --all            Remove all derived data (nuclear option)"
            echo "  --module-cache   Remove module cache only (safe, fixes most issues)"
            echo "  --index          Remove index data only (safe, rebuilds on next build)"
            exit 1
            ;;
    esac
}

main "$@"
```

---

## 4. Parallel Testing Configuration

### Current State

- No parallel testing enabled
- Tests run sequentially
- Single simulator per test run

### Recommended Parallel Testing Setup

**Configure in Scheme (Manual):**
1. Open `ListAll.xcodeproj` in Xcode
2. Edit Scheme → Test → Options
3. Check "Execute in parallel on Simulator"
4. Set "Maximum parallel test targets": 2-4

**Or via xcodebuild flags:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Parallel testing with explicit configuration
xcodebuild test \
    -project ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -parallel-testing-enabled YES \
    -maximum-parallel-testing-workers 2 \
    -resultBundlePath TestResults.xcresult
```

**For Multiple Destinations (Advanced):**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test across multiple simulators in parallel
xcodebuild test \
    -project ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -destination 'platform=iOS Simulator,name=iPhone 16 Plus' \
    -parallel-testing-enabled YES \
    -maximum-parallel-testing-workers auto \
    -resultBundlePath TestResults.xcresult
```

**Caveats:**
- ⚠️ Parallel testing requires thread-safe test code
- ⚠️ Can expose race conditions in tests
- ⚠️ May increase memory usage
- ✅ Significantly faster for large test suites

**Recommendation for ListAll:**
- Start with `-maximum-parallel-testing-workers 2`
- Monitor for flaky tests
- Increase workers if tests are stable

---

## 5. Error Handling in Test Scripts

### Current Issues in Fastlane

```ruby
# fastlane/Fastfile (current)
lane :test do
    sh "cd ../ListAll && xcodebuild test ... || true"
end
```

**Problem:** `|| true` masks all failures

### Recommended Test Script Template

Create `/Users/aleksi/source/ListAllApp/.github/scripts/run-tests.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# Test Execution Script
# =============================================================================
# Purpose: Run xcodebuild tests with proper error handling and reporting
# Usage:   ./run-tests.sh [--scheme SCHEME] [--platform PLATFORM]
# =============================================================================

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_BUILD_FAILED=1
readonly EXIT_TESTS_FAILED=2
readonly EXIT_INVALID_ARGS=3

# Defaults
SCHEME="ListAll"
PLATFORM="iOS"
DEVICE_NAME="iPhone 16 Pro"
RESULT_BUNDLE_PATH="TestResults.xcresult"
DERIVED_DATA_PATH="./build"

# Logging
log_info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }
log_success() { echo "[SUCCESS] $(date '+%H:%M:%S') $*"; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scheme)
                SCHEME="$2"
                shift 2
                ;;
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            *)
                log_error "Unknown argument: $1"
                exit ${EXIT_INVALID_ARGS}
                ;;
        esac
    done
}

# Set destination based on platform
set_destination() {
    case "${PLATFORM}" in
        iOS)
            DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=latest"
            ;;
        watchOS)
            DESTINATION="platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest"
            ;;
        macOS)
            DESTINATION="platform=macOS"
            ;;
        *)
            log_error "Invalid platform: ${PLATFORM}"
            exit ${EXIT_INVALID_ARGS}
            ;;
    esac
}

# Build for testing
build_for_testing() {
    log_info "Building ${SCHEME} for testing..."

    if ! xcodebuild build-for-testing \
        -project ListAll/ListAll.xcodeproj \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee build.log; then

        log_error "Build failed"
        return ${EXIT_BUILD_FAILED}
    fi

    log_success "Build completed"
    return ${EXIT_SUCCESS}
}

# Run tests
run_tests() {
    log_info "Running tests for ${SCHEME}..."

    local test_exit_code=0

    if ! xcodebuild test-without-building \
        -project ListAll/ListAll.xcodeproj \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -resultBundlePath "${RESULT_BUNDLE_PATH}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee test.log; then

        test_exit_code=$?
        log_error "Tests failed with exit code ${test_exit_code}"
    fi

    return ${test_exit_code}
}

# Extract test results summary
summarize_results() {
    if [[ ! -d "${RESULT_BUNDLE_PATH}" ]]; then
        log_error "Result bundle not found: ${RESULT_BUNDLE_PATH}"
        return
    fi

    log_info "Test Results Summary:"

    # Use xcrun xcresulttool to parse results
    if command -v xcrun >/dev/null 2>&1; then
        xcrun xcresulttool get --format human "${RESULT_BUNDLE_PATH}" 2>/dev/null || true
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?

    log_info "Cleaning up..."

    # Shutdown simulators if iOS/watchOS
    if [[ "${PLATFORM}" != "macOS" ]]; then
        xcrun simctl shutdown all 2>/dev/null || true
    fi

    exit ${exit_code}
}

trap cleanup EXIT ERR INT TERM

# Main execution
main() {
    parse_args "$@"
    set_destination

    log_info "Starting test execution"
    log_info "Scheme: ${SCHEME}"
    log_info "Platform: ${PLATFORM}"
    log_info "Destination: ${DESTINATION}"

    # Build
    if ! build_for_testing; then
        exit ${EXIT_BUILD_FAILED}
    fi

    # Test
    local test_result=0
    if ! run_tests; then
        test_result=${EXIT_TESTS_FAILED}
    fi

    # Summarize
    summarize_results

    if [[ ${test_result} -eq 0 ]]; then
        log_success "All tests passed"
        exit ${EXIT_SUCCESS}
    else
        log_error "Tests failed"
        exit ${EXIT_TESTS_FAILED}
    fi
}

main "$@"
```

**Key Features:**
1. ✅ Separate build and test phases
2. ✅ Proper exit code handling (not masked)
3. ✅ Log capture to files
4. ✅ Result bundle generation
5. ✅ Cleanup on exit/error
6. ✅ Configurable via command-line arguments

---

## 6. Updated CI Workflow

### Recommended `.github/workflows/ci.yml` Changes

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    name: Build and Test
    runs-on: macos-14

    strategy:
      matrix:
        platform:
          - scheme: ListAll
            destination: 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
            name: iOS
          - scheme: "ListAllWatch Watch App"
            destination: 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest'
            name: watchOS
      fail-fast: false  # Continue testing other platforms if one fails

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_16.1.app/Contents/Developer

    - name: Show Xcode version
      run: xcodebuild -version

    - name: Set Derived Data Path
      run: echo "DERIVED_DATA_PATH=${{ github.workspace }}/DerivedData" >> $GITHUB_ENV

    - name: Cache Derived Data
      uses: actions/cache@v4
      with:
        path: ${{ env.DERIVED_DATA_PATH }}
        key: ${{ runner.os }}-${{ matrix.name }}-derived-data-${{ hashFiles('**/ListAll.xcodeproj/project.pbxproj') }}
        restore-keys: |
          ${{ runner.os }}-${{ matrix.name }}-derived-data-

    - name: Cache SPM packages
      uses: actions/cache@v4
      with:
        path: |
          ~/.swiftpm
          ${{ env.DERIVED_DATA_PATH }}/SourcePackages
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-

    - name: Resolve SPM dependencies
      working-directory: ListAll
      run: |
        xcodebuild -resolvePackageDependencies \
          -project ListAll.xcodeproj \
          -scheme "${{ matrix.scheme }}"

    - name: Clean Stale Build Artifacts
      run: |
        if [[ -d "$DERIVED_DATA_PATH" ]]; then
          rm -rf "$DERIVED_DATA_PATH/ModuleCache.noindex" || true
          rm -rf "$DERIVED_DATA_PATH/Index.noindex" || true
        fi

    - name: Clean Up Simulators
      if: matrix.name != 'macOS'
      run: |
        xcrun simctl shutdown all 2>/dev/null || true
        sleep 2
        xcrun simctl delete unavailable 2>/dev/null || true
        pkill -TERM -f "Simulator.app" 2>/dev/null || true
        sleep 1

    - name: Build for Testing
      working-directory: ListAll
      run: |
        set -o pipefail
        xcodebuild build-for-testing \
          -project ListAll.xcodeproj \
          -scheme "${{ matrix.scheme }}" \
          -destination '${{ matrix.destination }}' \
          -derivedDataPath "$DERIVED_DATA_PATH" \
          -configuration Debug \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO \
          | tee build-${{ matrix.name }}.log

    - name: Run Tests
      working-directory: ListAll
      run: |
        set -o pipefail
        xcodebuild test-without-building \
          -project ListAll.xcodeproj \
          -scheme "${{ matrix.scheme }}" \
          -destination '${{ matrix.destination }}' \
          -derivedDataPath "$DERIVED_DATA_PATH" \
          -resultBundlePath TestResults-${{ matrix.name }}.xcresult \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO \
          | tee test-${{ matrix.name }}.log

    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: ${{ matrix.name }}-test-results
        path: ListAll/TestResults-${{ matrix.name }}.xcresult
        retention-days: 30

    - name: Upload Build Logs
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: ${{ matrix.name }}-build-logs
        path: |
          ListAll/build-${{ matrix.name }}.log
          ListAll/test-${{ matrix.name }}.log
        retention-days: 7

    - name: Upload Crash Logs
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: ${{ matrix.name }}-crash-logs
        path: |
          ~/Library/Logs/DiagnosticReports
          ${{ env.DERIVED_DATA_PATH }}/Logs
        retention-days: 7
```

**Key Improvements:**
1. ✅ Uses matrix strategy for iOS + watchOS testing
2. ✅ Explicit derived data path (consistent caching)
3. ✅ Clean stale build artifacts before build
4. ✅ Simulator cleanup before tests
5. ✅ Separate build-for-testing and test-without-building
6. ✅ Captures build/test logs separately
7. ✅ Uses `set -o pipefail` to catch pipe failures
8. ✅ `fail-fast: false` to test all platforms even if one fails

---

## 7. Updated Fastfile Test Lane

### Recommended Changes to `/Users/aleksi/source/ListAllApp/fastlane/Fastfile`

Replace the current `test` lane:

```ruby
desc "Run tests (mirrors CI behavior with proper error handling)"
lane :test do
  # iOS Tests
  ios_test_result = run_ios_tests

  # watchOS Tests
  watch_test_result = run_watch_tests

  # Fail the lane if any tests failed
  if ios_test_result != 0 || watch_test_result != 0
    UI.user_error!("Tests failed: iOS exit code #{ios_test_result}, watchOS exit code #{watch_test_result}")
  end

  UI.success("All tests passed!")
end

desc "Run iOS tests"
private_lane :run_ios_tests do
  UI.message("Running iOS tests...")

  result = sh(
    "cd ../ListAll && xcodebuild test " \
    "-project ListAll.xcodeproj " \
    "-scheme ListAll " \
    "-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' " \
    "-resultBundlePath ../fastlane/test_output/iOS-TestResults.xcresult " \
    "-derivedDataPath ../fastlane/build " \
    "-configuration Debug " \
    "CODE_SIGN_IDENTITY=\"\" " \
    "CODE_SIGNING_REQUIRED=NO " \
    "CODE_SIGNING_ALLOWED=NO",
    error_callback: lambda { |result|
      UI.error("iOS tests failed with exit code #{result}")
      return result
    }
  )

  return result
end

desc "Run watchOS tests"
private_lane :run_watch_tests do
  UI.message("Running watchOS tests...")

  result = sh(
    "cd ../ListAll && xcodebuild test " \
    "-project ListAll.xcodeproj " \
    "-scheme 'ListAllWatch Watch App' " \
    "-destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=latest' " \
    "-resultBundlePath ../fastlane/test_output/watchOS-TestResults.xcresult " \
    "-derivedDataPath ../fastlane/build " \
    "-configuration Debug " \
    "CODE_SIGN_IDENTITY=\"\" " \
    "CODE_SIGNING_REQUIRED=NO " \
    "CODE_SIGNING_ALLOWED=NO",
    error_callback: lambda { |result|
      UI.error("watchOS tests failed with exit code #{result}")
      return result
    }
  )

  return result
end
```

**Key Changes:**
1. ❌ Removed `|| true` (no longer masks failures)
2. ✅ Separate iOS and watchOS test lanes
3. ✅ Proper exit code handling
4. ✅ Explicit derived data path
5. ✅ Result bundle per platform

---

## 8. Command Reference

### Recommended xcodebuild Test Commands

**Basic Test (Clean + Build + Test):**
```bash
xcodebuild clean test \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -resultBundlePath TestResults.xcresult
```

**Build + Test Separately (Recommended for CI):**
```bash
# Step 1: Build for testing
xcodebuild build-for-testing \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -derivedDataPath ./build

# Step 2: Run tests without rebuilding
xcodebuild test-without-building \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -derivedDataPath ./build \
    -resultBundlePath TestResults.xcresult
```

**Parallel Testing:**
```bash
xcodebuild test \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -parallel-testing-enabled YES \
    -maximum-parallel-testing-workers 2 \
    -resultBundlePath TestResults.xcresult
```

**Run Specific Test Class:**
```bash
xcodebuild test \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -only-testing:ListAllTests/DataRepositoryTests \
    -resultBundlePath TestResults.xcresult
```

**Skip Specific Test:**
```bash
xcodebuild test \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -skip-testing:ListAllTests/FlakyTests \
    -resultBundlePath TestResults.xcresult
```

**Test with Retries (for flaky tests):**
```bash
xcodebuild test \
    -project ListAll/ListAll.xcodeproj \
    -scheme ListAll \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
    -test-iterations 3 \
    -retry-tests-on-failure \
    -resultBundlePath TestResults.xcresult
```

---

## 9. Quick Wins for Immediate Implementation

### Priority 1: High Impact, Low Effort

1. **Add explicit derived data path to CI**
   - File: `.github/workflows/ci.yml`
   - Change: Add `-derivedDataPath` flag
   - Impact: Consistent cache behavior
   - Effort: 5 minutes

2. **Separate build and test steps in CI**
   - File: `.github/workflows/ci.yml`
   - Change: Use `build-for-testing` + `test-without-building`
   - Impact: Better error diagnostics, faster reruns
   - Effort: 10 minutes

3. **Remove `|| true` from Fastfile test lane**
   - File: `fastlane/Fastfile`
   - Change: Remove masking, add proper error handling
   - Impact: Expose hidden test failures
   - Effort: 5 minutes

### Priority 2: Medium Impact, Medium Effort

4. **Create cleanup-simulators.sh script**
   - File: `.github/scripts/cleanup-simulators.sh`
   - Change: Add deterministic simulator cleanup
   - Impact: Reduce flaky test failures
   - Effort: 20 minutes

5. **Add simulator cleanup to CI workflow**
   - File: `.github/workflows/ci.yml`
   - Change: Run cleanup before tests
   - Impact: More reliable test execution
   - Effort: 5 minutes

6. **Clean stale build artifacts in CI**
   - File: `.github/workflows/ci.yml`
   - Change: Remove ModuleCache.noindex before build
   - Impact: Prevent cache corruption issues
   - Effort: 5 minutes

### Priority 3: Lower Priority Enhancements

7. **Enable parallel testing**
   - File: Xcode scheme + CI workflow
   - Change: Add parallel testing flags
   - Impact: Faster test execution (if stable)
   - Effort: 15 minutes + testing

8. **Create comprehensive run-tests.sh script**
   - File: `.github/scripts/run-tests.sh`
   - Change: Centralize test execution logic
   - Impact: Consistent test execution across environments
   - Effort: 30 minutes

---

## 10. Testing the Changes

### Validation Checklist

After implementing changes, verify:

1. **Build succeeds:**
   ```bash
   cd /Users/aleksi/source/ListAllApp/ListAll
   xcodebuild build-for-testing \
       -project ListAll.xcodeproj \
       -scheme ListAll \
       -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
       -derivedDataPath ./build
   ```

2. **Tests run:**
   ```bash
   xcodebuild test-without-building \
       -project ListAll.xcodeproj \
       -scheme ListAll \
       -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
       -derivedDataPath ./build \
       -resultBundlePath TestResults.xcresult
   ```

3. **Fastlane test lane works:**
   ```bash
   cd /Users/aleksi/source/ListAllApp
   bundle exec fastlane test
   ```

4. **CI workflow passes:**
   - Push to feature branch
   - Verify GitHub Actions workflow completes
   - Check artifact uploads

---

## 11. Shell Script Best Practices Summary

Based on analysis of existing scripts and industry standards:

### ✅ Current Good Practices in ListAll Scripts

1. **Strict mode:** `set -euo pipefail` (used in most scripts)
2. **Script directory detection:** `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
3. **Readonly variables:** `readonly SCRIPT_DIR`
4. **Logging functions:** Consistent `log_info`, `log_error` pattern
5. **Exit codes:** Defined constants like `EXIT_SUCCESS=0`
6. **Comprehensive tests:** `/Users/aleksi/source/ListAllApp/.github/scripts/tests/test-generate-screenshots-local.sh` is exemplary

### ⚠️ Areas for Improvement

1. **Hardcoded sleeps:** Replace with timeout loops (see simulator cleanup)
2. **Force kill usage:** Use SIGTERM before SIGKILL
3. **Error masking:** Remove `|| true` except where genuinely needed
4. **Validation:** Add verification steps after critical operations
5. **Quoting:** Always quote variables: `"${var}"` not `$var`

### 📋 Shell Script Template

For new scripts in the project:

```bash
#!/usr/bin/env bash
# =============================================================================
# Script Name
# =============================================================================
# Purpose: Brief description
# Usage:   ./script.sh [OPTIONS] ARGS
# =============================================================================

set -euo pipefail

# Script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Logging
log_info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log_warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }
log_success() { echo "[SUCCESS] $(date '+%H:%M:%S') $*"; }

# Cleanup on exit
cleanup() {
    local exit_code=$?
    # Add cleanup logic here
    exit "${exit_code}"
}
trap cleanup EXIT ERR INT TERM

# Main function
main() {
    # Script logic here
    log_info "Starting..."

    # Example validation
    if [[ $# -lt 1 ]]; then
        log_error "Missing required argument"
        echo "Usage: $0 <argument>"
        exit ${EXIT_FAILURE}
    fi

    log_success "Completed"
}

main "$@"
```

---

## Appendix A: File Locations

**Scripts to create:**
- `/Users/aleksi/source/ListAllApp/.github/scripts/cleanup-simulators.sh`
- `/Users/aleksi/source/ListAllApp/.github/scripts/run-tests.sh`
- `/Users/aleksi/source/ListAllApp/.github/scripts/clean-build-cache.sh`

**Files to modify:**
- `/Users/aleksi/source/ListAllApp/.github/workflows/ci.yml`
- `/Users/aleksi/source/ListAllApp/fastlane/Fastfile`
- `/Users/aleksi/source/ListAllApp/.github/scripts/generate-screenshots-local.sh` (optional: replace sleep with timeout)

**Documentation:**
- This file: `/Users/aleksi/source/ListAllApp/documentation/test-execution-best-practices.md`

---

## Appendix B: ShellCheck Recommendations

Run ShellCheck on all scripts before committing:

```bash
find /Users/aleksi/source/ListAllApp/.github/scripts -name "*.sh" -exec shellcheck {} \;
```

Common issues to fix:
- SC2086: Quote variables to prevent word splitting
- SC2164: Use `cd ... || exit` in case cd fails
- SC2155: Declare and assign separately to avoid masking return values
- SC2046: Quote command substitutions to prevent word splitting

---

**End of Document**
