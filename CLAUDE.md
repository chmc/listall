# Project Instructions

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
