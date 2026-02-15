#!/bin/bash
INPUT=$(cat)
PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // ""')

# Does the pattern contain a backslash-paren (escaped parenthesis)?
# This suggests searching for function calls/definitions
if echo "$PATTERN" | grep -Fq '\('; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "Reminder: Consider using listall_call_graph MCP tool instead of Grep for function caller/callee searches. It provides structured results with file paths and line numbers."
    }
  }'
else
  exit 0
fi
