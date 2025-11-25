# GitHub Workflows & CI Tooling

This directory contains GitHub Actions workflows, CI helper scripts, and development tools for the ListAll iOS app.

## 📁 Directory Structure

```
.github/
├── workflows/              # GitHub Actions workflows
│   ├── prepare-appstore.yml         # Main screenshot generation pipeline
│   └── TROUBLESHOOTING.md           # Comprehensive troubleshooting guide
├── scripts/                # CI helper scripts (14 total)
│   ├── test-pipeline-locally.sh     # Local CI simulator (3 modes)
│   ├── analyze-ci-failure.sh        # Automated log analysis
│   ├── compare-screenshots.sh       # Visual regression detection
│   ├── track-performance.sh         # Performance monitoring
│   ├── release-checklist.sh         # Release automation
│   ├── cleanup-artifacts.sh         # Artifact management
│   ├── track-ci-cost.sh             # Cost tracking
│   ├── generate-dashboard.sh        # Status dashboard
│   ├── find-simulator.sh            # Simulator discovery
│   ├── cleanup-watch-duplicates.sh  # Watch simulator cleanup
│   ├── validate-screenshots.sh      # Screenshot validation
│   ├── preflight-check.sh           # Environment validation
│   ├── completions.bash             # Tab completion
│   └── README.md                    # Scripts documentation
├── hooks/                  # Git hooks
│   └── pre-commit                   # Automated validation hook
├── DEVELOPMENT.md          # Local development guide
├── QUICK_REFERENCE.md      # One-page cheat sheet
└── README.md               # This file
```

## 🚀 Quick Start

**New to the project?** Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for a one-page cheat sheet!

**Want tab completion?** Run: `source .github/scripts/completions.bash`

### For Developers

**Before committing CI changes:**
```bash
# Fast validation (1-2s)
.github/scripts/test-pipeline-locally.sh --validate-only

# Quick test with simulator boot (10-15s)
.github/scripts/test-pipeline-locally.sh --quick
```

**Install pre-commit hook (optional):**
```bash
ln -sf ../../.github/hooks/pre-commit .git/hooks/pre-commit
```

### For Troubleshooting CI Failures

**Automatic diagnosis:**
```bash
# Analyze latest run
.github/scripts/analyze-ci-failure.sh --latest

# Analyze specific run
.github/scripts/analyze-ci-failure.sh 19667213668
```

**Manual troubleshooting:**
See [workflows/TROUBLESHOOTING.md](workflows/TROUBLESHOOTING.md)

### For Running Pipeline

**Trigger screenshot generation:**
```bash
gh workflow run prepare-appstore.yml -f version=1.2.0
```

**Monitor progress:**
```bash
gh run watch
```

### For Quality Assurance & Release

**Compare screenshots between runs:**
```bash
# Detect visual regressions
.github/scripts/compare-screenshots.sh <old-run> <new-run>
```

**Track performance:**
```bash
# Track latest run
.github/scripts/track-performance.sh --latest

# View history
.github/scripts/track-performance.sh --history 10
```

**Generate release checklist:**
```bash
# After successful pipeline
.github/scripts/release-checklist.sh --latest 1.2.0
```

## 📚 Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| [DEVELOPMENT.md](DEVELOPMENT.md) | Local testing workflow, debugging tips | Developers |
| [workflows/TROUBLESHOOTING.md](workflows/TROUBLESHOOTING.md) | CI failure diagnosis and fixes | Maintainers |
| [scripts/README.md](scripts/README.md) | Script reference documentation | Developers |

## 🛠️ Tools Overview

### Local Testing

**[test-pipeline-locally.sh](scripts/test-pipeline-locally.sh)**
- Simulates complete CI pipeline locally
- Three modes: validate-only (1-2s), quick (10-15s), full (60-90min)
- Catches issues before pushing to CI

### CI Diagnostics

**[analyze-ci-failure.sh](scripts/analyze-ci-failure.sh)**
- Automatically diagnoses pipeline failures
- Analyzes GitHub Actions logs
- Provides direct links to fixes

### Quality Assurance

**[compare-screenshots.sh](scripts/compare-screenshots.sh)**
- Compare screenshots between two CI runs
- Detect visual regressions automatically
- Generate diff images and reports
- Configurable difference threshold

**[track-performance.sh](scripts/track-performance.sh)**
- Track pipeline performance over time
- Detect performance degradation (>20%)
- Store historical metrics in CSV
- Warn when approaching timeouts

### Release Automation

