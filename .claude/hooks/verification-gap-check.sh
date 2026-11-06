#!/usr/bin/env bash
# Stop hook: when the final answer claims something could not be verified but shows no attempts
# ("Kokeiltu:" / "Tried:"), ask once for the escalation ladder before stopping.
# See .claude/skills/visual-verification/SKILL.md "When Something Fails".
set -euo pipefail

INPUT=$(cat)

# Loop guard 1: already continuing because of a Stop hook
if [[ "$(echo "${INPUT}" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  exit 0
fi

MESSAGE=$(echo "${INPUT}" | jq -r '.last_assistant_message // ""')
if [[ -z "${MESSAGE}" ]]; then
  exit 0
fi

# Ignore code and quoted text: phrases there are examples or meta discussion, not claims
PROSE=$(printf '%s' "${MESSAGE}" | perl -0777 -pe 's/```.*?```//gs; s/`[^`\n]*`//g; s/"[^"\n]*"//g; s/\x{201C}[^\x{201D}\n]*\x{201D}//g' 2>/dev/null || printf '%s' "${MESSAGE}")

readonly LIMITATION_PATTERN="ei (voi|voida|voitu|pysty|pystytty) (vielä )?todent|ei todennettu|todentamat|ei todennettavissa|en (pysty|pystynyt|voinut) todentamaan|simulaattorin rajoitus|(cannot|can't|couldn't|could not|unable to) (be )?verif|not verif(ied|iable)|unverified|simulator limitation"

if ! printf '%s' "${PROSE}" | grep -Eiq "${LIMITATION_PATTERN}"; then
  exit 0
fi

# Attempts are listed: nothing to add
if printf '%s' "${MESSAGE}" | grep -Eiq '(Kokeiltu|Tried)[*_]*:'; then
  exit 0
fi

# Loop guard 2: at most once per message (independent of stop_hook_active semantics)
SESSION_ID=$(echo "${INPUT}" | jq -r '.session_id // "unknown"')
HASH=$(printf '%s' "${MESSAGE}" | shasum | cut -c1-16)
MARKER="${TMPDIR:-/tmp}/claude-verification-gap-${SESSION_ID}-${HASH}"
if [[ -e "${MARKER}" ]]; then
  exit 0
fi
touch "${MARKER}"

jq -n '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: "Your answer says something could not be verified, but lists no attempts. Before stopping, for EACH unverified item run the escalation ladder (.claude/skills/visual-verification/SKILL.md \"When Something Fails\"): 1) read the exact error, not a diagnostic summary 2) rule out timing/state (wait for the condition, retry; never run launch and screenshot in the same parallel batch) 3) read the tool source if it is in the repo (Tools/listall-mcp) 4) search documentation/learnings/ and Known traps 5) try at least 2 alternative paths (another MCP tool, xcodebuild test, round-trip/integration test, real device). Then add a \"Kokeiltu:\" line per item with the command and its result, or cite the learnings file that documents the limitation with evidence. If you already did this, add the Kokeiltu lines and stop."
  }
}'
