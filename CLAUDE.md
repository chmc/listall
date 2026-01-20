# Project Instructions

## Mandatory Rules

- Never delete: `/CLAUDE.md`, `/.claude/`, `/docs/`
- Never remove UI features without explicit request
- Read before working: `/documentation/TODO.md`, `/documentation/ARCHITECTURE.md`
- Search `/documentation/learnings/*.md` when encountering issues (use tags/symptoms to find relevant files)
- Mark TODO.md tasks: `in-progress` → `completed`
- Update `documentation/features/SUMMARY.md` and category files after implementation
- Follow: TDD, DRY, SOLID, YAGNI
- All tests must pass before commit
- One task at a time

## Agents & Skills

Agents handle tasks; their skills load automatically. See `.claude/skills/INDEX.md` for skill reference.

| Agent | Use For | Skills |
|-------|---------|--------|
| `apple-dev` | iOS/watchOS implementation | swift-swiftui, fastlane, xctest |
| `apple-researcher` | Bug research, root causes | swiftui-patterns, coredata-sync |
| `critic` | Review before implementation | code-review |
| `integration-specialist` | Sync/data flow issues | coredata-sync, watch-connectivity |
| `pipeline-specialist` | CI/CD failures | github-actions, fastlane |
| `shell-specialist` | Shell scripts | bash-scripting |
| `testing-specialist` | Tests, verification | xctest, test-isolation |

**Always run `critic` before major implementations.**

## Learnings Format

Write learnings to `/documentation/learnings/`. See templates for format details:

| Template | Use For |
|----------|---------|
| `TEMPLATE.md` | Bug fixes, issues, problems solved |
| `GUIDE_TEMPLATE.md` | Reference docs, how-tos, analysis |