**[release-checklist.sh](scripts/release-checklist.sh)**
- Generate comprehensive release checklist
- Validate pipeline completion
- Include all steps: pre-release to post-release
- Standardize release process

### Monitoring & Cost Management

**[generate-dashboard.sh](scripts/generate-dashboard.sh)**
- Generate visual HTML/markdown dashboard
- Show current pipeline status and health
- Recent runs table with success rates
- Performance history visualization

**[track-ci-cost.sh](scripts/track-ci-cost.sh)**
- Track GitHub Actions CI costs
- Calculate monthly usage and costs
- Project future expenses
- Check free tier utilization

**[cleanup-artifacts.sh](scripts/cleanup-artifacts.sh)**
- Clean up old artifacts (>30 days default)
- Save storage space (2GB limit)
- Dry-run mode for preview
- Automated maintenance

### Developer Experience

**[completions.bash](scripts/completions.bash)**
- Bash tab completion for all scripts
- Recent run ID suggestions
- Device name auto-complete
- Context-aware completions

**[QUICK_REFERENCE.md](QUICK_REFERENCE.md)**
- One-page cheat sheet
- All common commands
- Quick diagnosis steps
- Common workflows

### Git Hooks

**[pre-commit](hooks/pre-commit)**
- Optional git hook for automatic validation
- Runs on CI file changes only
- Prevents pushing broken code

### Helper Scripts

**[preflight-check.sh](scripts/preflight-check.sh)**
- Validates environment before 90min run
- Checks Xcode, simulators, dependencies
- Fails fast on configuration issues

**[find-simulator.sh](scripts/find-simulator.sh)**
- Reliable simulator discovery
- Prevents shell injection
- UUID validation

**[cleanup-watch-duplicates.sh](scripts/cleanup-watch-duplicates.sh)**
- Removes duplicate Watch simulators
- Prevents "multiple devices matched" errors

**[validate-screenshots.sh](scripts/validate-screenshots.sh)**
- Validates screenshot dimensions
- Checks for blank/corrupt images
- Ensures App Store requirements met

## 🔧 Workflow: prepare-appstore.yml

The main workflow for generating and uploading App Store screenshots.

### Jobs

1. **generate-iphone-screenshots** (20-24 min)
   - Generates iPhone 16 Pro Max screenshots
   - Normalizes to 1290x2796
   - Validates dimensions

2. **generate-ipad-screenshots** (18-20 min)
   - Generates iPad Pro 13" screenshots
   - Normalizes to 2064x2752
   - Validates dimensions

3. **generate-watch-screenshots** (16 min)
   - Generates Apple Watch Series 10 screenshots
   - Normalizes to 396x484
   - Validates dimensions

4. **upload-to-appstore** (5-10 min)
   - Merges all screenshots
   - Validates before upload
   - Uploads to App Store Connect

### Features

- ✅ **Parallel job execution** - All devices generate simultaneously
- ✅ **Pre-boot optimization** - 76% faster (iPad: 84min → 20min)
- ✅ **Fail-fast validation** - Catches issues at 1min instead of 90min
- ✅ **Retry logic** - 2 attempts per job with 30s backoff
- ✅ **Comprehensive validation** - Dimensions, format, content
- ✅ **Detailed diagnostics** - Logs and artifacts for debugging

### Performance

| Job | Duration | Timeout | Buffer |
|-----|----------|---------|--------|
| iPhone | 20-24 min | 90 min | 4x |
| iPad | 18-20 min | 120 min | 6x |
| Watch | 16 min | 90 min | 5.6x |
| **Total** | **~60 min** | **120 min** | **2x** |

### Reliability Improvements

Based on fixing 140 consecutive failures:

**Before hardening:**
- ❌ Silent failures masked issues
- ❌ Shell injection vulnerabilities
- ❌ Timeout at 93% capacity (iPad)
- ❌ No validation until upload
- ❌ Poor error messages

**After hardening:**
- ✅ Fail-fast validation at each stage
- ✅ Secure environment variable injection
- ✅ 76% performance improvement
- ✅ Screenshot validation before merge
- ✅ Comprehensive error handling
- ✅ Automated diagnosis tools

## 🎯 Best Practices

### Before Committing

1. Run local validation:
   ```bash
   .github/scripts/test-pipeline-locally.sh --quick
   ```

2. For major changes, run full test:
   ```bash
   .github/scripts/test-pipeline-locally.sh --full
   ```

3. Review changes against security checklist:
   - No shell injection vulnerabilities
   - Proper error handling
   - Input validation
   - Clear error messages

