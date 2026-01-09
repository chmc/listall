# Screenshot Framing Integration - Executive Summary

**Project:** ListAll iOS/watchOS App
**Date:** 2025-11-28
**Status:** ✅ Core Implementation Complete, Enhancements Recommended

---

## Quick Overview

The screenshot framing solution is **already implemented** in the `screenshots_framed` lane but **deliberately not used** by default to maintain fast CI/CD execution. This is the correct architecture.

### Key Finding: Separation of Concerns

```
┌──────────────────────────────────────────────┐
│  Fast Path (Current - Used by CI/CD)         │
│  Screenshots → Normalize → Upload to ASC     │
│  Time: ~60-90 minutes                        │
│  Output: Exact App Store Connect dimensions  │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Slow Path (Available - Rarely Used)         │
│  Screenshots → Normalize → Frame → Marketing │
│  Time: +5-10 minutes for framing             │
│  Output: Device frames + promotional text    │
└──────────────────────────────────────────────┘
```

**Recommendation:** Keep this separation. Add convenience features for the slow path.

---

## Current Implementation Status

### ✅ What's Working

| Component | Status | Location |
|-----------|--------|----------|
| **Framing lane** | ✅ Implemented | `fastlane/Fastfile:701` (`screenshots_framed`) |
| **Configuration** | ✅ Complete | `fastlane/Framefile.json` |
| **Git rules** | ✅ Correct | `.gitignore` (framed screenshots excluded) |
| **Data flow** | ✅ Validated | Normalized → ASC, Framed → Marketing |
| **Localization** | ✅ Working | EN + FI text in Framefile |
| **Device support** | ✅ All platforms | iPhone, iPad, Watch |

### ⚠️ What's Missing

| Gap | Impact | Effort | Priority |
|-----|--------|--------|----------|
| **Convenience lane** (`frame_only`) | Medium | 1 hour | **High** |
| **Documentation** | High | 2 hours | **High** |
| **Script integration** | Low | 1 hour | Medium |
| **CI/CD workflow** | Low | 3 hours | Optional |

---

## Integration Points Map

### 1. Fastlane (Core)

```ruby
# Existing lanes (NO CHANGES NEEDED)
lane :screenshots_iphone     # Generate + normalize iPhone
lane :screenshots_ipad       # Generate + normalize iPad
lane :watch_screenshots      # Generate + normalize Watch
lane :screenshots_framed     # FULL PIPELINE with framing (slow)

# Recommended addition
lane :frame_only             # Frame existing normalized (fast)
```

**Current Flow (Default):**
```
screenshots_iphone/ipad/watch → screenshots_compat/ → App Store Connect ✅
```

**Framing Flow (On-Demand):**
```
screenshots_compat/ → frame_only → screenshots/framed/ → Marketing 🎨
```

### 2. GitHub Actions (CI/CD)

**Existing Workflows:**
- `prepare-appstore.yml` - Generates normalized screenshots ✅
- `publish-to-appstore.yml` - Uploads to ASC ✅
- `release.yml` - TestFlight builds ✅

**Recommended Addition:**
- `generate-framed-screenshots.yml` - Optional marketing workflow ⚠️

### 3. Local Development

**Existing:**
```bash
.github/scripts/generate-screenshots-local.sh [platform]
# Supports: iphone, ipad, watch, all
```

