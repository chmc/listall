---
title: macOS Screenshot Automation Reliability Fixes
date: 2025-12-20
severity: HIGH
category: fastlane
tags: [screenshots, tcc-permissions, applescript, process-termination, shell-scripting]
symptoms: [TCC errors silently ignored, apps not closing, screenshot automation fails]
root_cause: Silent stderr suppression hid TCC errors; process termination lacked verification
solution: Capture stderr with TCC detection; implement verified process termination with SIGTERM/SIGKILL
files_affected: [.github/scripts/generate-screenshots-local.sh, fastlane/Fastfile]
related: [xtest-nsapplescript-malloc-error.md, macos-screenshot-generation.md, macos-uitest-authorization-fix.md]
---

## Fixes Applied

### Fix 8.3: TCC Error Detection

**Problem**: `2>/dev/null || true` silently discarded TCC permission errors.

**Solution**: Helper function captures and checks stderr:

```bash
check_tcc_error() {
    local output="$1"
    local exit_code="$2"
    if [[ ${exit_code} -ne 0 ]]; then
        if [[ "${output}" == *"not authorized"* ]] || [[ "${output}" == *"(-1743)"* ]]; then
            log_warn "TCC Automation permissions may not be granted"
            log_warn "Fix: System Settings > Privacy & Security > Automation > Terminal/Xcode"
            return 1
        fi
    fi
    return 0
}

# Usage
output=$(osascript -e '...' 2>&1)
check_tcc_error "$output" $?
```

### Fix 8.4: Verified Process Termination

**Problem**: Apps not reliably terminating before screenshots.

**Solution**: Ruby helper with SIGTERM/SIGKILL and polling:

```ruby
def terminate_macos_app_verified(app_name)
  raise "Invalid app name" unless app_name =~ /\A[a-zA-Z0-9_-]+\z/

  system("pkill -SIGTERM #{app_name}")
  10.times do
    sleep(1)
    count = `pgrep #{app_name} | xargs ps -o state= 2>/dev/null | grep -v Z | wc -l`.to_i
    return true if count == 0
  end
  system("pkill -SIGKILL #{app_name}")
  true
end
```

## Bash Heredoc Gotcha

**Problem**: Apostrophe in heredoc inside `$()` causes parse error:
```bash
# BAD - "doesn't" breaks parsing
$(cat <<'EOF'
-- syntax doesn't work
EOF
)
```

**Solution**: Avoid contractions in heredocs within command substitution:
```bash
# GOOD
$(cat <<'EOF'
-- syntax does not work
EOF
)
```

## Defense in Depth Architecture

```
Layer 1: Shell (hide_and_quit_background_apps_macos)
    |
    v fails?
Layer 2: Swift (AppHidingScriptGenerator)
    |
    v fails?
Layer 3: Fallback (screenshot continues anyway)
```

## Verification

- 703 unit tests passing
- 4/4 screenshot tests passing
- `bash -n`, `shellcheck`, `ruby -c` all pass
