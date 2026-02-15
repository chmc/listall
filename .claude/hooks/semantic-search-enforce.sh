#!/usr/bin/env bash
set -euo pipefail

# Configuration
readonly FALLBACK_FILE=".claude/.grep-fallback-authorized"
readonly FALLBACK_TTL_SECONDS=300

# Read stdin
INPUT=$(cat)

# Extract pattern and file target info
PATTERN=$(echo "${INPUT}" | jq -r '.tool_input.pattern // ""' 2>/dev/null || echo "")
GLOB=$(echo "${INPUT}" | jq -r '.tool_input.glob // ""' 2>/dev/null || echo "")
PATH_TARGET=$(echo "${INPUT}" | jq -r '.tool_input.path // ""' 2>/dev/null || echo "")

if [[ -z "${PATTERN}" ]]; then
  exit 0
fi

# Check if fallback is authorized (file exists and is recent)
if [[ -f "${FALLBACK_FILE}" ]]; then
  CURRENT_TIME=$(date +%s)
  FILE_MTIME=$(stat -f %m "${FALLBACK_FILE}" 2>/dev/null || echo "0")
  AGE=$((CURRENT_TIME - FILE_MTIME))

  if [[ "${AGE}" -lt "${FALLBACK_TTL_SECONDS}" ]]; then
    exit 0  # Fallback authorized, allow grep
  else
    rm -f "${FALLBACK_FILE}" 2>/dev/null || true
  fi
fi

# === ALLOW EXCEPTIONS (exit 0 = allow) ===

# Non-Swift file targets: check glob and path for non-Swift extensions
if [[ -n "${GLOB}" ]] && echo "${GLOB}" | grep -Eq '\.(json|md|yml|yaml|sh|py|txt|html|css|js|ts|toml|cfg|ini|xml|plist|pbxproj|xcscheme|strings|entitlements)'; then
  exit 0
fi
if [[ -n "${PATH_TARGET}" ]] && echo "${PATH_TARGET}" | grep -Eq '\.(json|md|yml|yaml|sh|py|txt|html|css|js|ts|toml|cfg|ini|xml|plist|pbxproj|xcscheme|strings|entitlements)$'; then
  exit 0
fi

# Short patterns (< 4 chars) or long patterns (> 50 chars)
PATTERN_LEN=${#PATTERN}
if [[ "${PATTERN_LEN}" -lt 4 ]] || [[ "${PATTERN_LEN}" -gt 50 ]]; then
  exit 0
fi

# Combined allow-list check: quotes, spaces, regex operators, comment markers, @/import prefix
if echo "${PATTERN}" | grep -Eq '"|'\''|[[:space:]]|\.\*|\.\+|\\s|\\w|\\d|\[.*\]|//|TODO:|FIXME:|MARK:|^@|^import '; then
  exit 0
fi

# Short common words that are not symbol searches
PATTERN_LOWER=$(echo "${PATTERN}" | tr '[:upper:]' '[:lower:]')
case "${PATTERN_LOWER}" in
  id|url|app|data|list|item|view|name|type|mode|state|error|count|index|label|value|title|color|image|model|style|save|load|true|false|self|none|some|body|task|font|size|text|icon|date|file|case|func|enum|init|main|test|copy|edit|done|back|next|push|pull|sort|void|user|info|warn|cell|core|sync|mark|note|todo|with|from|into|each|bind)
    exit 0
    ;;
esac

# === DENY PATTERNS ===

IS_FUNCTION_SEARCH=false

# Hard deny: literal backslash-paren (Swift method signature)
if echo "${PATTERN}" | grep -Fq '\('; then
  IS_FUNCTION_SEARCH=true

# Hard deny: func keyword, "who calls", "callers of"
elif echo "${PATTERN}" | grep -Eq '^func[[:space:]]|who.?calls|callers?.of'; then
  IS_FUNCTION_SEARCH=true

# Hard deny: known type suffixes (ViewModel, Service, Manager, etc.)
elif echo "${PATTERN}" | grep -Eq '(ViewModel|Service|Manager|Repository|Provider|Controller|Coordinator|Interactor|UseCase)$'; then
  IS_FUNCTION_SEARCH=true

# Hard deny: camelCase with verb prefix (8+ chars)
elif [[ "${PATTERN_LEN}" -ge 8 ]] && echo "${PATTERN}" | grep -Eq '^(get|set|load|save|delete|update|create|fetch|handle|perform|apply|cancel|remove|insert|process|configure|validate|present|dismiss|navigate|register|execute|observe|subscribe|toggle|enable|disable|refresh|compute|resolve|format|parse|encode|decode|convert|display|render|animate|trigger|dispatch|prepare|complete|request|respond|reset|release|suspend|resume|connect|disconnect|upload|download)[A-Z]'; then
  IS_FUNCTION_SEARCH=true
fi

if [[ "${IS_FUNCTION_SEARCH}" = true ]]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Use semantic search instead of Grep for function/symbol searches.\n\nAvailable modes:\n- listall_call_graph(symbol:, mode: \"callers\") — who calls this\n- listall_call_graph(symbol:, mode: \"references\") — all usages\n- listall_call_graph(symbol:, mode: \"definition\") — find definitions\n- listall_call_graph(symbol:, mode: \"graph\") — full call graph\n\nIf semantic tools failed (index unavailable), run: touch .claude/.grep-fallback-authorized\nThen retry Grep. Fallback expires after 5 minutes."
    }
  }'
  exit 0
fi

# Everything else: ALLOW
exit 0
