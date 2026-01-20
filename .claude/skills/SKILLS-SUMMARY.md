---
title: Skills Summary
date: 2025-01-20
type: index
purpose: Quick skill selection reference for LLM agents
usage: Scan triggers/symptoms to find relevant skills, then load full SKILL.md
tags:
  - skills
  - index
  - quick-reference
  - agent-selection
---

# Skills Summary

Quick reference for skill selection. Scan triggers to find relevant skills, then read full `SKILL.md` for details.

## Skill Selection Matrix

| Skill | Load When | Key Patterns | Key Antipatterns |
|-------|-----------|--------------|------------------|
| `swift-swiftui` | Writing Swift code | async/await, @Observable, actors | force unwrap (!), callback hell |
| `fastlane` | Screenshots, App Store | erase_simulator(false), only_testing | erase_simulator(true), no retries |
| `xctest` | Unit/UI tests | AAA pattern, waitForExistence | sleep(), force unwrap in tests |
| `simulator-management` | Simulator issues | shutdown all before runs | pre-booting, no cleanup |
| `swiftui-patterns` | List/ForEach bugs | direct @Published binding | computed property as data source |
| `coredata-sync` | Sync issues, race conditions | mutation flag, async save | fetch immediately after save |
| `code-review` | PR review, critique | specific actionable feedback | vague criticism without alternatives |
| `watch-connectivity` | Watch sync | check reachability, transferUserInfo | fire-and-forget sendMessage |
| `github-actions` | CI failures | always() artifacts, timeout-minutes | no timeout, success-only artifacts |
| `bash-scripting` | Shell scripts | set -euo pipefail, quoted vars | unquoted vars, missing error handling |
| `test-isolation` | Permission dialogs | TestHelpers factory methods | direct ViewModel() instantiation |

---

## swift-swiftui

**Path**: `.claude/skills/swift-swiftui/SKILL.md`

**Triggers**:
- Writing or reviewing Swift code
- SwiftUI view implementation
- State management decisions
- Concurrency/async code

**Symptoms Addressed**:
- Nested callback hell
- Thread safety issues
- Massive view files
- Random crashes from force unwraps

**Patterns**:
- Use `@Observable` macro (iOS 17+) for simple state
- Use `async/await` over completion handlers
- Use `actor` for thread-safe shared state
- Use `@Environment` for dependency injection
- Keep views small, extract subviews
- Handle errors explicitly with Result or throws

**Antipatterns**:
- Callback hell with nested completions
- Force unwrapping (!)
- 500+ line SwiftUI views
- Singletons with `.shared` everywhere
- Manual locks/semaphores

---

## fastlane

**Path**: `.claude/skills/fastlane/SKILL.md`

**Triggers**:
- Screenshot generation
- App Store deployment
- Snapfile configuration
- Screenshot dimension issues

**Symptoms Addressed**:
- Screenshots taking too long
- Wrong localization in screenshots
- Keychain conflicts in CI
- Screenshot dimension mismatch

**Patterns**:
- `erase_simulator(false)` - reuse warm simulator
- `reinstall_app(true)` - clean app state
- `localize_simulator(true)` - correct strings
- `concurrent_simulators(false)` - avoid keychain conflicts
- `only_testing` - run only screenshot tests
- `number_of_retries(2)` - handle CI flakiness

**Antipatterns**:
- `erase_simulator(true)` - adds 6-10 min per locale
- `concurrent_simulators(true)` - causes keychain conflicts
- Running all UI tests (not just screenshots)
- No test timeouts

**App Store Dimensions**:
- iPhone 6.7": 1290x2796
- iPad 13": 2064x2752
- Watch: 396x484

---

## xctest

**Path**: `.claude/skills/xctest/SKILL.md`

**Triggers**:
- Writing unit tests
- Writing UI tests
- Debugging test failures
- Test flakiness

**Symptoms Addressed**:
- Unclear test failures
- Flaky tests
- Tests that hang
- Poor test coverage

