# Automation Roadmap (CI/CD, Screenshots, Releases)

Purpose: Implement end-to-end automation for ListAll (iOS + watchOS) using GitHub Actions (free) and Fastlane. Tasks are atomic, ordered, and small enough to fit into an AI assistant context.

Assumptions
- Public GitHub repo: https://github.com/chmc/listall
- Apple Developer Program active; App live (v1.0)
- Localization: en (default) and fi
- Xcode 16+, macOS runners (macos-14 or newer)
- Prefer Xcode automatic signing for now (no certs in repo). We'll use App Store Connect API key for uploads.

Outcomes
- CI on every push/PR: build + unit/UI tests
- Auto screenshots for EN + FI (fully automated, framed)
  - Initial scope: iPhone 6.5" Pro, iPad Pro 13" (M4), and watchOS
- TestFlight uploads on tag or manual dispatch
- App Store submission lane that bundles metadata + screenshots

---

## Phase 1 — Baseline CI on GitHub Actions

### ✅ 1.1 Add CI workflow (build + tests) - COMPLETED
- File: `.github/workflows/ci.yml`
- Steps:
  - Checkout
  - Select Xcode version (e.g., 16.x)
  - Cache DerivedData
  - Resolve SPM
  - Build and run tests for iOS (and any watch targets as needed)
  - Upload test results as artifact
- Acceptance
  - CI runs on PR and push to `main`
  - Green run on current `main`
  - Artifacts include XCTest logs and .xcresult
- **Status**: Implemented with iOS and watchOS build/test, includes caching (addresses 1.2 as well)

### ✅ 1.2 Speed up CI with caching - COMPLETED
- Add actions/cache for `~/Library/Developer/Xcode/DerivedData` and SPM (`~/.swiftpm`, `~/Library/Developer/Xcode/DerivedData/SourcePackages`)
- Acceptance
  - Subsequent runs show cache hits

### ✅ 1.3 Surface status in README - COMPLETED
- Add CI badge to `README.md`
- Acceptance
  - Badge shows current CI state
- **Status**: CI badge added to README showing workflow status

---

## Phase 2 — Fastlane bootstrap

### ✅ 2.1 Add Ruby toolchain - COMPLETED
Ruby toolchain (Gemfile, Gemfile.lock) with Fastlane and xcode-install is set up. `bundle exec fastlane --version` works locally.
- Files: `Gemfile`, `Gemfile.lock` (commit lockfile)
- Gems: `fastlane`, `xcode-install` (optional)
- Acceptance
  - `bundle exec fastlane --version` works locally

### ✅ 2.2 Create Fastlane skeleton - COMPLETED
- Files: `fastlane/Fastfile`, `fastlane/Appfile`
- Lanes (initial):
  - `test`: mirrors CI with xcodebuild build+test and non-failing exit (for parity); also provides `test_scan` lane using Fastlane Scan
  - `beta`: builds archive via `build_app` and conditionally uploads to TestFlight via `pilot` when `ASC_*` env vars are set
  - `release`: configures `deliver` guarded by App Store Connect API key (no auto-submit)
- Acceptance
  - `bundle exec fastlane test` runs locally (verified) and is CI-friendly (uses xcodebuild under the hood)
- Notes
  - Appfile prefilled with `app_identifier: io.github.chmc.ListAll` and `team_id: M9BR5FY93A`; set `apple_id` later in 2.3

### ✅ 2.3 Configure App Store Connect API key - COMPLETED
- Create API key in App Store Connect (Roles: `App Manager` or `Developer`)
- Store as GitHub Secrets (repository level):
  - `ASC_KEY_ID`
  - `ASC_ISSUER_ID`
  - `ASC_KEY_BASE64` (contents of .p8 base64-encoded)
- Update `Fastfile` to use `app_store_connect_api_key`
- Acceptance
  - `fastlane deliver` can auth non-interactively in CI (dry-run)

Implementation details (wired in repo)
- Fastlane now reads the API key from environment and authenticates automatically:
  - `fastlane/Fastfile`: `beta` and `release` lanes use `app_store_connect_api_key` when `ASC_*` are present
  - Added lane `asc_dry_run` to validate auth without uploading anything
  - `fastlane/Appfile`: supports `apple_id` via environment (`APPLE_ID`) if you want to set it locally/CI without committing email

Local setup (.env file approach)
- Created `.env.template` (tracked in git) with placeholder values
- Developers copy to `.env` (gitignored) and fill in actual credentials
- Fastlane automatically loads `.env` files - no manual export needed
- Test with: `bundle exec fastlane asc_dry_run`

