#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
AGENT_TYPE=$(echo "${INPUT}" | jq -r '.agent_type // ""' 2>/dev/null || echo "")

# Agents that do not explore Swift code get no reminder
case "${AGENT_TYPE}" in
  critic-reviewer|shell-script-specialist|pipeline-specialist|statusline-setup|claude-code-guide|web-fetch)
    exit 0
    ;;
esac

# Explore and Plan start without CLAUDE.md, so this reminder is their only pointer to call_graph
jq -n '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: "REMINDER: Use listall_call_graph MCP tool as your primary Swift code exploration tool.\n- listall_call_graph(symbol:, mode: \"graph\") — full call graph (callers + callees)\n- listall_call_graph(symbol:, mode: \"callers\") — who calls this\n- listall_call_graph(symbol:, mode: \"references\") — all usages\n- listall_call_graph(symbol:, mode: \"definition\") — find definitions\nBootstrapping: Use Glob to find symbol names first, then trace with call_graph."
  }
}'
