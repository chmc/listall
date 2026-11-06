#!/usr/bin/env bash
# Tests for verification-gap-check.sh (Stop) and mcp-failure-ladder.sh (PostToolUseFailure).
# Run: .claude/hooks/tests/hooks.test.sh
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly HOOK_DIR
readonly STOP_HOOK="${HOOK_DIR}/verification-gap-check.sh"
readonly FAILURE_HOOK="${HOOK_DIR}/mcp-failure-ladder.sh"

PASSED=0
FAILED=0

# Each test gets a fresh marker directory so "once per message" state does not leak
fresh_tmpdir() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

run_stop_hook() {
  local message="${1}"
  local active="${2:-false}"
  local session="${3:-test-session}"
  jq -n --arg m "${message}" --argjson a "${active}" --arg s "${session}" \
    '{session_id: $s, hook_event_name: "Stop", stop_hook_active: $a, last_assistant_message: $m}' \
    | "${STOP_HOOK}"
}

run_failure_hook() {
  local tool="${1}"
  local error="${2}"
  jq -n --arg t "${tool}" --arg e "${error}" \
    '{hook_event_name: "PostToolUseFailure", tool_name: $t, tool_input: {}, error: $e}' \
    | "${FAILURE_HOOK}"
}

expect_context() {
  local name="${1}" output="${2}"
  if [[ -n "${output}" ]] && echo "${output}" | jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo "FAIL (expected feedback): ${name}"
  fi
}

expect_silent() {
  local name="${1}" output="${2}"
  if [[ -z "${output}" ]]; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo "FAIL (expected no output): ${name}: ${output}"
  fi
}

expect_context_contains() {
  local name="${1}" output="${2}" needle="${3}"
  if echo "${output}" | jq -r '.hookSpecificOutput.additionalContext // ""' | grep -Fq "${needle}"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo "FAIL (expected '${needle}'): ${name}"
  fi
}

# --- Stop hook: real messages from project history (2026) ---

fresh_tmpdir
expect_context "real: limitation claimed (watch sync)" "$(run_stop_hook \
  'Korjaus on valmis ja testit menevät läpi, mutta yhtä osaa ei voi todentaa simulaattorissa: sitä, että listat todella saapuvat kelloon.')"

fresh_tmpdir
expect_context "real: limitation claimed (CI)" "$(run_stop_hook \
  'toimiiko macOS-kuvien validointi ja toistuuko 19.3. watchOS-kaatuminen. Näitä ei voi todentaa paikallisesti.')"

fresh_tmpdir
expect_context "real: 'Ei todennettu:' heading" "$(run_stop_hook \
  $'**Ei todennettu:**\n- Listojen saapumista kelloon simulaattorissa.')"

fresh_tmpdir
expect_silent "real: quoted phrase in meta discussion" "$(run_stop_hook \
  'Luovutin todentamisessa liian helposti. Kolmesta "ei voi todentaa" -kohdasta kaksi oli väärin.')"

fresh_tmpdir
expect_silent "real: quoted 'ei todennettu' in plan" "$(run_stop_hook \
  'critic-reviewer-agentti haastaa jatkossa jokaisen "ei todennettu" -kohdan.')"

fresh_tmpdir
# shellcheck disable=SC2016 # backticks are literal Markdown in the message
expect_silent "real: sudo cannot prompt" "$(run_stop_hook \
  '`sudo` ei pysty kysymään salasanaa `!`-kehotteen kautta, koska se tarvitsee oikean terminaalin.')"

fresh_tmpdir
expect_silent "real: disk image cannot grow" "$(run_stop_hook \
  'Jos virtuaalikone yrittää käyttää yli 43 Gt, levykuva ei pysty kasvamaan.')"

fresh_tmpdir
expect_silent "phrase only inside code block" "$(run_stop_hook \
  $'Lisäsin regexin:\n```\nei voi todentaa|not verified\n```\nValmis.')"

# --- Stop hook: escape hatches and loop guards ---

fresh_tmpdir
expect_silent "limitation with Kokeiltu evidence" "$(run_stop_hook \
  $'Tätä ei voi todentaa simulaattorissa.\nKokeiltu: transferUserInfo 5 kertaa, 0 toimitettu (loki).')"

fresh_tmpdir
expect_silent "limitation with Tried evidence" "$(run_stop_hook \
  $'This could not verify delivery.\nTried: log stream on both simulators.')"

fresh_tmpdir
expect_context "english couldn't verify" "$(run_stop_hook "I couldn't verify the watch receives the lists.")"

fresh_tmpdir
expect_context "english not verifiable" "$(run_stop_hook 'Three items are not verifiable in the simulator.')"

fresh_tmpdir
expect_silent "stop_hook_active true" "$(run_stop_hook 'Tätä ei voi todentaa.' true)"

fresh_tmpdir
first="$(run_stop_hook 'Tätä ei voi todentaa.' false same-session)"
second="$(run_stop_hook 'Tätä ei voi todentaa.' false same-session)"
expect_context "same message: first time" "${first}"
expect_silent "same message: second time" "${second}"

fresh_tmpdir
expect_silent "no limitation words" "$(run_stop_hook 'Kaikki testit menevät läpi ja kuvakaappaukset on analysoitu.')"

# --- PostToolUseFailure hook ---

expect_context_contains "window not found" \
  "$(run_failure_hook mcp__listall__listall_screenshot_macos "Internal error: Application 'ListAll' not found or has no visible windows.")" \
  "parallel"

expect_context_contains "xctestrun missing" \
  "$(run_failure_hook mcp__listall__listall_click 'Internal error: XCUITest result file not found. build-for-testing did not generate xctestrun file')" \
  "mcp-watch-xctestrun-naming.md"

expect_context_contains "simulator timeout" \
  "$(run_failure_hook mcp__listall__listall_screenshot 'Internal error: Command timed out after 30 seconds. The simulator may be unresponsive.')" \
  "listall_shutdown_simulator"

expect_context_contains "unknown error points at tool source" \
  "$(run_failure_hook mcp__listall__listall_query 'Internal error: something new')" \
  "Tools/listall-mcp/Sources"

expect_silent "other MCP server ignored" "$(run_failure_hook mcp__playwright__browser_click 'boom')"

echo "Passed: ${PASSED}, Failed: ${FAILED}"
[[ "${FAILED}" -eq 0 ]]
