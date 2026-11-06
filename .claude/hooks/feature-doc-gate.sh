#!/usr/bin/env bash
# PreToolUse hook for Bash: a feat commit that changes app code must also update documentation/features/.
# The rule existed only as text and was skipped: 37 feat commits after 2026-01-20, features/SUMMARY.md untouched.
# Escape hatch for features that are not user-facing: a "Feature-Doc: n/a (reason)" trailer in the message.
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "${INPUT}" | jq -r '.tool_input.command // ""')

if ! printf '%s' "${COMMAND}" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit'; then
  exit 0
fi

# Conventional commit type at the start of the message: -m "feat...", or a line starting with feat (heredoc)
if ! printf '%s' "${COMMAND}" | perl -0777 -ne 'exit(/(?:^|\n|["'"'"'])[ \t]*feat(?:\([^)]*\))?!?:/ ? 0 : 1)'; then
  exit 0
fi

if printf '%s' "${COMMAND}" | grep -Fq 'Feature-Doc: n/a'; then
  exit 0
fi

REPO="${CLAUDE_PROJECT_DIR:-.}"
# git add / commit -a in the same command stage files only after this hook runs, so look at all changes then
if printf '%s' "${COMMAND}" | grep -Eq 'git[[:space:]]+add|commit[^;&|]*[[:space:]](-a|--all|-[a-zA-Z]*a[a-zA-Z]*)([[:space:]]|$)'; then
  CHANGED=$(git -C "${REPO}" status --porcelain --untracked-files=all | cut -c4-)
else
  CHANGED=$(git -C "${REPO}" diff --cached --name-only)
fi

if ! printf '%s\n' "${CHANGED}" | grep -Eq '^"?ListAll/(ListAll|ListAllMac|ListAllWatch Watch App|Shared)/'; then
  exit 0
fi
if printf '%s\n' "${CHANGED}" | grep -Eq '^"?documentation/features/'; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "feat commit changes app code but not documentation/features/. Update documentation/features/SUMMARY.md and the category file for the user-facing change, stage them, and commit again. If the feature is not user-facing, add a trailer line \"Feature-Doc: n/a (reason)\" to the commit message."
  }
}'
