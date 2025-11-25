#!/bin/bash
set -euo pipefail

# Generate CI pipeline health dashboard
# Usage: generate-dashboard.sh [--output FILE] [--format html|markdown]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
OUTPUT_FILE="ci-dashboard.html"
FORMAT="html"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--output FILE] [--format html|markdown]"
            echo ""
            echo "Generate CI pipeline health dashboard."
            echo ""
            echo "Options:"
            echo "  --output FILE     Output file (default: ci-dashboard.html)"
            echo "  --format FORMAT   Output format: html or markdown (default: html)"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info "Generating CI dashboard..."

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not installed" >&2
    exit 1
fi

# Fetch data
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
RECENT_RUNS=$(gh run list --workflow=prepare-appstore.yml --limit 10 --json databaseId,number,status,conclusion,createdAt,headBranch,event 2>/dev/null || echo '[]')

# Load performance history if exists
PERF_FILE=".github/performance-history.csv"
PERFORMANCE_DATA=""
if [ -f "$PERF_FILE" ]; then
    PERFORMANCE_DATA=$(tail -n 10 "$PERF_FILE" | tail -n +2)
fi

# Calculate success rate
TOTAL_RUNS=$(echo "$RECENT_RUNS" | jq 'length')
SUCCESS_RUNS=$(echo "$RECENT_RUNS" | jq '[.[] | select(.conclusion == "success")] | length')
SUCCESS_RATE=0
if [ $TOTAL_RUNS -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_RUNS * 100) / $TOTAL_RUNS}")
fi

# Get latest run info
LATEST_RUN=$(echo "$RECENT_RUNS" | jq '.[0]')
LATEST_STATUS=$(echo "$LATEST_RUN" | jq -r '.status // "unknown"')
LATEST_CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion // "unknown"')
LATEST_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId // ""')

# Generate dashboard based on format
if [ "$FORMAT" == "markdown" ]; then
    # Markdown format
    cat > "$OUTPUT_FILE" <<EOF
# CI Pipeline Dashboard

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Repository:** $REPO

---

## 📊 Current Status

| Metric | Value |
|--------|-------|
| Latest Run | #$LATEST_ID |
| Status | $LATEST_STATUS |
| Conclusion | $LATEST_CONCLUSION |
| Success Rate (Last 10) | ${SUCCESS_RATE}% ($SUCCESS_RUNS/$TOTAL_RUNS) |

---

## 📈 Recent Runs

| Run # | Status | Conclusion | Branch | Trigger | Date |
|-------|--------|------------|--------|---------|------|
EOF

    echo "$RECENT_RUNS" | jq -r '.[] | "\(.number) | \(.status) | \(.conclusion // "N/A") | \(.headBranch) | \(.event) | \(.createdAt | split("T")[0])"' >> "$OUTPUT_FILE"

    if [ -n "$PERFORMANCE_DATA" ]; then
        cat >> "$OUTPUT_FILE" <<EOF

---

## ⏱️ Performance History

| Run ID | Date | iPhone (s) | iPad (s) | Watch (s) | Total (s) |
|--------|------|------------|----------|-----------|-----------|
EOF

        echo "$PERFORMANCE_DATA" | while IFS=, read -r run_id date status iphone ipad watch total conclusion; do
            echo "| $run_id | $date | $iphone | $ipad | $watch | $total |" >> "$OUTPUT_FILE"
        done
    fi

    cat >> "$OUTPUT_FILE" <<EOF

---

## 🛠️ Quick Links