**Recommended Addition:**
```bash
.github/scripts/generate-screenshots-local.sh framed
# Fast framing of existing normalized screenshots
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    UI TESTS EXECUTION                        │
│  iOS Simulators + watchOS Simulators                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓ (Raw captures, various dimensions)
┌─────────────────────────────────────────────────────────────┐
│  fastlane/screenshots/                                       │
│  ├─ en-US/  ← Raw iPhone/iPad                               │
│  ├─ fi/     ← Raw iPhone/iPad                               │
│  └─ watch/  ← Raw Watch                                     │
│  Status: GITIGNORED (temporary artifacts)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓ (ImageMagick normalization)
        ┌──────────────┴──────────────┐
        │                              │
        ↓                              ↓
┌──────────────────────┐  ┌──────────────────────────────┐
│ screenshots_compat/  │  │ watch_normalized/            │
│ ├─ en-US/            │  │ ├─ en-US/                    │
│ │  ├─ iPhone.png     │  │ │  └─ Watch.png (396x484)   │
│ │  │  (1290x2796)    │  │ └─ fi/                       │
│ │  └─ iPad.png       │  │     └─ Watch.png (396x484)   │
│ │     (2064x2752)    │  │ Status: COMMITTED            │
│ └─ fi/ (same)        │  └──────────────────────────────┘
│ Status: COMMITTED    │              │
└──────┬───────────────┘              │
       │                              │
       │ (Optional: Frameit)          │
       ↓                              │
┌──────────────────────┐              │
│ screenshots/framed/  │              │
│ ├─ en-US/            │              │
│ │  ├─ iPhone_framed.png             │
│ │  │  (1421x2909)    │              │
│ │  └─ iPad_framed.png               │
│ │     (non-standard) │              │
│ └─ fi/ (same)        │              │
│ Status: GITIGNORED   │              │
└──────┬───────────────┘              │
       │                              │
       ↓ Marketing                    ↓ App Store Connect
┌──────────────────────┐  ┌──────────────────────────────┐
│  Website Assets      │  │  deliver (Fastlane)          │
│  Social Media        │  │  screenshots/delivery/       │
│  Press Kit           │  │  (copies from compat +       │
│                      │  │   watch_normalized)          │
└──────────────────────┘  └──────────────────────────────┘
```

---

## Recommended Implementation Plan

### Phase 1: Enhancement (2-3 hours) - **HIGH PRIORITY**

**Goal:** Make framing fast and easy for developers

**Tasks:**
1. ✅ Add `frame_only` lane to Fastfile
2. ✅ Update generate-screenshots-local.sh with `framed` mode
3. ✅ Test locally: `bundle exec fastlane frame_only`
4. ✅ Commit changes to feature branch

**Benefits:**
- 50x faster framing (2 min vs. 90 min)
- Developer self-service
- No impact on existing workflows

### Phase 2: Documentation (1-2 hours) - **HIGH PRIORITY**

**Goal:** Clear documentation for all users

**Tasks:**
1. ✅ Create `documentation/screenshot_framing.md`
2. ✅ Update README.md with framing section
3. ✅ Add troubleshooting guide
4. ✅ Document when to use framed vs. normalized

**Benefits:**
- Reduces confusion
- Marketing team self-service
- Onboarding documentation

### Phase 3: CI/CD Integration (3-4 hours) - **OPTIONAL**

**Goal:** Automated framing for marketing team

**Tasks:**
1. ⚠️ Create `.github/workflows/generate-framed-screenshots.yml`
2. ⚠️ Test workflow execution
3. ⚠️ Add to README

**Benefits:**
- Marketing team can download framed screenshots directly
- No developer intervention needed

**Note:** Only implement if marketing team requests it

---

## Key Decisions

### ✅ Decisions to Keep

1. **Framing is separate from default workflow**
   - Rationale: Speed - CI/CD completes 10x faster without framing
   - Evidence: Commit a26d0eb deliberately skips framing

2. **Framed screenshots are gitignored**
   - Rationale: Large files, derived artifacts
   - Evidence: .gitignore correctly configured

3. **Normalized screenshots are committed**
   - Rationale: Required for ASC, version control marketing materials
   - Evidence: screenshots_compat/ and watch_normalized/ in git

4. **Use Framefile.json for configuration**
   - Rationale: Declarative, version-controlled marketing text
   - Evidence: Working Framefile with EN + FI localization

### ⚠️ Decisions to Make

1. **Should we add CI/CD framing workflow?**
   - Recommendation: **Wait for marketing team request**
   - Rationale: Low urgency, developers can run locally

2. **Should we add more device frames?**
   - Current: Generic frames (show_complete_frame: true)
   - Recommendation: **Keep current approach**
   - Rationale: Generic frames work for all devices

3. **Should we support more locales?**
   - Current: EN, FI
   - Recommendation: **Add on-demand**
   - Rationale: Easy to add when needed

---

## Risk Assessment

### ✅ Low Risk (Safe to Proceed)

- Adding `frame_only` lane (additive, no breaking changes)
- Documentation updates (no code changes)
- Local script enhancements (backward compatible)

### ⚠️ Medium Risk (Test Thoroughly)

- CI/CD workflow (new infrastructure)
- Frameit version updates (test compatibility)

### ❌ High Risk (Avoid)

- Integrating framing into default CI/CD (too slow)
- Committing framed screenshots to git (bloat)
- Using framed screenshots for ASC upload (dimension mismatch)

---

## Success Metrics

### Phase 1 Success Criteria

