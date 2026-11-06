# Project Instructions

Use Context7 MCP for library/API documentation, code generation, setup or configuration steps without being asked.

## Rules

- Don't delete the `/.claude/` or `/docs/` directories or `/CLAUDE.md`. Show the user any single file you remove or merge under them before committing.
- Never remove UI features without an explicit request.
- Read `documentation/ARCHITECTURE.md` before working on app code.
- When something fails, search `documentation/learnings/` first (by `tags:` and symptoms); most recurring problems are recorded there.
- Before implementing, check which docs in `documentation/` the change affects and update them. A user-facing feature added or removed updates `documentation/features/SUMMARY.md` and its category file; the `feature-doc-gate` hook blocks `feat` commits that change app code without them.
- Follow TDD, DRY, SOLID, YAGNI. One task at a time.
- All tests must pass before commit. Commits go straight to `main`, so CI only reports a failure after it has landed.

## Build & Test

Run from `ListAll/`. Commands mirror `.github/workflows/ci.yml`; `resolve-simulator.sh` pins the simulator runtime to the Xcode in `.xcode-version`.

```bash
IOS=$(../.github/scripts/resolve-simulator.sh iOS "iPhone 17 Pro")
WATCH=$(../.github/scripts/resolve-simulator.sh watchOS "Apple Watch Series 11 (46mm)")
xcodebuild test -project ListAll.xcodeproj -scheme ListAll -destination "platform=iOS Simulator,id=$IOS" -parallel-testing-enabled NO \
  -skip-testing:ListAllTests/AppGroupsTests -skip-testing:ListAllTests/CloudKitTests -skip-testing:ListAllUITests -skip-testing:ListAllUITestsLaunchTests
xcodebuild test -project ListAll.xcodeproj -scheme "ListAllWatch Watch App" -destination "platform=watchOS Simulator,id=$WATCH" -parallel-testing-enabled NO -skip-testing:"ListAllWatch Watch AppUITests"
xcodebuild test -project ListAll.xcodeproj -scheme ListAllMac -destination 'platform=macOS' -skip-testing:ListAllMacUITests -skip-testing:MacKeyboardNavigationTests
# One test: -only-testing:<Target>/<Class>/<method>
```

`bundle exec fastlane test` ends in `|| true` and never fails, so don't use it as a check.

## Visual Verification

After every change to app code, build, launch, screenshot and analyze the result on each affected platform (macOS, iPhone, iPad if it shows the UI, watch if affected) with the listall MCP tools. Unit tests don't catch layout, navigation or localization problems, and the user expects the screenshots to have been studied, not just taken. The `visual-verification` skill has the platform rules, fresh-build sequence, launch arguments and cleanup.

## Decision Protocol

Before asking for plan approval, before a root-cause or fix decision, and before saying something is done:

1. **Verify facts**: give evidence for every claim the decision depends on: the command you ran and its output, or `file:line`. Take counts and warnings from a clean state (no incremental build or cache). A root-cause claim, including "this path works", needs reproduction evidence (log line or screenshot) whenever the bug is reproducible.
2. **Separate**: list *verified* (with evidence) and *not verified* separately. Each not-verified item gets a `Kokeiltu:` line (what you tried and the result) or a link to a learnings file that documents the limitation with evidence.
3. **Challenge**: ask what would make each claim wrong and what was not tested. For non-trivial changes (not typo fixes), run `critic-reviewer`: during planning, before asking for approval, or, when no plan was reviewed, before saying the change is done (it caught a missing requirement test that the implementer's own run missed). Give it the code and the plan, not your conclusions, ask it to verify the claims itself and to report correctness gaps rather than style.
4. **Decide**: state the decision with reasons, and which claims were refuted and what changed as a result.

Before reporting anything as a limitation ("can't verify", "not possible", "tool doesn't work"), run the escalation ladder in the `visual-verification` skill → "When Something Fails". Its alternative paths are other listall MCP tools, `xcodebuild test`, integration tests or a real device, not screenshot substitutes. The `mcp-failure-ladder` and `verification-gap-check` hooks point back to it.

## Code Navigation

Use `listall_call_graph` for Swift symbols (callers, definitions, references, hierarchy) and Grep for string literals, comments and non-Swift files; the `semantic-search` skill has the modes. A hook blocks symbol-like Grep searches. If the call graph index is unavailable, `touch .claude/.grep-fallback-authorized` allows Grep for 5 minutes.

## Subagents

Custom agents in `.claude/agents/` preload the skills listed in their `skills:` frontmatter, and their descriptions say when to use them. Built-in Explore and Plan agents don't read this file, so put any constraint they need into the prompt.

## Learnings

Write learnings to `documentation/learnings/` with `TEMPLATE.md` (bugs and fixes) or `GUIDE_TEMPLATE.md` (reference and analysis), including `title:` and `tags:` frontmatter so they can be found later.
