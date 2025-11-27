# Timeout Integration Architecture - Visual Diagram

This diagram shows how timeout values flow through the system and interact across layers.

## Full System Integration Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB ACTIONS WORKFLOW                            │
│                    (.github/workflows/prepare-appstore.yml)                  │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │   iPhone Job    │  │    iPad Job     │  │   Watch Job     │            │
│  │                 │  │                 │  │                 │            │
│  │  timeout: 90min │  │  timeout: 120min│  │  timeout: 110min│            │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │            │
│  │  │Retry Loop │  │  │  │Retry Loop │  │  │  │Retry Loop │  │            │
│  │  │40min × 2  │  │  │  │50min × 2  │  │  │  │50min × 2  │  │            │
│  │  └─────┬─────┘  │  │  └─────┬─────┘  │  │  └─────┬─────┘  │            │
│  └────────┼────────┘  └────────┼────────┘  └────────┼────────┘            │
│           │                    │                     │                      │
│           └────────────────────┴─────────────────────┘                      │
│                                │                                            │
│                        env: SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT="60"  │
└───────────────────────────────┼─────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FASTLANE LAYER                                 │
│                            (fastlane/Fastfile)                               │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ENV['SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT'] ||= default_timeout  │  │
│  │                                                                       │  │
│  │ CI mode: 60s (from GitHub Actions)                                   │  │
│  │ Local mode: 30s (fallback)                                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ xcargs Configuration (passed to xcodebuild)                          │  │
│  │                                                                       │  │
│  │ iPhone/iPad:                                                          │  │
│  │   -default-test-execution-time-allowance 480                         │  │
│  │   -maximum-test-execution-time-allowance 900                         │  │
│  │                                                                       │  │
│  │ Watch:                                                                │  │
│  │   -default-test-execution-time-allowance 300                         │  │
│  │   -maximum-test-execution-time-allowance 600                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  snapshot() function call ─────────────────────────────────────────────────┤
└───────────────────────────────────────────────────────────────────────┬─────┘
                                                                        │
                                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SNAPFILE LAYER                                 │
│                            (fastlane/Snapfile)                               │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Configuration Delegation to Fastfile                                 │  │
│  │                                                                       │  │
│  │ ✅ number_of_retries(0)        - No Fastlane-level retries           │  │
│  │ ✅ xcargs REMOVED               - Prevents conflict with Fastfile    │  │
│  │ ✅ concurrent_simulators(false) - Sequential device execution        │  │
│  │ ✅ erase_simulator(false)       - Fast locale switching              │  │
│  │ ✅ reinstall_app(true)          - Clean state per locale             │  │
│  │ ✅ localize_simulator(true)     - Set system language                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  All timeout control delegated to Fastfile xcargs ─────────────────────────┤
└───────────────────────────────────────────────────────────────────────┬─────┘
                                                                        │
                                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            XCODEBUILD LAYER                                 │
