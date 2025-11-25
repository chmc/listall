#!/bin/bash
# Bash completion for CI helper scripts
# Install: source .github/scripts/completions.bash
# Or add to ~/.bashrc: source /path/to/ListAllApp/.github/scripts/completions.bash

_test_pipeline_locally_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            COMPREPLY=( $(compgen -W "--full --quick --validate-only full quick validate" -- ${cur}) )
            ;;
    esac
}

_analyze_ci_failure_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            # Offer --latest or run IDs from recent runs
            local recent_runs=$(gh run list --workflow=prepare-appstore.yml --limit 5 --json databaseId --jq '.[].databaseId' 2>/dev/null || echo "")
            COMPREPLY=( $(compgen -W "--latest --stdin ${recent_runs}" -- ${cur}) )
            ;;
    esac
}

_compare_screenshots_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1|2)
            # Offer recent run IDs
            local recent_runs=$(gh run list --workflow=prepare-appstore.yml --limit 10 --json databaseId --jq '.[].databaseId' 2>/dev/null || echo "")
            COMPREPLY=( $(compgen -W "${recent_runs}" -- ${cur}) )
            ;;
        3)
            COMPREPLY=( $(compgen -W "--threshold" -- ${cur}) )
            ;;
    esac
}

_track_performance_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            local recent_runs=$(gh run list --workflow=prepare-appstore.yml --limit 10 --json databaseId --jq '.[].databaseId' 2>/dev/null || echo "")
            COMPREPLY=( $(compgen -W "--latest --history ${recent_runs}" -- ${cur}) )
            ;;
        2)
            if [ "$prev" == "--history" ]; then
                COMPREPLY=( $(compgen -W "5 10 20 30 50" -- ${cur}) )
            fi
            ;;
    esac
}

_release_checklist_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            local recent_runs=$(gh run list --workflow=prepare-appstore.yml --limit 10 --json databaseId --jq '.[].databaseId' 2>/dev/null || echo "")
            COMPREPLY=( $(compgen -W "--latest ${recent_runs}" -- ${cur}) )
            ;;
        2)
            # Suggest version format
            COMPREPLY=( $(compgen -W "1.0.0 1.1.0 1.2.0 2.0.0" -- ${cur}) )
            ;;
    esac
}

_find_simulator_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            COMPREPLY=( $(compgen -W "\"iPhone 16 Pro Max\" \"iPad Pro 13-inch (M4)\" \"Apple Watch Series 10 (46mm)\"" -- ${cur}) )
            ;;
        2)
            COMPREPLY=( $(compgen -W "iOS watchOS" -- ${cur}) )
            ;;
    esac
}

_validate_screenshots_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case ${COMP_CWORD} in
        1)
            # Offer directory completion
            COMPREPLY=( $(compgen -d -- ${cur}) )
            ;;
        2)
            COMPREPLY=( $(compgen -W "iphone ipad watch" -- ${cur}) )
            ;;
    esac
}

# Register completions
complete -F _test_pipeline_locally_completions test-pipeline-locally.sh
complete -F _test_pipeline_locally_completions .github/scripts/test-pipeline-locally.sh

complete -F _analyze_ci_failure_completions analyze-ci-failure.sh
complete -F _analyze_ci_failure_completions .github/scripts/analyze-ci-failure.sh

complete -F _compare_screenshots_completions compare-screenshots.sh
complete -F _compare_screenshots_completions .github/scripts/compare-screenshots.sh

complete -F _track_performance_completions track-performance.sh
complete -F _track_performance_completions .github/scripts/track-performance.sh

complete -F _release_checklist_completions release-checklist.sh
complete -F _release_checklist_completions .github/scripts/release-checklist.sh

complete -F _find_simulator_completions find-simulator.sh
complete -F _find_simulator_completions .github/scripts/find-simulator.sh

complete -F _validate_screenshots_completions validate-screenshots.sh
complete -F _validate_screenshots_completions .github/scripts/validate-screenshots.sh

# No args needed for these
complete -o default preflight-check.sh
complete -o default .github/scripts/preflight-check.sh
complete -o default cleanup-watch-duplicates.sh
complete -o default .github/scripts/cleanup-watch-duplicates.sh

echo "✅ CI scripts bash completion loaded"
echo "   Try: .github/scripts/<TAB><TAB>"
