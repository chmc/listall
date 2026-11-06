---
title: Maintaining the Claude Code Instructions (CLAUDE.md, skills, agents, hooks)
date: 2026-11-06
type: guide
category: ci-cd
tags:
  - claude-code
  - claude-md
  - skills
  - subagents
  - hooks
  - prompt-audit
  - ai-instructions
use_when:
  - Changing CLAUDE.md, .claude/skills, .claude/agents, .claude/hooks or .claude/settings.json
  - A rule in CLAUDE.md keeps being ignored
  - A hook does not fire or fails with "No such file or directory"
files_affected:
  - CLAUDE.md
  - .claude/settings.json
  - .claude/hooks/
  - .claude/agents/
  - .claude/skills/
related:
  - claude-code-mcp-server-config.md
---

## Overview

How the repo's Claude Code instructions are layered, what was verified about how Claude Code loads them (Claude Code 2.1.311, November 2026 audit), and how to test a change to them.

## Quick Reference

| Need | Where it goes |
|------|---------------|
| Fact or rule that applies to every task | `CLAUDE.md` (keep it under ~60 lines, plain wording, say why) |
| Procedure or domain knowledge | A skill; its `description` decides when it loads |
| Rule that must hold every time | A hook (`.claude/hooks/`, registered in `.claude/settings.json`) with tests in `.claude/hooks/tests/hooks.test.sh` |
| Personal preference of the user | Auto-memory, not the repo |

| Check | Command |
|-------|---------|
| Hook tests | `.claude/hooks/tests/hooks.test.sh` |
| Instruction audit (contradictions, stale references, old-model wording) | `claude -p "/doctor prompt-audit" --permission-mode plan` |
| Agent skill preloading | Spawn the agent with "without tools, quote the first heading of each skill whose full content is in your context" |

## Details

### Verified behavior

- **Custom agents preload their `skills:`**: probes of apple-dev-expert (7 skills), pipeline-specialist (3) and testing-specialist (3) quoted every listed skill's first heading without reading files. Prompts don't need to tell agents to read their skills. Built-in Explore and Plan agents get no preloaded skills and no CLAUDE.md, so constraints they need go into the prompt (the SubagentStart hook adds the call_graph reminder).
- **Hooks are read at session start**: a hook added to `settings.json` mid-session did not run in that session, and did run in a fresh `claude -p` session. Test hook changes with `.claude/hooks/tests/hooks.test.sh` and a fresh session.
- **Hook commands need `"${CLAUDE_PROJECT_DIR}"`**: with relative paths, a `cd ListAll` in the session made the Stop hook fail with `.claude/hooks/verification-gap-check.sh: No such file or directory`.
- **Skill descriptions are YAML**: an unquoted description containing `: ` is invalid YAML. Quote descriptions.
- **Skill description changes apply immediately** in the running session (the skill listing was refreshed after the edit).

### Why the 2026-11 rewrite removed things

Official guidance (code.claude.com/docs/en/best-practices, memory, skills, sub-agents, hooks) for current models: CLAUDE.md under 200 lines, no architecture description (Claude reads the repo), no ALL-CAPS emphasis (it makes the model over-apply rules), exact test commands instead, and hooks for rules that must not be skipped. The audit found broken agent names, references to deleted scripts and tests, a skill index covering 13 of 15 skills, generic skill advice that contradicted the code (`@Observable`, "no singletons"), and memory entries describing a PLAN.md protocol that no longer existed.

### Rules that are enforced, not just written

- `feature-doc-gate.sh`: added because `documentation/features/SUMMARY.md` stayed untouched through 37 `feat` commits. Escape hatch: `Feature-Doc: n/a (reason)` trailer.
- `verification-gap-check.sh`, `mcp-failure-ladder.sh`: the escalation ladder before reporting "can't verify".
- `semantic-search-enforce.sh`: Grep for Swift symbols is blocked in favor of `listall_call_graph`.

Add a new hook only when a written rule is shown to be skipped; each one adds friction to every session.

## Troubleshooting

- **Hook "No such file or directory"**: the command path is relative; use `"${CLAUDE_PROJECT_DIR}"/.claude/hooks/<name>.sh`.
- **New hook does nothing**: restart Claude Code; hooks are captured at session start.
- **Rule in CLAUDE.md ignored**: shorten the file or move the rule into a hook; adding IMPORTANT/MUST does not help current models.
- **Skill never loads**: rewrite its description as "what it does. Use when ..." with the words a request would contain.
