# Quality Arsenal: Break Everything

## Context

ListAll has ~1,750 tests and weekly mutation testing, but no sanitizers, no code coverage, and several real tests skipped in CI with documented root causes sitting unfixed. The actual recurring bugs are race conditions (`perform` vs `performAndWait`), sync ordering, and concurrency timing — not memory safety or input validation. This plan targets those real bug patterns.

**CI model:** Push directly to `main`. CI triggers on every push. Expensive jobs run weekly.

---

## Phase 1: Compiler Strictness + Static Analyzer (every push, ~1 hour)

### 1A. Warnings as errors in CI
- Add `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` to all 3 `xcodebuild` commands in CI only
- First: run local build on all 3 schemes, fix any existing warnings
- Add comment in ci.yml: "Note: enabling Swift 6 strict concurrency will require disabling this temporarily"

### 1B. Xcode Static Analyzer
- Add `RUN_CLANG_STATIC_ANALYZER=YES` to CI build steps
- Free, runs during existing build — no additional job or time

**Files:** `.github/workflows/ci.yml`, any source files with warnings

---

## Phase 2: Code Coverage Reporting (every push, ~2 hours)

### 2A. Enable coverage
- Add `-enableCodeCoverage YES` to all 3 `xcodebuild test` commands

### 2B. Coverage extraction script: `scripts/extract-coverage.sh`
- Extract using `xcrun xccov view --report --json TestResults.xcresult` (note: path argument required)
- Filter to project source files, write markdown to `$GITHUB_STEP_SUMMARY`
- No hard threshold — visibility only

### 2C. Post-test step in each platform job
- iOS: `TestResults.xcresult`, macOS: `TestResults-Mac.xcresult`, watchOS: `TestResults-Watch.xcresult`
- Upload coverage JSON as artifact alongside existing xcresult

**Files:** `.github/workflows/ci.yml`, `scripts/extract-coverage.sh` (new)

---

## Phase 3: Fix Skipped CI Tests (~3 hours)

These are real tests being wasted. Root causes are documented in `documentation/learnings/`.

### 3A. `testRemoteChangeThreadSafety` (CoreDataRemoteChangeTests)
- **Root cause:** Timer debouncing + CI run loop timing (see `documentation/learnings/coredata-notification-test-ci-flakiness.md`)
- **Fix:** Longer timeout + `RunLoop.current.run()` pumping

### 3B. `testBatchedReloadPerformance` (SyncBugFixTests)
- **Root cause:** Hard 5-second threshold too tight for CI runners
- **Fix:** Increase to 15s or use XCTest `measure {}` with baselines

### 3C. `testDataRepositoryHandlesSyncNotification` (ServicesTests)
- **Root cause:** 0.1s async delay with 1.0s timeout
- **Fix:** Increase timeout, use `expectation(forNotification:)`

### 3D. `testReorder_modifiedAtPersistsToDatabase` (ListOrderingTests)
- **Root cause:** Timestamp comparison with 0.1s sleep
- **Fix:** Increase sleep or use date comparison with tolerance

### 3E. 5 SuggestionService tests
- `testGetSuggestionsWithLimit`, `testGetSuggestionsWithoutLimit`, `testSuggestionDetailsIncluded`, `testSuggestionServiceIndividualItems`, `testSuggestionServiceRecentItems`
- **Root cause:** Unknown — needs actual investigation
- **Action:** Run locally, diagnose failure, fix or document why they must stay skipped

### 3F. Update ci.yml
- Remove `-skip-testing:` lines for each fixed test

**Files:** `.github/workflows/ci.yml`, test source files as needed, `documentation/learnings/` (update if new findings)

---

## Phase 4: Stress & Concurrency Tests (every push, ~3 hours)

New test files in existing targets. Fast (<5s each), in-memory stores.

### 4A. `ListAllTests/StressTests.swift` — Volume + rapid state changes
- 500+ items in one list → verify sorting and export work
- 500 lists → reorder first-to-last → verify no duplicate order numbers
- Rapid add/delete/reorder cycle (200 iterations) on `MainViewModel` → verify clean state
- Test `validateDataIntegrity(lists:)` and `validateListBusinessRules(_:existingLists:)` (complex logic, NOT covered in existing UtilsTests)
- Order number collision recovery: manually corrupt order numbers → call reorder → verify recovery
- Use `@Suite(.serialized)` to prevent cross-test contamination