### When CI Fails

1. Run automated diagnosis:
   ```bash
   .github/scripts/analyze-ci-failure.sh --latest
   ```

2. Check linked troubleshooting sections

3. Test fix locally before retrying

4. If issue persists, check TROUBLESHOOTING.md

### Debugging Workflow

1. **Fast iteration:**
   - Use `--validate-only` for syntax checks
   - Use `--quick` for environment validation
   - Use `--full` only before releases

2. **CI debugging:**
   - Use analyzer for instant diagnosis
   - Check pre-flight logs first
   - Download xcresult artifacts for details

3. **Simulator issues:**
   - Clean state: `xcrun simctl shutdown all`
   - Delete unavailable: `xcrun simctl delete unavailable`
   - List available: `xcrun simctl list devices available`

## 📊 Monitoring

**Check workflow runs:**
```bash
# List recent runs
gh run list --workflow=prepare-appstore.yml --limit 5

# Watch current run
gh run watch

# View run details
gh run view <run-id> --web
```

**Analyze failures:**
```bash
# Auto-analyze
.github/scripts/analyze-ci-failure.sh <run-id>

# Download logs
gh run view <run-id> --log > run.log
```

**Quality monitoring:**
```bash
# Compare screenshots for regressions
.github/scripts/compare-screenshots.sh <baseline-run> <current-run>

# Track performance
.github/scripts/track-performance.sh --latest
.github/scripts/track-performance.sh --history 10
```

## 🔄 Change History

### 2025-11-25 - Major Reliability Overhaul + Advanced Tooling

**Fixes:**
- ✅ Fixed 140-attempt failure streak
- ✅ 11 CRITICAL/HIGH security bugs
- ✅ 4 MEDIUM robustness issues
- ✅ Shell injection vulnerabilities
- ✅ Silent failure modes
- ✅ Pre-boot optimization (76% faster)

**New Tools (14 total scripts + 1 hook):**

*Development:*
- ✅ Local CI simulator (test-pipeline-locally.sh) - 3 modes
- ✅ Pre-commit hook - Auto-validation
- ✅ Bash completion (completions.bash) - Tab completion

*Diagnostics:*
- ✅ Log analyzer (analyze-ci-failure.sh) - Auto-diagnosis

*Quality Assurance:*
- ✅ Screenshot comparison (compare-screenshots.sh) - Visual regression
- ✅ Performance tracking (track-performance.sh) - Metrics & trends

*Release:*
- ✅ Release checklist (release-checklist.sh) - Process automation

*Monitoring:*
- ✅ Status dashboard (generate-dashboard.sh) - HTML/markdown
- ✅ Cost tracking (track-ci-cost.sh) - Budget analysis
- ✅ Artifact cleanup (cleanup-artifacts.sh) - Storage management

*Infrastructure:*
- ✅ Simulator finder (find-simulator.sh) - Discovery
- ✅ Watch cleanup (cleanup-watch-duplicates.sh) - Duplicate removal
- ✅ Screenshot validator (validate-screenshots.sh) - Dimension check
- ✅ Pre-flight checker (preflight-check.sh) - Environment validation

**Documentation (2,500+ lines):**
- ✅ TROUBLESHOOTING.md (420 lines) - 140-failure analysis
- ✅ DEVELOPMENT.md (440 lines) - Local testing guide
- ✅ scripts/README.md (570 lines) - Complete tool reference
- ✅ .github/README.md (410 lines) - Infrastructure hub
- ✅ QUICK_REFERENCE.md (350 lines) - One-page cheat sheet
- ✅ All tools include --help documentation

## 🆘 Getting Help

1. **Quick issues:** Check [TROUBLESHOOTING.md](workflows/TROUBLESHOOTING.md)
2. **Development questions:** Check [DEVELOPMENT.md](DEVELOPMENT.md)
3. **Script usage:** Check [scripts/README.md](scripts/README.md)
4. **Automated diagnosis:** Run analyzer tool
5. **Still stuck:** File GitHub issue with analyzer output

## 🤝 Contributing

When modifying CI infrastructure:

1. ✅ Test locally first (`--quick` minimum)
2. ✅ Use feature branches
3. ✅ Run critical code review
4. ✅ Update relevant documentation
5. ✅ Verify CI passes before merging

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed guidelines.

---

**Last Updated:** 2025-11-25
**Maintainer:** @chmc
**Status:** ✅ Production-ready after comprehensive hardening

🤖 This infrastructure was built by analyzing and fixing 140 consecutive pipeline failures.