CI usage (GitHub Secrets)
- Repository secrets configured:
  - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_BASE64` ✅
- Workflows can call `bundle exec fastlane beta` (uploads if secrets exist) or `bundle exec fastlane asc_dry_run` to check auth

**Status**: COMPLETED
- ✅ API key created in App Store Connect
- ✅ GitHub repository secrets configured
- ✅ Local .env setup with template file
- ✅ Fastlane authentication tested successfully (`asc_dry_run` passed)
- ✅ Documentation added to README.md

### ✅ 2.4 Tie Fastlane into CI - COMPLETED
- Add new workflow `.github/workflows/release.yml` with manual dispatch and on tag (e.g., `v*`)
- Jobs:
  - `tests`: run `fastlane test`
  - `beta`: run `fastlane beta` (on tag or manual)
- Acceptance
  - Manual `workflow_dispatch` works and uploads to TestFlight (once code signing is valid)

Implementation details (wired in repo)
- Created `.github/workflows/release.yml`
  - Triggers: `workflow_dispatch` and `push` on tags `v*`
  - Runner: `macos-14`, Xcode 16.1 selected to match CI
  - Ruby 3.2 pinned with Bundler 2.x (updated `Gemfile.lock` from legacy Bundler 1.17.2 to 2.5.19)
  - Job `tests`: sets up Ruby + Bundler cache and runs `bundle exec fastlane test`; uploads `fastlane/test_output` as artifact
  - Job `beta`: depends on `tests`, exports App Store Connect secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_BASE64`) to env and runs `bundle exec fastlane beta`; uploads any generated `.ipa/.xcarchive` artifacts from `ListAll/build`

CI usage
- Manually trigger "Release" workflow from GitHub Actions, or push a tag like `v1.1.0`
- With valid signing on the runner, `beta` will upload to TestFlight via API key

**Status**: COMPLETED
- ✅ Workflow added and configured
- ✅ Ruby/Bundler compatibility resolved (Ruby 3.2 + Bundler 2.x)
- ✅ Fastlane Match configured for code signing (certificate + provisioning profiles in private git repo)
- ✅ Build and upload to TestFlight working end-to-end
- ✅ Version numbering using `sed` to update all targets (main + watchOS)

### 2.5 Implement industry-standard version numbering
- Problem: Currently using hardcoded version (1.1) and `sed` command to update `MARKETING_VERSION` in project.pbxproj
- Goal: Adopt semantic versioning (SemVer: MAJOR.MINOR.PATCH) with automated increments
- Approach options:
  1. **Git tag-based**: Extract version from git tags (e.g., `v1.2.0`), auto-increment patch for builds
  2. **Config file**: Store version in dedicated file (e.g., `.version` or `fastlane/version.txt`), update via Fastlane
  3. **Fastlane actions**: Use `increment_version_number` with `bump_type` parameter properly configured for all targets
  4. **agvtool integration**: Configure project to work with Apple's agvtool for version management
- Tasks:
  - Research and decide on best approach for iOS/watchOS multi-target projects
  - Implement version increment strategy that:
    - Updates both main app and Watch app consistently
    - Supports semantic versioning (major.minor.patch)
    - Allows manual version bumps (major/minor) via workflow parameter
    - Auto-increments patch version for TestFlight builds
    - Works reliably with Xcode's `MARKETING_VERSION` build setting
  - Update `Fastfile` `beta` lane to use new versioning approach
  - Update GitHub workflow to accept version bump type as input (patch/minor/major)
  - Add validation to ensure all targets have matching version numbers
- Acceptance:
  - `bundle exec fastlane beta bump_type:patch` increments version correctly (e.g., 1.1.0 → 1.1.1)
  - Manual workflow dispatch allows choosing version bump type (patch/minor/major)
  - Both main app and Watch app targets get identical version numbers
  - Version increments are git-committed and tagged automatically
  - CI logs clearly show which version is being built
- Benefits:
  - Eliminates hardcoded version numbers in Fastfile
  - Enables proper release management with semantic versioning
  - Makes version history trackable via git tags
  - Industry-standard approach used by major iOS apps

---

## Phase 3 — Deterministic UI + Screenshot Automation (iPhone 6.5" + iPad 13")