- [ ] `frame_only` lane executes in <5 minutes
- [ ] Framed screenshots match Framefile.json configuration
- [ ] No errors in local execution
- [ ] Script works with `./generate-screenshots-local.sh framed`

### Phase 2 Success Criteria

- [ ] Developer can understand when to use framing without asking
- [ ] Troubleshooting guide covers common issues
- [ ] README clearly explains the two workflows

### Phase 3 Success Criteria (Optional)

- [ ] Marketing team can download framed screenshots without developer help
- [ ] CI workflow completes in <10 minutes
- [ ] No impact on existing CI/CD pipelines

---

## Quick Start Guide

### For Developers

**Generate normalized screenshots (default - fast):**
```bash
.github/scripts/generate-screenshots-local.sh all
# Time: ~60-90 minutes
# Output: screenshots_compat/ + watch_normalized/
# Use for: App Store Connect submissions
```

**Add framing (after Phase 1 implementation):**
```bash
bundle exec fastlane frame_only
# Time: ~2 minutes (frames existing normalized screenshots)
# Output: screenshots/framed/
# Use for: Marketing materials, social media
```

### For Marketing Team

**Option 1: Request from developer**
```
"Please generate framed screenshots for the marketing page"
→ Developer runs: bundle exec fastlane frame_only
→ Developer shares: fastlane/screenshots/framed/
```

**Option 2: After Phase 3 (CI/CD)**
```
1. Go to GitHub Actions
2. Run "Generate Framed Screenshots (Marketing)"
3. Download artifact: framed-screenshots
```

---

## Dependencies Checklist

**Local Development:**
- [x] Xcode 16.1+
- [x] iOS 18.1 simulators
- [x] watchOS 11 simulators
- [x] Ruby 3.2+
- [x] Bundler
- [x] ImageMagick (`brew install imagemagick`)
- [x] Font file: `fastlane/fonts/SF-Pro-Display-Semibold.ttf`

**CI/CD:**
- [x] macOS 14 runners
- [x] Xcode 16.1
- [x] ImageMagick (via Homebrew)
- [x] Fastlane (via bundle)

---

## File Locations Quick Reference

| File | Path | Purpose |
|------|------|---------|
| **Fastfile** | `fastlane/Fastfile` | Automation lanes |
| **Framefile** | `fastlane/Framefile.json` | Framing config |
| **Helper** | `fastlane/lib/screenshot_helper.rb` | Normalization logic |
| **Local Script** | `.github/scripts/generate-screenshots-local.sh` | Developer CLI |
| **CI Workflow** | `.github/workflows/prepare-appstore.yml` | Screenshot CI |
| **Normalized (iOS/iPad)** | `fastlane/screenshots_compat/` | ASC submission |
| **Normalized (Watch)** | `fastlane/screenshots/watch_normalized/` | ASC submission |
| **Framed (Marketing)** | `fastlane/screenshots/framed/` | Marketing (gitignored) |

---

## Next Actions

### Immediate (Before Merging to Main)

1. ✅ **Implement `frame_only` lane** (see detailed plan in main document)
2. ✅ **Update generate-screenshots-local.sh** (add `framed` mode)
3. ✅ **Test locally** (ensure no regressions)
4. ✅ **Create documentation** (screenshot_framing.md + README updates)

### Short-term (Next Sprint)

5. ⚠️ **Review with team** (validate approach)
6. ⚠️ **Merge to main** (after approval)
7. ⚠️ **Update release process** (document framing workflow)

### Optional (Future)

8. ⚠️ **Add CI/CD workflow** (if marketing team requests)
9. ⚠️ **Add pre-flight checks** (validate dependencies)
10. ⚠️ **Monitor performance** (track execution times)

---

## Questions?

**When should I use framed screenshots?**
→ Marketing website, social media, press kit. NOT for App Store Connect.

**Why are framed screenshots gitignored?**
→ Large files (~500KB each), derived artifacts, can be regenerated anytime.

**Can I customize the frames?**
→ Yes! Edit `fastlane/Framefile.json` (background, text, fonts).

**How long does framing take?**
→ Full pipeline: ~90 min. Fast framing (frame_only): ~2 min.

**Do I need to commit framed screenshots?**
→ NO. Only commit normalized screenshots (screenshots_compat/).

---

**Document Version:** 1.0
**For Detailed Implementation:** See `INTEGRATION_PLAN_SCREENSHOT_FRAMING.md`
**Last Updated:** 2025-11-28