**Patterns**:
- Arrange-Act-Assert pattern
- `test<Method>_<Scenario>_<Expected>` naming
- `XCTAssertEqual` with message
- `try XCTUnwrap` for safe optionals
- `waitForExistence(timeout:)` for UI
- Accessibility identifiers for element queries

**Antipatterns**:
- `sleep()` in tests
- Force unwrapping in tests
- Multiple behaviors in one test
- `timeout: .infinity`
- Querying by text labels (breaks localization)
- Random test data

---

## simulator-management

**Path**: `.claude/skills/simulator-management/SKILL.md`

**Triggers**:
- Simulator boot failures
- "Unable to boot device" errors
- "Multiple devices matched" errors
- Duplicate simulators

**Symptoms Addressed**:
- Simulator hangs
- Race conditions with Fastlane
- Simulator state corruption
- Duplicate simulators

**Patterns**:
- `xcrun simctl shutdown all` before runs
- `xcrun simctl delete unavailable` for cleanup
- Let Fastlane boot simulators on demand
- `SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=120`

**Antipatterns**:
- Pre-booting simulators before Fastlane
- Not cleaning up between runs
- Leaving simulators in unknown state

**Quick Commands**:
```bash
xcrun simctl shutdown all
xcrun simctl delete unavailable
xcrun simctl list devices available
```

---

## swiftui-patterns

**Path**: `.claude/skills/swiftui-patterns/SKILL.md`

**Triggers**:
- List drag-and-drop issues
- ForEach onMove bugs
- Items "jumping back" after drag
- Data binding issues

**Symptoms Addressed**:
- onMove reverts visual changes
- Drag-drop loses state
- List items duplicate or disappear
- State becomes stale

**Patterns**:
- Direct `@Published` array binding with ForEach
- Update in-memory state first, persist async
- Hash only by `id` (stable during mutations)
- Single source of truth
- Mutation flag to block reloads during drag

**Antipatterns**:
- Computed property as ForEach data source (breaks drag)
- Multiple copies of state array
- Hash including mutable properties like `orderNumber`
- Fetch immediately after mutation
- Multiple notification observers triggering reloads

**Debug Checklist**:
1. Is data source computed or stored?
2. Are there multiple copies of state?
3. What notifications/observers exist?
4. Is there async work during mutation?
5. What's in the hash/equality implementation?

---

## coredata-sync

**Path**: `.claude/skills/coredata-sync/SKILL.md`

**Triggers**:
- CloudKit sync issues
- Data not appearing on other devices
- Race conditions after save
- Merge conflicts

**Symptoms Addressed**:
- Stale data after save
- Sync stuck in pending
- Data loss during sync
- Duplicate entities

**Patterns**:
- Use mutation flag to block reloads during save
- Don't fetch immediately after save (trust in-memory state)
- Use `mergeByPropertyObjectTrumpMergePolicy`
- Use `performBackgroundTask` for sync operations
- findOrCreate pattern for upsert

**Antipatterns**:
- `loadData()` immediately after `context.save()`
- Passing managed objects between threads
- No merge policy set
- Multiple sources of truth

**Common Errors**:
- "Merge conflict with no resolution" -> Set merge policy
- "Sync stuck in pending" -> Check CloudKit Dashboard
- "Duplicate entities" -> Use unique constraints

---

## code-review

**Path**: `.claude/skills/code-review/SKILL.md`

**Triggers**:
- PR review requested
- Code critique needed
- Architecture decisions
- Quality validation

**Symptoms Addressed**:
- Need structured review process
- Want to find flaws before merge
- Need to validate decisions

**Review Lenses**:
- Correctness, Security, Performance
- Maintainability, Testing, Error handling
- For architecture: Scalability, Flexibility, Coupling
- For CI/CD: Reliability, Speed, Debugging

**Patterns**:
- Frame critiques to further discussion
- Offer specific, actionable feedback
- Acknowledge good before pointing out issues
- Suggest alternatives when identifying problems
- Ask "What would make this fail?"

**Antipatterns**:
- Criticizing without offering alternatives
- Personal attacks
- Blocking progress indefinitely
- Vague criticism like "this feels wrong"
- Demanding perfection when good enough works