### 4B. `ListAllTests/ConcurrencyTests.swift` — Race condition reproduction
**These target the #1 actual bug pattern: `perform` vs `performAndWait` races.**
- Two background contexts saving to same entity simultaneously → verify no `NSMergeConflict` crash
- Notification handler firing on background queue while main thread reads `@Published` property → verify thread safety
- Debounce timer + concurrent save → verify timer doesn't fire stale data
- `synchronizeLists(_:)` called from two threads simultaneously → verify data integrity

### 4C. `ListAllTests/CoreDataRecoveryTests.swift` — Recoverable error paths
**Not fault injection (singleton prevents it). Instead, test the recovery code directly.**
- Test `deleteAndRecreateStore()` path (CoreDataManager.swift lines 217-221) — verify store is recreated successfully
- Test error codes that trigger recovery: 134110, 256, 134060, 513, 4
- Test that after store recreation, data operations work normally
- Note: the `fatalError` path (line 224) is intentionally untestable — it's Apple's recommended crash-on-corruption pattern

### 4D. `ListAllWatch Watch AppTests/WatchSyncChaosTests.swift`
- 256KB size limit enforcement (100 items × 990-char descriptions)
- Empty sync from Watch side
- Sync ordering: Watch sends update while phone is mid-save

### 4E. `ListAllMacTests/MacStressTests.swift`
- Same stress patterns (4A) adapted for macOS TestHelpers

**Files:**
- `ListAll/ListAllTests/StressTests.swift` (new)
- `ListAll/ListAllTests/ConcurrencyTests.swift` (new)
- `ListAll/ListAllTests/CoreDataRecoveryTests.swift` (new)
- `ListAll/ListAllWatch Watch AppTests/WatchSyncChaosTests.swift` (new)
- `ListAll/ListAllMacTests/MacStressTests.swift` (new)
- `ListAll/ListAll.xcodeproj/project.pbxproj` (register new files in test targets)

---

## Phase 5: Weekly Quality Workflow (~3 hours)

### 5A. Thread Sanitizer — validate locally first
- Run `xcodebuild test -enableThreadSanitizer YES` locally on macOS scheme
- If clean: add weekly job for macOS (no simulator overhead)
- If noisy with actor false positives: defer until Swift 6 migration
- Do NOT skip `testRemoteChangeThreadSafety` (should be fixed in Phase 3)

### 5B. Address Sanitizer for stress tests
- Run Phase 4 stress tests with `-enableAddressSanitizer YES`
- Catches use-after-free in Core Data ObjC bridging (cheap insurance, even if no historical bugs)
- Cannot combine with TSan — separate job

### 5C. Periphery dead code detection
- `.periphery.yml` — MUST list all 3 schemes, build ALL 3 for indexing
- Validate locally first before adding to CI
- `retain_obj_c_accessible: true`

### 5D. `quality.yml` workflow
```
quality.yml (schedule: Sunday 8am UTC, workflow_dispatch)
  ├── asan-stress     [macos-14, 45 min]
  ├── tsan-macos      [macos-14, 60 min]  (only if local validation passes)
  └── periphery       [macos-14, 30 min]
```

**Files:** `.periphery.yml` (new), `.github/workflows/quality.yml` (new)

---

## Implementation Order

1. Phase 1 — warnings-as-errors + static analyzer (instant wins)
2. Phase 3 — fix skipped tests (highest value: real tests being wasted)
3. Phase 4 — stress + concurrency tests (targets actual bug patterns)
4. Phase 2 — coverage reporting (visibility)
5. Phase 5 — weekly quality workflow (TSan/ASan/Periphery)

---

## Verification

- Push to main → warnings-as-errors passes, static analyzer runs, coverage in job summary, all new tests pass, previously-skipped tests now run
- `quality.yml` manual dispatch → ASan passes, Periphery report uploads
- TSan: validate locally first, decide whether to add to weekly
