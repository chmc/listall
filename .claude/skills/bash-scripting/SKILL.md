---
name: bash-scripting
description: Defensive Bash scripting patterns for CI/CD pipelines. Use when writing shell scripts, reviewing .sh files, or debugging script issues.
---

# Bash Scripting Best Practices

## Script Header

Always start with strict mode:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e` (errexit): Exit on any command failure
- `set -u` (nounset): Exit on undefined variable reference
- `set -o pipefail`: Exit on pipe failures, not just last command

## Variable Handling

### Patterns
```bash
# Always quote variables
echo "${var}"

# Default values
local file_path="${1:-default.txt}"

# Required variables
local input="${1:?Error: input required}"

# Readonly constants
readonly CONFIG_FILE="config.yml"

# Local in functions
local result=""
```

### Antipatterns
```bash
# BAD: Unquoted
echo $var

# BAD: No default handling
process "$1"  # Crashes if $1 missing
```

## Error Handling

### Cleanup with Traps
```bash
cleanup() {
    local exit_code=$?
    rm -f "${TEMP_FILE:-}"
    exit "${exit_code}"
}
trap cleanup EXIT ERR INT TERM
```

### Meaningful Exit Codes
```bash
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_FILE_NOT_FOUND=2
readonly EXIT_PERMISSION_DENIED=3
```

## Temporary Files

```bash
TEMP_FILE=$(mktemp)
trap 'rm -f "${TEMP_FILE}"' EXIT

# Use the temp file safely
echo "data" > "${TEMP_FILE}"
```

## Conditionals

```bash
# Use [[ ]] for Bash conditionals
if [[ "${status}" == "success" ]]; then
    # ...
fi

# Numeric comparison
if [[ "${count}" -gt 0 ]]; then
    # ...
fi

# File tests
if [[ -f "${file}" && -r "${file}" ]]; then
    # ...
fi

# Empty/non-empty checks
if [[ -z "${var}" ]]; then  # empty
if [[ -n "${var}" ]]; then  # non-empty
```

## Logging

```bash
log_info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log_warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }
```

## Input Validation

```bash
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <input_file>" >&2
        exit 1
    fi

    local input_file="$1"

    if [[ ! -f "${input_file}" ]]; then
        echo "Error: File not found: ${input_file}" >&2
        exit 1
    fi

    # ... rest of script
}
main "$@"
```

## macOS/BSD Compatibility

```bash
# sed -i requires backup extension on macOS
sed -i '' 's/foo/bar/' file.txt  # macOS
sed -i 's/foo/bar/' file.txt      # Linux

# date format differs
date -u +%Y-%m-%dT%H:%M:%SZ      # Both
date -d "1 day ago"              # GNU only
date -v-1d                       # BSD only
```

## Antipatterns

### Missing Safety
```bash
# BAD
#!/bin/bash
cd /some/dir
rm -rf *

# GOOD
#!/usr/bin/env bash
set -euo pipefail
cd /some/dir || exit 1
rm -rf ./*
```

### Parsing ls Output
```bash
# BAD: Breaks on spaces
for file in $(ls *.txt); do

# GOOD: Use glob directly
for file in *.txt; do
    [[ -f "${file}" ]] || continue
```

### Using eval
```bash
# BAD: Security risk
eval "$user_input"

# GOOD: Use arrays
declare -a cmd=("$@")
"${cmd[@]}"
```

## Code Review Checklist

1. **HEADER**: Uses `#!/usr/bin/env bash` and `set -euo pipefail`
2. **QUOTING**: All variables properly quoted
3. **VALIDATION**: Inputs validated at entry point
4. **ERRORS**: Exit codes documented and meaningful
5. **CLEANUP**: Traps for cleanup on exit/error
6. **TEMP FILES**: Uses mktemp, cleaned up
7. **LOGGING**: Errors to stderr, consistent format
8. **HELP**: --help option with usage examples
9. **SHELLCHECK**: Passes without warnings
10. **PORTABILITY**: BSD/GNU differences handled if needed