### 3.1 Introduce deterministic UI test data
- App: enable a launch argument/env (e.g., `UITESTS_SEED=1`) to inject sample lists/items to a clean store (no iCloud sync during UITests)
- Wire in the app`s launch to check this flag and pre-populate consistent demo data
- Acceptance
  - Launching with the flag always shows the same demo lists/items

### 3.2 Add Snapshot helpers to UITests
- Add `SnapshotHelper.swift` (from Fastlane) to `ListAllUITests` target
- Call `setupSnapshot(app)` before `app.launch()` and use `snapshot("01-...")`
- Acceptance
  - Local `fastlane snapshot` captures at least one screenshot

### 3.3 Write screenshot tests (EN)
- Tests to cover 6–8 iPhone scenes (proposed set below)
- Ensure predictable waits (no `if exists` branching); use expectations
- Acceptance
  - All screenshots generate without flakiness on iPhone 6.5" and iPad 13" simulators

### 3.4 Enable localization runs (EN + FI)
- Configure `Snapfile` with `languages(["en-US","fi"])`
- Use localized copy in UI so screenshots reflect language
- Acceptance
  - Two folders per language with consistent assets

### 3.5 Devices: iPhone 6.5" + iPad 13" (REQUIRED)
- Update Snapshot configuration to run on two devices:
  - iPhone 6.5" Pro (e.g., iPhone 11 Pro Max simulator) — 1242x2688 output
  - iPad Pro (13-inch) (M4) — 2064x2752 output
- Acceptance
  - Snapshot run produces EN+FI screenshots for both devices.

### 3.6 Framing: add device frames and captions for ALL screenshots
- Tooling: Fastlane Frameit.
- Tasks
  - Add Framefile.json with per-locale titles/subtitles and background.
  - Pick readable font (e.g., SF Pro) and verify FI line breaks.
  - Store framed outputs under `fastlane/screenshots/framed` (or `metadata/screenshots/framed`).
  - Apply framing to iPhone, iPad, and Apple Watch screenshots.
- Acceptance
  - All screenshots used for App Store are framed variants.
  - CI job verifies that only framed screenshots are uploaded.

### 3.7 Wire screenshots into deliver (use framed)
- Configure `fastlane deliver` to pick screenshots from `fastlane/screenshots` or `metadata/screenshots`
- Ensure framed directory is the upload source, not raw captures
- Add `--skip_screenshots false` and `--overwrite_screenshots`
- Acceptance
  - A dry-run shows screenshots detected per device + locale

---

## Phase 4 — Watch screenshots (fully automated)

### 4.1 End-to-end automation via UITests + simctl
- Add a watchOS UI test plan that drives the watch app (paired simulator) to key screens.
- Build a small WatchSnapshot helper to:
  - Detect paired watch simulator UDID
  - Run `xcrun simctl io <watch-udid> screenshot <path>` at strategic points
  - Name files with stable convention (e.g., `Watch_46mm_1.png`)
- Target one size initially (e.g., Series 11 46mm). Add Ultra later if desired.
- Acceptance
  - `bundle exec fastlane snapshot` (or dedicated lane) generates 3–5 watch screenshots per locale without manual steps.

### 4.2 Normalize and validate sizes
- Use a small script (Ruby or Swift) to verify filename patterns + dimensions match App Store requirements
- Acceptance
  - CI job fails if sizes/patterns are wrong

### 4.3 Optional framing with Frameit
- If desired, add device frames/captions via `frameit`
- Acceptance
  - Framed variants are generated and stored separately

---

## Phase 5 — Release automation

### 5.1 TestFlight lane finalized
- `beta` lane: build with correct scheme/workspace, export method `app-store`, upload with `pilot`
- Acceptance
  - Build appears in TestFlight automatically

### 5.2 App Store submission lane
- `release` lane: `deliver` metadata + screenshots; optional `submit_for_review` with phased release toggled off
- Acceptance
  - Upload succeeds; manual review step handled in App Store Connect

### 5.3 Git tag driven releases
- On `v*` tag push, run `beta` automatically; `release` is manual
- Acceptance
  - Tagging `v1.1.0` triggers TestFlight build

---

## Phase 6 — Quality, docs, and guardrails

### 6.1 Linting and SwiftFormat (optional)
- Add `swift-format` or `swiftlint` to CI
- Acceptance
  - Lint job runs and reports issues

### 6.2 Contributor docs
- Update `README.md` with: how to run CI locally, how to generate screenshots, how to release
- Acceptance
  - Clear instructions for maintainers

### 6.3 Monitoring flakiness
- Persist UI test logs and attach to PRs
- Acceptance
  - Failures include actionable logs/screenshots

---

## Secrets & Access
- GitHub Secrets required:
  - `ASC_KEY_ID`
  - `ASC_ISSUER_ID`
  - `ASC_KEY_BASE64`
- Optional (later):
  - `SLACK_WEBHOOK_URL` for notifications

## Proposed iOS/iPadOS Screenshot Set (EN, mirrored for FI)
1. Lists Home — "Organize everything at a glance"
2. Create List — "Create lists in seconds"
3. List Detail — "Track active and completed items"
4. Item with Images — "Add photos and notes to items"
5. Search/Filter — "Find anything instantly"
6. Sync/Cloud (if applicable) — "Your lists on all devices"
7. Settings/Customization — "Tune ListAll to your flow"
8. Share/Export (if applicable) — "Share lists with others"

iPhone device size
- We will ship a single iPhone size (6.5"). If you prefer the latest Max device, switch to 6.7" in config.

iPad coverage (REQUIRED)
- Capture at least 3 scenes specifically on iPad Pro 13" (M4) to showcase split UI and spacious layout.
- Required resolution: 2064x2752.

## Proposed watchOS Screenshot Set (automated)
1. Watch Home — recent lists
2. List Detail — items view
3. Add/Complete item — quick interaction
4. Complication — highlights on watch face (if supported)

---

## Try locally (reference)
- Run tests
  - `xcodebuild -project ListAll/ListAll.xcodeproj -scheme ListAll -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`
- Fastlane (after Phase 2)
  - `bundle exec fastlane test`
  - `bundle exec fastlane snapshot`
  - `bundle exec fastlane beta`

Snapshot device hints (names may vary by Xcode version)
- `iPhone 11 Pro Max` (6.5") or `iPhone XS Max` (6.5")
- `iPad Pro (13-inch) (M4)` (2064x2752)

Notes
- We’ll adjust schemes/targets once Fastfile and project details are wired.
- Watch screenshots are fully automated via test flow + simctl.
