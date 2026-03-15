# Project Instructions

Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Subagent Skill Injection

MANDATORY: When spawning subagents via Task tool, include this instruction block in prompts (replace `{agent-name}`):
```
SKILL USAGE INSTRUCTION:
1. Read your agent definition at `.claude/agents/{agent-name}.md`
2. For each skill in your `skills:` frontmatter, read `.claude/skills/{skill-name}/SKILL.md`
3. ONLY if task requires skills outside your domain, read `.claude/skills/SKILLS-SUMMARY.md`
4. Apply patterns from loaded skills; reference which skills you used
```
**Verification**: If your Task prompt does NOT contain the SKILL USAGE INSTRUCTION block, you are violating this rule.

## Mandatory Rules

- Never delete: `/CLAUDE.md`, `/.claude/`, `/docs/`
- Never remove UI features without explicit request
- Read before working: `/documentation/ARCHITECTURE.md`
- Search `/documentation/learnings/*.md` when encountering issues (use tags/symptoms to find relevant files)
- Before implementation: check if documentation in `/documentation/` needs updating based on the change
- Always include .claude/agents/critic-reviewer.md to make sure that there is second opinion in place
- Update `documentation/features/SUMMARY.md` and category files after implementation
- Visual verification (build → launch → screenshot → analyze) is mandatory after ALL implementation work
- Follow: TDD, DRY, SOLID, YAGNI
- All tests must pass before commit
- One task at a time

## Implementation Visual Verification

**BLOCKING RULE**: MCP tools MUST be connected before visual verification. If `listall_diagnostics` or other `listall_*` tools are not available, you MUST:
1. Stop and inform the user that MCP tools are not connected
2. Request Claude Code restart to load the MCP server
3. **NO WORKAROUNDS ALLOWED** - do not use `screencapture`, `simctl io`, or other alternatives

### Required Platform Coverage

| Platform | When Required | Tool |
|----------|---------------|------|
| macOS | Always for shared/macOS code | `listall_screenshot_macos` |
| iPhone | Always for shared/iOS code | `listall_screenshot` (boot iPhone simulator) |
| iPad | If UI supports iPad | `listall_screenshot` (boot iPad simulator) |
| watchOS | If change affects watch app | `listall_screenshot` (boot Watch simulator) |

### Verification Workflow

1. **Run `listall_diagnostics`** if tools not working
2. Launch each applicable platform with `UITEST_MODE` + `DISABLE_TOOLTIPS`
3. Screenshot all platforms, compare for consistency
4. For interactive testing: use `listall_query`, `listall_click`, `listall_type`, `listall_swipe`
5. **Cleanup**: Quit macOS app (`listall_quit_macos`) and shutdown simulators (`listall_shutdown_simulator`)

MCP server config: `.mcp.json` | Binary: `Tools/listall-mcp/.build/debug/listall-mcp`

See `.claude/skills/visual-verification/SKILL.md` for launch commands, cleanup, and detailed patterns.

## UI Polish Verification

After any UI implementation, run the `professional-ui-polish` Debug Checklist before considering task complete.
See `.claude/skills/professional-ui-polish/SKILL.md` for full patterns and antipatterns.

## Semantic Search Tools

**MANDATORY**: Use `listall_call_graph` as primary tool for understanding Swift code (callers, definitions, references, hierarchy). Use Grep only for string literals, comments, non-code content.
See `.claude/skills/semantic-search/SKILL.md` for modes, parameters, and workflows.
**Fallback**: If call_graph fails, run `touch .claude/.grep-fallback-authorized` then retry with Grep.

## Agents & Skills

Agents handle tasks; their skills load automatically. See `.claude/skills/INDEX.md` for skill reference.

| Agent | Use For | Skills |
|-------|---------|--------|
| `apple-dev-expert` | iOS/watchOS implementation, UX | swift-swiftui, fastlane, xctest, apple-hig, apple-ux-patterns, professional-ui-polish |
| `apple-dev-researcher` | Bug research, root causes | swiftui-patterns, coredata-sync, professional-ui-polish |
| `critic` | Review before implementation | code-review |
| `integration-specialist` | Sync/data flow issues | coredata-sync, watch-connectivity |
| `pipeline-specialist` | CI/CD failures | github-actions, fastlane |
| `shell-specialist` | Shell scripts | bash-scripting |
| `testing-specialist` | Tests, verification | xctest, test-isolation |

**Always run `critic` before major implementations.**

## Learnings Format

Write learnings to `/documentation/learnings/` using LLM optimized format. See templates for format details:

| Template | Use For |
|----------|---------|
| `TEMPLATE.md` | Bug fixes, issues, problems solved |
| `GUIDE_TEMPLATE.md` | Reference docs, how-tos, analysis |
