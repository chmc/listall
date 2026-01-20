---
title: CloudKit Schema Deployment to Production
date: 2026-01-05
severity: CRITICAL
category: cloudkit
tags: [schema, production, deployment, testflight, ci-cd]
symptoms:
  - macOS app shows empty lists while iOS has data
  - CloudKit sync silently fails
  - Console shows CKError Code=12 or Code=2006
  - Error "Cannot create or modify field in production schema"
  - New entities work in Debug but not Release
root_cause: CloudKit schema never deployed from Development to Production environment
solution: Manual schema deployment via CloudKit Dashboard before TestFlight/App Store release
files_affected:
  - ListAll/Shared/Persistence.swift
  - ListAll/Shared/ListAll.xcdatamodeld
related:
  - cloudkit-sync-enhanced-reliability.md
---

## Why Manual Deployment Required

Production schema is:
1. **Immutable (additive-only)** - prevents data loss
2. **Multi-version support** - old and new apps sync with same database
3. **Human review checkpoint** - irreversible changes require confirmation

## When to Deploy

Deploy schema when:
- First TestFlight/App Store build
- Adding new Core Data entities (new CD_* record types)
- Adding new attributes to entities
- Adding new relationships

## How to Deploy

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select container → Schema section
3. Switch to **Development** environment
4. Click gear (⚙️) → **"Deploy Schema Changes..."**
5. Review diff → Click **Deploy** (cannot be undone)

## Before Deploying

Run Debug build with schema initialization:

```swift
#if DEBUG
if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
    try cloudKitContainer.initializeCloudKitSchema(
        options: NSPersistentCloudKitContainerSchemaInitializationOptions()
    )
}
#endif
```

This creates "fully saturated" record with ALL fields including optional ones.

## Pre-Release Checklist

- [ ] Core Data model changes? → Run Debug build first
- [ ] Check CloudKit Dashboard → Compare Development vs Production
- [ ] Schema differences? → Deploy Schema Changes
- [ ] Wait for deployment success
- [ ] Build and submit

## CI Automation

Release workflow includes schema drift detection that blocks releases if Development has undeployed changes.

**Required GitHub Secrets:**
- `CLOUDKIT_MANAGEMENT_TOKEN` - CloudKit Dashboard → API Tokens → Management Tokens
- `APPLE_TEAM_ID` - Your team ID

**Skip check:** Set `SKIP_CLOUDKIT_CHECK=true` repository variable.

**Limitation:** `cktool` can export/compare but cannot deploy to Production - only Dashboard can.

## Behavior Without Deployment

| Behavior | Development | Production |
|----------|-------------|------------|
| Schema auto-creates | Yes | No |
| Missing record type | Auto-created | Error |
| Missing field | Auto-created | Error |
| User experience | Seamless | "Data not syncing" |
