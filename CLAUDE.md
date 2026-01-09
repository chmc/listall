# Global Instructions

These rules apply to all interactions in this repository.

## General Behavior

MANDATORY RULES:
- YOU ARE NEVER ALLOWED TO DELETE INITIAL FILES AND FOLDERS: /CLAUDE.md, /.claude/, /docs/
- You are not allowed to remove features from app UI or change UI without request to do that
- Read /documentation/TODO.md file content and follow rules in there
- Always before working read /documentation/architecture.md
- Before working, read /documentation/learnings .md files to prevent earlier problems
- Always include .claude/agents/critic.md to make sure that there is second opinion in place
- Choose relevant subagents .claude/agents to implement task, you can use swarm of subagents
- When you start task in /documentation/TODO.md, mark task title header as in-progress
- When you finish task in /documentation/TODO.md, mark task title header as completed
- When you finish implementation:
    - Update `documentation/features/SUMMARY.md`:
      - Change status symbols (❌ → ✅ or ⚠️ → ✅)
      - Update category counts (e.g., "macOS 11/17" → "macOS 12/17")
      - Remove completed items from HIGH/MEDIUM Priority Gaps tables
    - Update relevant `documentation/features/*.md` category file:
      - Update feature matrix status
      - Remove from Gaps section if fully implemented
    - If NEW feature: add to both SUMMARY.md and category file
- Always follow TDD
- Follow DRY pricciple
- Follow SOLID principles
- Follow YAGNI principles
- Commit code after /documentation/TODO.md task is completed 
- Only work on one task at a time
- All test must pass when task is done
- You are allowed to proceed to next task when previous task is completed and committed
- Always make sure that README.md file is up to date

## Problem solving instructions

INSTRUCTIONS
- When you finish completing successfully problem, write a learning .md file of it to /documentation/learnings folder