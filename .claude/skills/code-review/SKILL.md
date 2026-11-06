---
name: code-review
description: "Review checklist and severity levels for ListAll changes, focused on correctness. Use when reviewing a diff, PR or plan, or validating an implementation before commit."
---

# Code Review

Look for what would make the change wrong, and prove findings (failing test, log, `file:line`) instead of asserting them. Skip style preferences and tests for cases that cannot happen; say plainly when a part is fine.

## Severity

| Level | Meaning |
|-------|---------|
| CRITICAL | Data loss, crash, sync corruption, broken release; must fix |
| IMPORTANT | Wrong behavior in a real scenario, missing test for changed logic; fix before commit |
| MINOR | Real but low-impact issue; fix if cheap |
| OBSERVATION | Worth knowing, no action needed |

## ListAll Risk Checklist

Recurring bug sources in this codebase, check these first:

- **Core Data threading**: `perform` vs `performAndWait` where the next line depends on the result; contexts used off their queue (`documentation/learnings/macos-cloudkit-sync-race-condition.md`).
- **Sync reloads**: notification bursts must coalesce into one reload; reloads must not overwrite an in-flight mutation (`coredata-sync` skill).
- **Watch connectivity**: payload shape changes need both iPhone and watch sides plus the round-trip test (`watch-connectivity` skill).
- **Platforms**: shared files compile for iOS, macOS and watchOS; `#if os(...)` branches all still build.
- **Localization**: new user-facing strings have Finnish translations in `Localizable.xcstrings`.
- **Tests**: wait on state (`XCTNSPredicateExpectation`), not fixed `asyncAfter` delays; macOS tests don't touch real App Groups or iCloud (`test-isolation` skill).
- **Docs**: user-facing feature changes update `documentation/features/` (the `feature-doc-gate` hook enforces this on `feat` commits).

## Lenses by Change Type

- **Code**: correctness, error handling, test coverage of the changed logic.
- **CI/CD**: reliability, run time, whether a failure is diagnosable from the log, what happens when a job is cancelled or times out.
- **Dependency upgrades**: a clean compile is not enough. Diff how the library calls your code (concurrency and serialization of handlers, cancellation, ordering, defaults). Diff `Package.resolved`. Under 0.x, `from:` accepts any 0.y; use `.upToNextMinor(from:)`. Count deprecations from a clean build. Know how to roll back.

## Escalate

Object strongly when user data or privacy is at risk, an irreversible step has no safeguard, or core architecture changes without analysis.
