#!/usr/bin/env bash
# PostToolUseFailure hook for listall MCP tools: at the moment a tool fails, point at the known trap
# for this error and the escalation ladder, so the failure is investigated instead of reported as a limit.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "${INPUT}" | jq -r '.tool_name // ""')
ERROR=$(echo "${INPUT}" | jq -r '.error // ""')

if [[ "${TOOL_NAME}" != mcp__listall__* ]]; then
  exit 0
fi

HINT="Unknown error: grep its message in Tools/listall-mcp/Sources to see what the tool actually checks before concluding anything."
if echo "${ERROR}" | grep -Fqi "no visible windows"; then
  HINT="Known trap: the window was not open yet. Never run listall_launch_macos and listall_screenshot_macos in the same parallel batch (UITEST_MODE quits the app first); call the screenshot after the launch result and retry. The diagnostics 'Screen Recording' line is not proof either way."
elif echo "${ERROR}" | grep -Fqi "xctestrun"; then
  HINT="Known trap: xctestrun lookup. See documentation/learnings/mcp-watch-xctestrun-naming.md; check the files in DerivedData/ListAll-*/Build/Products and that the MCP binary was rebuilt and Claude Code restarted."
elif echo "${ERROR}" | grep -Eqi "timed out|unresponsive"; then
  HINT="Known trap: simulator stuck (often after xcodebuild test). Run listall_shutdown_simulator(udid: all), boot again, relaunch the app, then retry."
fi

jq -n --arg hint "${HINT}" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUseFailure",
    additionalContext: ("listall MCP tool failed. " + $hint + " Do not report this as a limitation until you have run the escalation ladder in .claude/skills/visual-verification/SKILL.md \"When Something Fails\" (exact error, timing, tool source, learnings, 2 alternative paths).")
  }
}'