---

## watch-connectivity

**Path**: `.claude/skills/watch-connectivity/SKILL.md`

**Triggers**:
- iPhone-Watch sync issues
- Watch shows stale data
- Messages not received
- Session activation fails

**Symptoms Addressed**:
- Data not syncing to Watch
- Watch app shows old data
- Real-time sync not working

**Communication Methods**:
| Method | Use Case | Delivery |
|--------|----------|----------|
| `sendMessage` | Real-time, watch active | Immediate |
| `transferUserInfo` | Guaranteed delivery | Queued |
| `updateApplicationContext` | Latest state only | Replaces previous |

**Patterns**:
- Check `isReachable` before `sendMessage`
- Use `transferUserInfo` for guaranteed delivery
- Validate data at boundaries
- Handle all activation states

**Antipatterns**:
- Fire-and-forget without error handling
- Not checking activation state
- Inconsistent data transforms between services

---

## github-actions

**Path**: `.claude/skills/github-actions/SKILL.md`

**Triggers**:
- CI failures
- Pipeline optimization
- Workflow configuration
- Build/test timeouts

**Symptoms Addressed**:
- Jobs timing out
- Cannot debug failed runs
- Slow pipelines
- Flaky tests in CI

**Patterns**:
- Use `macos-14` or `macos-15` (Apple Silicon)
- Set `timeout-minutes` on all jobs
- Upload artifacts with `if: always()`
- Use `nick-fields/retry` for transient failures
- Cache Homebrew, bundler, derived data
- Parallel jobs for independent work

**Antipatterns**:
- `macos-12` (Intel, slower, deprecated)
- No timeout (6 hour default)
- Artifacts only on success
- No caching
- Single attempt without retry

**Code Signing in CI**:
```yaml
CODE_SIGN_IDENTITY=''
CODE_SIGNING_REQUIRED=NO
```

---

## bash-scripting

**Path**: `.claude/skills/bash-scripting/SKILL.md`

**Triggers**:
- Writing shell scripts
- Reviewing .sh files
- Script debugging
- CI script issues

**Symptoms Addressed**:
- Scripts failing silently
- Undefined variable errors
- Scripts not portable
- Missing cleanup

**Patterns**:
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Always quote variables: `"${var}"`
- Use traps for cleanup: `trap cleanup EXIT`
- Validate inputs at entry point
- Use `[[ ]]` for conditionals
- Errors to stderr

**Antipatterns**:
- Unquoted variables
- Missing `set -euo pipefail`
- Using `eval` with user input
- Parsing `ls` output
- No cleanup traps

**Review Checklist**:
1. HEADER: `#!/usr/bin/env bash`, `set -euo pipefail`
2. QUOTING: All variables quoted
3. VALIDATION: Inputs validated
4. CLEANUP: Traps for exit/error
5. SHELLCHECK: Passes without warnings

---

## test-isolation

**Path**: `.claude/skills/test-isolation/SKILL.md`

**Triggers**:
- Permission dialogs in tests
- Tests work locally but fail in CI
- System resource access in tests
- App Groups access errors

**Symptoms Addressed**:
- Permission dialogs blocking tests
- Tests triggering system access
- Flaky tests due to shared state

**Patterns**:
- Use `TestHelpers` factory methods
- Use in-memory Core Data for tests
- Use `XCTSkipIf` for integration tests
- Protocol-based mocking

**Class Mapping**:
| Production | Test Alternative |
|------------|------------------|
| `ExportViewModel()` | `TestHelpers.createTestExportViewModel()` |
| `DataManager.shared` | `TestHelpers.createTestDataManager()` |
| `CloudKitService()` | Skip with `XCTSkipIf` or mock |

**Antipatterns**:
- Direct `ViewModel()` instantiation in tests
- Using `.shared` singletons in tests
- Missing skip conditions for integration tests
- Tests that require signed builds

**Red Flags in Test Reviews**:
- Direct ViewModel instantiation
- Use of `.shared` singletons
- Missing XCTSkipIf for system resources
