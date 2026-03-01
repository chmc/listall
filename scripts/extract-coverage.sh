#!/usr/bin/env bash
#
# extract-coverage.sh — Extract code coverage from an xcresult bundle
#
# Usage: extract-coverage.sh <xcresult-path> [coverage-json-output-path]
#
# Extracts coverage via xccov, filters to project source files,
# writes a markdown summary to $GITHUB_STEP_SUMMARY, and optionally
# saves the raw coverage JSON for artifact upload.
#
set -euo pipefail

XCRESULT_PATH="${1:?Usage: extract-coverage.sh <xcresult-path> [coverage-json-output]}"
COVERAGE_JSON_OUTPUT="${2:-coverage.json}"

if [[ ! -d "${XCRESULT_PATH}" ]]; then
  echo "::error::xcresult bundle not found: ${XCRESULT_PATH}"
  exit 1
fi

echo "Extracting coverage from: ${XCRESULT_PATH}"

# Extract raw coverage JSON
xcrun xccov view --report --json "${XCRESULT_PATH}" > "${COVERAGE_JSON_OUTPUT}"

if [[ ! -s "${COVERAGE_JSON_OUTPUT}" ]]; then
  echo "::warning::Coverage report is empty — code coverage may not have been enabled"
  exit 0
fi

# Use python3 (available on all GitHub macOS runners) to parse and format
python3 - "${COVERAGE_JSON_OUTPUT}" <<'PYEOF'
import json
import sys
import os

coverage_path = sys.argv[1]

with open(coverage_path) as f:
    data = json.load(f)

# Filter targets to project source files only
# Exclude Apple frameworks, system libs, test bundles, and third-party packages
EXCLUDE_PREFIXES = (
    "/Applications/Xcode",
    "/usr/",
    "/System/",
    "/Library/",
)
EXCLUDE_SUFFIXES = (
    "Tests.swift",
    "UITests.swift",
    "LaunchTests.swift",
)

targets = data.get("targets", [])

# Collect all project source files across targets
project_files = []
for target in targets:
    target_name = target.get("name", "")
    # Skip test targets entirely
    if "Tests" in target_name or "UITest" in target_name:
        continue

    for file_info in target.get("files", []):
        file_path = file_info.get("path", "")

        # Skip non-project files
        if any(file_path.startswith(p) for p in EXCLUDE_PREFIXES):
            continue
        if any(file_path.endswith(s) for s in EXCLUDE_SUFFIXES):
            continue

        # Extract just the filename for display
        filename = os.path.basename(file_path)
        line_coverage = file_info.get("lineCoverage", 0)
        covered_lines = file_info.get("coveredLines", 0)
        executable_lines = file_info.get("executableLines", 0)

        # Skip files with no executable lines
        if executable_lines == 0:
            continue

        project_files.append({
            "name": filename,
            "path": file_path,
            "line_coverage": line_coverage,
            "covered_lines": covered_lines,
            "executable_lines": executable_lines,
        })

# Sort by coverage ascending (worst coverage first for visibility)
project_files.sort(key=lambda f: f["line_coverage"])

# Calculate overall stats
total_covered = sum(f["covered_lines"] for f in project_files)
total_executable = sum(f["executable_lines"] for f in project_files)
overall_pct = (total_covered / total_executable * 100) if total_executable > 0 else 0

# Write markdown to GITHUB_STEP_SUMMARY
summary_path = os.environ.get("GITHUB_STEP_SUMMARY", "")
if not summary_path:
    # Fallback: print to stdout if not in GitHub Actions
    output = sys.stdout
else:
    output = open(summary_path, "a")

output.write("\n### Code Coverage\n\n")
output.write(f"**Overall: {overall_pct:.1f}%** ({total_covered}/{total_executable} lines)\n\n")

if project_files:
    # Show top 10 lowest-coverage files and top 5 highest
    LOW_COUNT = 10
    HIGH_COUNT = 5

    output.write("<details>\n<summary>Lowest coverage files</summary>\n\n")
    output.write("| File | Coverage | Lines |\n")
    output.write("|------|----------|-------|\n")
    for f in project_files[:LOW_COUNT]:
        pct = f["line_coverage"] * 100
        output.write(f"| {f['name']} | {pct:.1f}% | {f['covered_lines']}/{f['executable_lines']} |\n")
    output.write("\n</details>\n\n")

    output.write("<details>\n<summary>Highest coverage files</summary>\n\n")
    output.write("| File | Coverage | Lines |\n")
    output.write("|------|----------|-------|\n")
    for f in reversed(project_files[-HIGH_COUNT:]):
        pct = f["line_coverage"] * 100
        output.write(f"| {f['name']} | {pct:.1f}% | {f['covered_lines']}/{f['executable_lines']} |\n")
    output.write("\n</details>\n\n")

    output.write(f"Total files: {len(project_files)}\n")

if summary_path:
    output.close()

# Also print summary to build log
print(f"Coverage: {overall_pct:.1f}% ({total_covered}/{total_executable} lines, {len(project_files)} files)")
PYEOF

echo "Coverage JSON saved to: ${COVERAGE_JSON_OUTPUT}"
