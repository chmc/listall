# Project Instructions

Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Subagent Skill Injection

MANDATORY: When spawning subagents via Task tool, you MUST instruct agents to use skills.

**Always include this instruction block in Task prompts (replace `{agent-name}` with actual agent):**
```
SKILL USAGE INSTRUCTION:
1. Read your agent definition at `.claude/agents/{agent-name}.md`
2. For each skill in your `skills:` frontmatter, read `.claude/skills/{skill-name}/SKILL.md`
3. ONLY if task requires skills outside your domain, read `.claude/skills/SKILLS-SUMMARY.md`
4. Apply patterns from loaded skills; reference which skills you used
```

**Example Task prompt:**
```
Task: Investigate CI pipeline failure

SKILL USAGE INSTRUCTION:
1. Read your agent definition at `.claude/agents/pipeline-specialist.md`
2. For each skill in your `skills:` frontmatter, read `.claude/skills/{skill-name}/SKILL.md`
3. ONLY if task requires skills outside your domain, read `.claude/skills/SKILLS-SUMMARY.md`
4. Apply patterns from loaded skills; reference which skills you used

Investigate why the screenshot job is timing out...
```

**Verification**: If your Task prompt does NOT contain the SKILL USAGE INSTRUCTION block, you are violating this rule.

## Mandatory Rules

- Never delete: `/CLAUDE.md`, `/.claude/`, `/docs/`
- Never remove UI features without explicit request
- Read before working: `/documentation/TODO.md`, `/documentation/ARCHITECTURE.md`
- Search `/documentation/learnings/*.md` when encountering issues (use tags/symptoms to find relevant files)
- Mark TODO.md tasks: `in-progress` → `completed`
- Always include .claude/agents/critic-reviewer.md to make sure that there is second opinion in place
- Update `documentation/features/SUMMARY.md` and category files after implementation
- Follow: TDD, DRY, SOLID, YAGNI
- All tests must pass before commit
- One task at a time

## Implementation Visual Verification

**BLOCKING RULE**: MCP tools MUST be connected before visual verification. If `listall_diagnostics` or other `listall_*` tools are not available, you MUST:
1. Stop and inform the user that MCP tools are not connected
2. Request Claude Code restart to load the MCP server
3. **NO WORKAROUNDS ALLOWED** - do not use `screencapture`, `simctl io`, or other alternatives

### Required Platform Coverage

**ALL implementations MUST be verified on ALL applicable platforms:**

| Platform | When Required | Tool |
|----------|---------------|------|
| macOS | Always for shared/macOS code | `listall_screenshot_macos` |
| iPhone | Always for shared/iOS code | `listall_screenshot` (boot iPhone simulator) |
| iPad | If UI supports iPad | `listall_screenshot` (boot iPad simulator) |
| watchOS | If change affects watch app | `listall_screenshot` (boot Watch simulator) |

### Verification Workflow

**Default: Screenshot-Only (always works)**

1. **Run `listall_diagnostics`** if tools not working
2. **macOS**: Launch with `UITEST_MODE`, screenshot
3. **iPhone**: Boot simulator, launch with `UITEST_MODE`, screenshot
4. **iPad** (if applicable): Boot iPad simulator, launch, screenshot
5. **watchOS** (if applicable): Boot Watch simulator, launch, screenshot
6. **Compare all screenshots** for consistency before considering task complete
7. **Cleanup (when done)**: Quit macOS app and shutdown simulators

**Advanced: Interactive (when needed for user flow testing)**

- Use `listall_query`, `listall_click`, `listall_type`, `listall_swipe` to test flows
- **macOS**: Always works (Accessibility API)
- **iOS/iPad Simulators**: Uses XCUITest (may have issues on some iOS versions)
- **watchOS**: Uses XCUITest (~10-30s per action, slower than iOS)
- If interactions fail, fall back to screenshot-only verification

### Launch Commands

```
# macOS
listall_launch_macos(app_name: "ListAll", launch_args: ["UITEST_MODE", "DISABLE_TOOLTIPS"])
listall_screenshot_macos(app_name: "ListAll")

# iPhone/iPad
listall_boot_simulator(udid: "...")
listall_launch(udid: "booted", bundle_id: "io.github.chmc.ListAll", launch_args: ["UITEST_MODE", "DISABLE_TOOLTIPS"])
listall_screenshot(udid: "booted")
```

### Cleanup Commands

```
# macOS - quit when done
listall_quit_macos(app_name: "ListAll")

# macOS - hide (keep running in background)
listall_hide_macos(app_name: "ListAll")

# Simulators
listall_shutdown_simulator(udid: "all")
```

**Background launch**: Add `BACKGROUND` to launch_args to launch without focusing:
```
listall_launch_macos(app_name: "ListAll", launch_args: ["UITEST_MODE", "BACKGROUND"])
```
Note: BACKGROUND means "not focused" - app windows still visible, just not frontmost. Use `listall_hide_macos` after launch if you want the app completely hidden.

MCP server configuration: `.mcp.json` (project root)
MCP server binary: `Tools/listall-mcp/.build/debug/listall-mcp`

See `.claude/skills/visual-verification/SKILL.md` for detailed patterns.

## Semantic Search Tools

`listall_call_graph` queries Xcode's IndexStore for structured code analysis.

**Modes:**
| Mode | Use for | Example |
|------|---------|---------|
| `"graph"` (default) | Callers + callees | `listall_call_graph(symbol: "addList(name:)")` |
| `"callers"` | Who calls this | `listall_call_graph(symbol: "save()", mode: "callers")` |
| `"callees"` | What this calls | `listall_call_graph(symbol: "save()", mode: "callees")` |
| `"definition"` | Find where defined | `listall_call_graph(symbol: "DataRepository", mode: "definition")` |
| `"references"` | All usages | `listall_call_graph(symbol: "addList", mode: "references")` |

**Requirements:** Project must be built in Xcode. After rebuilding MCP server, restart Claude Code.

**MANDATORY**: Use `listall_call_graph` as your primary tool for understanding Swift code. This includes: how features work, who calls what, where things are defined, and how components connect. Use Grep only for string literals, comments, docs, and non-code content.

**Bootstrapping workflow** (when you don't know the symbol name yet):
1. Use Glob to find likely source files (e.g., `**/Suggestion*.swift`)
2. Use `listall_call_graph(symbol: "SuggestionService", mode: "references")` to map the architecture
3. Use `listall_call_graph(symbol: "getSuggestions", mode: "graph")` to trace the full call flow
4. Read source files only for implementation details that call_graph doesn't show

**When to use which:**
| Question type | Tool | Why |
|--------------|------|-----|
| "How does X work?" | Glob → call_graph → Read | Find symbols, trace architecture, then read details |
| "Where is X defined?" | `call_graph(mode: "definition")` | Direct lookup |
| "Who uses X?" | `call_graph(mode: "references")` | All usages with context |
| String literals, config values | Grep | Text content, not code structure |
| Comments, TODOs, docs | Grep | Non-code content |

**Fallback**: If call_graph fails (index unavailable), run `touch .claude/.grep-fallback-authorized` then retry with Grep.

## Agents & Skills

Agents handle tasks; their skills load automatically. See `.claude/skills/INDEX.md` for skill reference.

| Agent | Use For | Skills |
|-------|---------|--------|
| `apple-dev-expert` | iOS/watchOS implementation, UX | swift-swiftui, fastlane, xctest, apple-hig, apple-ux-patterns |
| `apple-dev-researcher` | Bug research, root causes | swiftui-patterns, coredata-sync |
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
