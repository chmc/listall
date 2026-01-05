# CloudKit Schema Deployment to Production

## Date: 2026-01-05

## Status: RESOLVED

## Problem
macOS app showed empty lists while iOS app had data. CloudKit sync silently failed because the schema (CD_ItemEntity, CD_ListEntity, etc.) was never deployed from Development to Production environment.

## Root Cause
CloudKit requires **manual schema deployment** to Production. This is intentional:

1. **Production schema is immutable (additive-only)** - prevents data loss
2. **Multi-version support** - old and new app versions must sync with same database
3. **Human review checkpoint** - irreversible changes require explicit confirmation

## When to Deploy Schema

### Triggers - Deploy When:

1. **First TestFlight/App Store build** - Production schema starts empty
2. **Adding new Core Data entities** - new `CD_*` record types needed
3. **Adding new attributes to entities** - new fields in existing record types
4. **Adding new relationships** - requires schema field updates
5. **After any Core Data model changes** - run debug build first, then deploy

### How to Know Schema Needs Deployment:

**Check CloudKit Dashboard:**
1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select your container
3. Compare Development vs Production schemas
4. If Development has record types Production doesn't → deploy needed

**Signs of Missing Schema (in Production builds):**
- Data syncs on one device but not others
- Console shows `CKError Code=12` or `Code=2006`
- Error: "Cannot create or modify field... in production schema"
- New entities/fields work in Debug but not Release builds

## Solution: Deploy Schema

### Via CloudKit Dashboard (Required)

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select container → Schema section
3. Switch to **Development** environment
4. Click gear icon (⚙️) → **"Deploy Schema Changes..."**
5. Review the diff (shows what will change)
6. Click **Deploy** (cannot be undone!)
7. Wait for success confirmation

### Before Deploying - Ensure Complete Schema

Run a Debug build with schema initialization to create all fields:

```swift
// In your Core Data stack setup (Debug only)
#if DEBUG
if let cloudKitContainer = container as? NSPersistentCloudKitContainer {
    do {
        try cloudKitContainer.initializeCloudKitSchema(
            options: NSPersistentCloudKitContainerSchemaInitializationOptions()
        )
    } catch {
        print("CloudKit schema initialization failed: \(error)")
    }
}
#endif
```

This creates a "fully saturated" record with ALL possible fields, including optional ones.

## Pre-Release Checklist

Before every TestFlight/App Store submission:

- [ ] Core Data model changes? → Run Debug build to update Development schema
- [ ] Check CloudKit Dashboard → Compare Development vs Production
- [ ] Schema differences? → Deploy Schema Changes
- [ ] Wait for deployment success
- [ ] Build and submit to TestFlight/App Store

## Automation Limitations

Apple's `cktool` can export/import Development schema but **cannot deploy to Production**. The deploy button in CloudKit Dashboard is the only way - by design.

```bash
# Can do: Export Development schema
xcrun cktool export-schema \
  --team-id $TEAM_ID \
  --container-id iCloud.io.github.chmc.ListAll \
  --environment development \
  --output-file schema.ckdb

# Cannot do: Deploy to Production (must use Dashboard UI)
```

## What Happens Without Deployment

| Behavior | Development | Production |
|----------|-------------|------------|
| Schema auto-creates | ✅ Yes | ❌ No |
| Missing record type | Auto-created | Error: cannot create |
| Missing field | Auto-created | Error: cannot modify |
| App behavior | Works normally | Sync silently fails |
| User experience | Seamless | "Data not syncing" |

## Related Files
- `ListAll/Shared/Persistence.swift` - NSPersistentCloudKitContainer setup
- `ListAll/Shared/ListAll.xcdatamodeld` - Core Data model

## References
- [Deploying an iCloud Container's Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [initializeCloudKitSchema(options:)](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3343548-initializecloudkitschema)
- [WWDC21: Meet CloudKit Console](https://developer.apple.com/videos/play/wwdc2021/10117/)
