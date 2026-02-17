---
description: Use swarm of subagents to implement a plan section
argument-hint: [what-to-implement] [@plan-file]
---

You are executing a plan section using a swarm of subagents. Follow these instructions precisely. Apply visual verification skill.

## 1. Parse Arguments

The user provided: $ARGUMENTS

Extract two pieces of information:
- **WHAT** to implement (the section/feature/task description)
- **WHICH FILE** contains the plan spec (look for `@file` references or file paths)

If either is missing or unclear, use `AskUserQuestion` to ask:
- "What section/feature should I implement?" (if WHAT is missing)
- "Which file contains the plan?" (if WHICH FILE is missing — offer recently modified .md files as options)

## 2. Read the Plan

Read the referenced plan file. Extract the specific section that matches what the user wants implemented. Capture:
- The full task descriptions (every detail matters for subagents)
- Any context, constraints, or dependencies mentioned
- Acceptance criteria if present

## 3. Invoke the Subagent-Driven Development Skill

**MANDATORY:** Invoke the `superpowers:subagent-driven-development` skill and follow its process for task dispatch and review loops.

**CRITICAL OVERRIDE:** Follow steps 1–6 of THIS command only. When the `subagent-driven-development` skill's process reaches its final "finishing" step (invoking `finishing-a-development-branch`), **SKIP IT**. Do NOT invoke `superpowers:finishing-a-development-branch`. Instead, proceed to step 6 ("Completion Summary") below.

The parts of the skill you MUST use:

- Read plan once, extract ALL tasks with full text
- Create TodoWrite with all tasks
- For each task (sequential dispatch):
  1. **Dispatch implementer subagent** with full task text + context
  2. Answer any questions the subagent raises
  3. **Dispatch spec compliance reviewer** — must pass before proceeding
  4. **Dispatch code quality reviewer** — must pass before proceeding
  5. Review loops until both reviewers approve
  6. Mark task complete

## 4. Follow ALL CLAUDE.md Rules

Every subagent Task prompt MUST include:

```
SKILL USAGE INSTRUCTION:
1. Read your agent definition at `.claude/agents/{agent-name}.md`
2. For each skill in your `skills:` frontmatter, read `.claude/skills/{skill-name}/SKILL.md`
3. ONLY if task requires skills outside your domain, read `.claude/skills/SKILLS-SUMMARY.md`
4. Apply patterns from loaded skills; reference which skills you used
```

Additional mandatory rules:
- Run critic-reviewer before major implementations
- Follow TDD, DRY, SOLID, YAGNI
- All tests must pass before commit
- Use `listall_call_graph` as primary tool for understanding Swift code

## 5. Visual Verification After Implementation

**BLOCKING RULE:** After all tasks are complete, apply the `visual-verification` skill:

1. Run `listall_diagnostics` to confirm MCP tools are connected
2. Build and launch on ALL applicable platforms:
   - **macOS**: `listall_launch_macos` with `UITEST_MODE`, then `listall_screenshot_macos`
   - **iPhone**: Boot simulator, launch with `UITEST_MODE`, screenshot
   - **iPad** (if UI changes): Boot iPad simulator, launch, screenshot
   - **watchOS** (if watch changes): Boot Watch simulator, launch, screenshot
3. Carefully analyze ALL screenshots for correctness (layout, alignment, content, navigation)
4. Compare screenshots across platforms for consistency
5. **Cleanup**: Quit macOS app (`listall_quit_macos`) and shutdown simulators (`listall_shutdown_simulator`)

## 6. Completion Summary

After visual verification passes, end the session by:

1. **Summarize** what was implemented: files changed, features added, tests written
2. **Present changes as unstaged** — do NOT commit, merge, or create PRs automatically
3. **Ask the user** what they want to do next (e.g., review the diff, commit, run more tests, etc.)

**HARD STOP:** Do NOT invoke `superpowers:finishing-a-development-branch`. Do NOT automatically merge, create PRs, or commit. The user decides what happens next.