- [Workflow Runs](https://github.com/$REPO/actions/workflows/prepare-appstore.yml)
- [Troubleshooting Guide](.github/workflows/TROUBLESHOOTING.md)
- [Development Guide](.github/DEVELOPMENT.md)
- [Quick Reference](.github/QUICK_REFERENCE.md)

---

**Last Updated:** $(date '+%Y-%m-%d %H:%M:%S')
EOF

else
    # HTML format
    cat > "$OUTPUT_FILE" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CI Pipeline Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .header {
            background: white;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        h1 {
            color: #1a202c;
            margin-bottom: 8px;
        }

        .meta {
            color: #718096;
            font-size: 14px;
        }

        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }

        .card {
            background: white;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        .card h2 {
            color: #1a202c;
            font-size: 18px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #e2e8f0;
        }

        .metric:last-child {
            border-bottom: none;
        }

        .metric-label {
            color: #718096;
            font-size: 14px;
        }

        .metric-value {
            color: #1a202c;
            font-weight: 600;
            font-size: 16px;
        }

        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .status-success {
            background: #c6f6d5;
            color: #22543d;
        }

        .status-failure {
            background: #fed7d7;
            color: #742a2a;
        }

        .status-in-progress {
            background: #feebc8;
            color: #7c2d12;
        }

        .status-cancelled {
            background: #e2e8f0;
            color: #2d3748;
        }

        .runs-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 16px;
        }

        .runs-table th {
            text-align: left;
            padding: 12px;
            background: #f7fafc;
            color: #718096;
            font-size: 12px;
            text-transform: uppercase;
            font-weight: 600;
        }

        .runs-table td {
            padding: 12px;
            border-bottom: 1px solid #e2e8f0;
            font-size: 14px;
        }

        .runs-table tr:last-child td {
            border-bottom: none;
        }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 8px;
        }

        .progress-fill {
            height: 100%;
            background: #48bb78;
            transition: width 0.3s;
        }

        .chart {
            height: 200px;
            margin-top: 16px;
        }

        .links {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            margin-top: 16px;
        }

        .link-button {
            display: inline-block;
            padding: 8px 16px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            transition: background 0.2s;
        }

        .link-button:hover {
            background: #5a67d8;
        }

        .emoji {
            font-size: 20px;
        }

        footer {
            text-align: center;
            color: white;
            margin-top: 40px;
            padding: 20px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 CI Pipeline Dashboard</h1>
            <div class="meta">
EOF

    # Insert dynamic data
    cat >> "$OUTPUT_FILE" <<EOF
                <strong>Repository:</strong> $REPO<br>
                <strong>Generated:</strong> $(date '+%Y-%m-%d %H:%M:%S')
EOF

    cat >> "$OUTPUT_FILE" <<'EOF'
            </div>
        </div>

        <div class="dashboard">
            <!-- Current Status -->
            <div class="card">
                <h2><span class="emoji">📊</span> Current Status</h2>
EOF

    # Insert latest run status
    STATUS_CLASS="status-in-progress"
    case "$LATEST_CONCLUSION" in
        success) STATUS_CLASS="status-success" ;;
        failure) STATUS_CLASS="status-failure" ;;
        cancelled) STATUS_CLASS="status-cancelled" ;;
    esac

    cat >> "$OUTPUT_FILE" <<EOF
                <div class="metric">
                    <span class="metric-label">Latest Run</span>
                    <span class="metric-value">#$LATEST_ID</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="status-badge $STATUS_CLASS">$LATEST_CONCLUSION</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Success Rate (Last 10)</span>
                    <span class="metric-value">${SUCCESS_RATE}%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${SUCCESS_RATE}%"></div>
                </div>
EOF

    cat >> "$OUTPUT_FILE" <<'EOF'
            </div>

            <!-- Quick Stats -->
            <div class="card">
                <h2><span class="emoji">📈</span> Statistics</h2>
EOF

    cat >> "$OUTPUT_FILE" <<EOF
                <div class="metric">
                    <span class="metric-label">Total Runs (Last 10)</span>
                    <span class="metric-value">$TOTAL_RUNS</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Successful</span>
                    <span class="metric-value" style="color: #22543d;">$SUCCESS_RUNS</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Failed</span>
                    <span class="metric-value" style="color: #742a2a;">$(($TOTAL_RUNS - $SUCCESS_RUNS))</span>
                </div>
EOF

    cat >> "$OUTPUT_FILE" <<'EOF'
            </div>
        </div>

        <!-- Recent Runs -->
        <div class="card">
            <h2><span class="emoji">🔄</span> Recent Runs</h2>
            <table class="runs-table">
                <thead>
                    <tr>
                        <th>Run #</th>
                        <th>Branch</th>
                        <th>Status</th>
                        <th>Date</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Insert run rows
    echo "$RECENT_RUNS" | jq -r '.[] | @json' | while IFS= read -r run; do
        RUN_NUM=$(echo "$run" | jq -r '.number')
        BRANCH=$(echo "$run" | jq -r '.headBranch')
        STATUS=$(echo "$run" | jq -r '.conclusion // .status')
        DATE=$(echo "$run" | jq -r '.createdAt | split("T")[0]')

        STATUS_CLASS="status-in-progress"
        case "$STATUS" in
            success) STATUS_CLASS="status-success" ;;
            failure) STATUS_CLASS="status-failure" ;;
            cancelled) STATUS_CLASS="status-cancelled" ;;
        esac

        cat >> "$OUTPUT_FILE" <<EOF
                    <tr>
                        <td>#$RUN_NUM</td>
                        <td>$BRANCH</td>
                        <td><span class="status-badge $STATUS_CLASS">$STATUS</span></td>
                        <td>$DATE</td>
                    </tr>
EOF
    done

    cat >> "$OUTPUT_FILE" <<'EOF'
                </tbody>
            </table>
        </div>

        <!-- Quick Links -->
        <div class="card">
            <h2><span class="emoji">🔗</span> Quick Links</h2>
            <div class="links">
EOF

    cat >> "$OUTPUT_FILE" <<EOF
                <a href="https://github.com/$REPO/actions/workflows/prepare-appstore.yml" class="link-button">View Workflow Runs</a>
                <a href="https://github.com/$REPO/blob/main/.github/workflows/TROUBLESHOOTING.md" class="link-button">Troubleshooting</a>
                <a href="https://github.com/$REPO/blob/main/.github/DEVELOPMENT.md" class="link-button">Development Guide</a>
                <a href="https://github.com/$REPO/blob/main/.github/QUICK_REFERENCE.md" class="link-button">Quick Reference</a>
EOF

    cat >> "$OUTPUT_FILE" <<'EOF'
            </div>
        </div>
    </div>

    <footer>
        Generated by CI Dashboard Tool • Last Updated:
EOF

    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"

    cat >> "$OUTPUT_FILE" <<'EOF'
    </footer>
</body>
</html>
EOF

fi

print_success "Dashboard generated: $OUTPUT_FILE"

if [ "$FORMAT" == "html" ]; then
    print_info "Open in browser: open $OUTPUT_FILE"
fi

exit 0