│                         (Apple's Test Runner)                               │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Test Timeout Enforcement                                             │  │
│  │                                                                       │  │
│  │ iPhone/iPad Tests:                                                    │  │
│  │   Soft timeout: 480s (8 minutes) - warning threshold                 │  │
│  │   Hard timeout: 900s (15 minutes) - kills test                       │  │
│  │                                                                       │  │
│  │ Watch Tests:                                                          │  │
│  │   Soft timeout: 300s (5 minutes)                                     │  │
│  │   Hard timeout: 600s (10 minutes)                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Spawns test process ──────────────────────────────────────────────────────┤
└───────────────────────────────────────────────────────────────────────┬─────┘
                                                                        │
                                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          UI TEST CODE LAYER                                 │
│                  (ListAll/ListAllUITests/ListAllUITests_Simple.swift)        │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Internal Timeout Budget Tracking                                     │  │
│  │                                                                       │  │
│  │ Total test budget: 880s (900s xcodebuild max - 20s safety margin)    │  │
│  │                                                                       │  │
│  │ Budget allocation:                                                    │  │
│  │   ├─ App launch retry 1: 45s (iPhone) / 60s (iPad)                   │  │
│  │   ├─ App launch retry 2: 45s (iPhone) / 60s (iPad)                   │  │
│  │   ├─ UI ready wait:      15s                                         │  │
│  │   ├─ Data load wait:     15s                                         │  │
│  │   ├─ Screenshot capture: ~10s                                        │  │
│  │   └─ Overhead/margin:    ~700s remaining                             │  │
│  │                                                                       │  │
│  │ Launch timeout:                                                       │  │
│  │   iPhone: 45s                                                         │  │
│  │   iPad:   60s                                                         │  │
│  │                                                                       │  │
│  │ Element timeout: 15s                                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Interacts with simulator ─────────────────────────────────────────────────┤
└───────────────────────────────────────────────────────────────────────┬─────┘
                                                                        │
                                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SIMULATOR LAYER                                   │
│                        (iOS/iPadOS/watchOS Simulator)                        │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Boot Timeout: SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT                │  │
│  │                                                                       │  │
│  │ CI mode:    60s max wait for "Booted" state                          │  │
│  │ Local mode: 30s max wait                                             │  │
│  │                                                                       │  │
│  │ Boot sequence:                                                        │  │
│  │   1. CoreSimulatorService starts simulator                           │  │
│  │   2. Simulator.app launches (if GUI needed)                          │  │
│  │   3. Boot sequence (kernel, SpringBoard, etc.)                       │  │
│  │   4. State transitions: Shutdown → Booting → Booted                  │  │
│  │                                                                       │  │
│  │ If timeout exceeded:                                                  │  │
│  │   → Fastlane snapshot fails fast                                     │  │
│  │   → GitHub Actions retry kicks in                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Timeout Interaction Matrix

| Event | Layer 1 (GHA) | Layer 2 (Retry) | Layer 3 (xcodebuild) | Layer 4 (Sim Boot) | Layer 5 (UI Test) |
|-------|---------------|-----------------|----------------------|--------------------|-------------------|
| **Simulator boot timeout** | - | - | - | ⚠️ Triggers | - |
| → Fastlane fails | - | ⚠️ Catches | - | - | - |
| → Retry recovery runs | ✅ Executes | - | - | - | - |
| → Retry attempt 2 | - | ✅ Starts | - | - | - |
| | | | | | |
| **App launch timeout** | - | - | - | - | ⚠️ Triggers |
| → Internal retry (2x) | - | - | - | - | ✅ Retries |
| → If both fail, XCTSkip | - | - | ⚠️ Catches | - | - |
| → Test method fails | - | ⚠️ Catches | - | - | - |
| → Retry recovery runs | ✅ Executes | - | - | - | - |
| | | | | | |
| **Test method timeout** | - | - | ⚠️ Triggers | - | - |
| → xcodebuild kills test | - | ⚠️ Catches | - | - | - |
| → Fastlane reports failure | - | - | - | - | - |
| → Retry recovery runs | ✅ Executes | - | - | - | - |
| | | | | | |
| **Retry action timeout** | - | ⚠️ Triggers | - | - | - |
| → Kills Fastlane process | - | ✅ Enforces | - | - | - |
| → Retry attempt 2 | - | ✅ Starts | - | - | - |
| | | | | | |
| **Job timeout** | ⚠️ Triggers | - | - | - | - |
| → Kills entire job | ✅ Enforces | - | - | - | - |
| → No retry (terminal) | ❌ Fails | - | - | - | - |

**Legend**:
- ⚠️ = Timeout triggered at this layer
- ✅ = Recovery/retry mechanism executes
- ❌ = Terminal failure (no recovery)
- `-` = Layer not involved in this scenario

---

## Data Flow: Environment Variable Propagation

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1. GitHub Actions YAML (prepare-appstore.yml:175,352,514)           │
│    env:                                                              │
│      SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT: "60"                  │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 2. Bash Shell Environment (inherited by child processes)            │
│    $ echo $SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT                  │
│    60                                                                │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 3. bundle exec fastlane ios screenshots_iphone_locale                │
│    (Fastlane Ruby process inherits environment)                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 4. Fastfile (fastlane/Fastfile:86)                                   │
│    ENV['SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT'] ||= default_timeout│
│                                                                       │
│    CI mode detected: ENV['CI'] = "true"                              │
│    default_timeout = '60'                                             │
│    ENV var already set to "60" → uses "60" (||= doesn't override)   │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 5. snapshot() function (Fastlane gem internal)                       │
│    Reads ENV['SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT']            │
│    Uses 60s as max wait time for simulator boot                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ 6. xcrun simctl boot <UDID>                                          │
│    Fastlane polls simulator state every 1s for up to 60s             │
│    Checks: "Shutdown" → "Booting" → "Booted"                         │
│                                                                       │
│    If booted within 60s: ✅ Continue                                 │
│    If timeout exceeded:  ❌ Raise error, retry action catches it     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Failure Cascade Analysis

### Scenario 1: Simulator Boot Hangs (CoreSimulatorService Deadlock)

```
Time  Layer               Event                              Action
────────────────────────────────────────────────────────────────────────
0s    Simulator           Boot process starts                -
30s   Simulator           Still in "Booting" state           (polling...)
60s   Simulator (L4)      ⚠️ BOOT TIMEOUT EXCEEDED           -
60s   Fastlane            snapshot() raises boot error       Propagates ↑
60s   Retry Action (L2)   Catches error                      Trigger recovery
61s   Recovery Script     Kill simulator processes           Cleanup
76s   Recovery Script     Wait for stabilization (15s)       -
91s   Retry Action (L2)   ✅ START ATTEMPT 2                 -
91s   Simulator           Fresh boot attempt                 -
...   ...                 (repeat if needed)                 -
```

**Total time to recovery**: ~31 seconds
**Retry attempts remaining**: 1 (of 2)
**Budget consumed**: 91s / 2400s (40min iPhone retry timeout)

---

### Scenario 2: App Launch Timeout (iPad, First Locale)

```
Time  Layer               Event                              Action
────────────────────────────────────────────────────────────────────────
0s    Simulator           Booted successfully (30s)          -
30s   UI Test (L5)        app.launch() called                -
45s   UI Test (L5)        Still launching...                 (waiting...)
90s   UI Test (L5)        ⚠️ LAUNCH TIMEOUT (60s iPad)       -
90s   UI Test             Internal retry (attempt 1/2)       Sleep 5s
95s   UI Test             app.launch() retry                 -
155s  UI Test (L5)        ⚠️ LAUNCH TIMEOUT (60s again)      -
155s  UI Test             throw XCTSkip                      Test skipped
155s  xcodebuild (L3)     Test marked as skipped             Propagates ↑
155s  Fastlane            Lane fails (no screenshots)        Propagates ↑
155s  Retry Action (L2)   Catches failure                    Trigger recovery
156s  Recovery Script     Full simulator cleanup             Cleanup
186s  Retry Action (L2)   ✅ START ATTEMPT 2                 -
```

**Total time to recovery**: ~156 seconds
**Retry attempts remaining**: 1 (of 2)
**Budget consumed**: 186s / 3000s (50min iPad retry timeout)

---

### Scenario 3: Test Method Exceeds xcodebuild Timeout (Rare)

```
Time  Layer               Event                              Action
────────────────────────────────────────────────────────────────────────
0s    UI Test             testScreenshots01_WelcomeScreen()  Starts
120s  UI Test             App launched (2 retries)           -
135s  UI Test             UI ready wait                      -
150s  UI Test             Screenshot captured                Complete ✅
150s  UI Test             testScreenshots02_MainFlow()       Starts
...   ...                 (something hangs - simulator deadlock?)
870s  UI Test             Still hanging...                   -
880s  UI Test             checkTimeoutBudget() warns         Low budget
900s  xcodebuild (L3)     ⚠️ MAXIMUM TIMEOUT (900s)          -
900s  xcodebuild          Kills test process (SIGKILL)       Test killed
900s  Fastlane            Lane fails                         Propagates ↑
900s  Retry Action (L2)   Catches failure                    Trigger recovery
901s  Recovery Script     Full cleanup + 15s wait            Cleanup
916s  Retry Action (L2)   ✅ START ATTEMPT 2                 -
```

**Total time to recovery**: ~916 seconds (15.3 minutes)
**Retry attempts remaining**: 1 (of 2)
**Budget consumed**: 916s / 3000s (50min iPad retry timeout)

---

## Configuration Consistency Checklist

Use this checklist when modifying timeout values:

### ✅ Pre-Change Verification

- [ ] Identify which layer the timeout belongs to (L1-L5)
- [ ] Check if timeout is set in multiple locations
- [ ] Verify current integration point dependencies
- [ ] Read this document's integration matrix

### ✅ Change Implementation

- [ ] Update timeout value in primary location
- [ ] Check for related timeouts that need adjustment
- [ ] Maintain proper timeout hierarchy (outer > inner)
- [ ] Update comments explaining the timeout value

### ✅ Cross-Layer Validation

- [ ] Layer 1 (GHA job) > Layer 2 (retry) timeout
  - iPhone: `90 min > (2 × 40 min = 80 min)` ✓
  - iPad: `120 min > (2 × 50 min = 100 min)` ✓
  - Watch: `110 min > (2 × 50 min = 100 min)` ✓

- [ ] Layer 2 (retry) > Layer 3 (xcodebuild) worst case
  - iPhone: `40 min > 900s × N tests` ✓
  - iPad: `50 min > 900s × N tests` ✓

- [ ] Layer 3 (xcodebuild max) > Layer 5 (test budget)
  - `900s > 880s` ✓ (20s safety margin)

- [ ] Layer 5 (test budget) > test operations
  - `880s > (2×60s launch + 2×15s wait + overhead)` ✓

- [ ] Layer 4 (sim boot) is reasonable
  - `60s` allows ~30s actual boot time + polling overhead ✓

### ✅ Documentation Updates

- [ ] Update this diagram if architecture changes
- [ ] Update INTEGRATION_ANALYSIS_REPORT.md with new values
- [ ] Update inline code comments
- [ ] Update troubleshooting guide if failure modes change

### ✅ Testing

- [ ] Test locally with new timeout values
- [ ] Verify no timeout conflicts in logs
- [ ] Check CI run completes within new limits
- [ ] Verify retry recovery still works

---

## Quick Reference: Current Timeout Values

| Component | iPhone | iPad | Watch | File Location |
|-----------|--------|------|-------|---------------|
| **Layer 1: GHA Job** | 90 min | 120 min | 110 min | `.github/workflows/prepare-appstore.yml:29,206,382` |
| **Layer 2: Retry Action** | 40 min | 50 min | 50 min | `.github/workflows/prepare-appstore.yml:121,298,460` |
| **Layer 3: xcodebuild Default** | 480s | 480s | 300s | `fastlane/Fastfile:159,1111,3632` |
| **Layer 3: xcodebuild Max** | 900s | 900s | 600s | `fastlane/Fastfile:159,1111,3632` |
| **Layer 4: Sim Boot (CI)** | 60s | 60s | 60s | `.github/workflows/prepare-appstore.yml:175,352,514` |
| **Layer 4: Sim Boot (Local)** | 30s | 30s | 30s | `fastlane/Fastfile:85` |
| **Layer 5: Test Budget** | 880s | 880s | - | `ListAll/ListAllUITests/ListAllUITests_Simple.swift:70` |
| **Layer 5: Launch Timeout** | 45s | 60s | 45s | `ListAll/ListAllUITests/ListAllUITests_Simple.swift:18` |
| **Layer 5: Element Timeout** | 15s | 15s | - | `ListAll/ListAllUITests/ListAllUITests_Simple.swift:25` |

**Last Updated**: 2025-11-27 (commit 3ae24eb)

---

## Integration Points Map

```
File                                    Sets/Reads                          Used By
─────────────────────────────────────────────────────────────────────────────────────
prepare-appstore.yml (L29)             Sets: timeout-minutes: 90           GitHub Actions
prepare-appstore.yml (L206)            Sets: timeout-minutes: 120          GitHub Actions
prepare-appstore.yml (L382)            Sets: timeout-minutes: 110          GitHub Actions
prepare-appstore.yml (L121,298,460)    Sets: timeout_minutes: 40/50/50     nick-fields/retry
prepare-appstore.yml (L175,352,514)    Sets: SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT="60"
                                                                            ↓
Fastfile (L86)                         Reads: ENV['SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT']
Fastfile (L85)                         Sets: default_timeout = ENV['CI'] ? '60' : '30'
Fastfile (L159,1111,3632)              Sets: -default-test-execution-time-allowance 480/300
Fastfile (L159,1111,3632)              Sets: -maximum-test-execution-time-allowance 900/600
                                                                            ↓
xcodebuild (Apple)                     Reads: xcargs from snapshot() call
xcodebuild (Apple)                     Enforces: test execution time allowances
                                                                            ↓
ListAllUITests_Simple.swift (L70)      Sets: test budget = 880s (900s - 20s)
ListAllUITests_Simple.swift (L18)      Sets: launchTimeout = 45s/60s
ListAllUITests_Simple.swift (L25)      Sets: elementTimeout = 15s
```

---

**Diagram Maintained By**: Integration Specialist Agent
**Purpose**: Visual reference for timeout integration debugging
**Related Documents**: `.github/INTEGRATION_ANALYSIS_REPORT.md`, `.github/workflows/TROUBLESHOOTING.md`
