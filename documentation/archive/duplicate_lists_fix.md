# Duplicate Lists Bug Fix

## Problem Analysis

### Symptoms
1. **UI shows duplicate lists** - Same list appears multiple times with same name
2. **SwiftUI ForEach warnings** - "the ID [UUID] occurs multiple times within the collection"
3. **Deleting one list deletes all duplicates** - When user deletes one instance, all instances disappear

### Root Cause
**Core Data contains duplicate `ListEntity` records with the same UUID**

Evidence from logs:
```
💾 [DataManager] Fetched 13 ListEntity objects from Core Data
💾   - 'Sovellusideat': Has 0 items in Core Data
💾   - 'Sovellusideat': Has 1 items in Core Data  ← DUPLICATE!
💾   - 'Grillaus': Has 0 items in Core Data
💾   - 'Grillaus': Has 6 items in Core Data        ← DUPLICATE!
💾   - 'Matkapohja': Has 0 items in Core Data
💾   - 'Matkapohja': Has 41 items in Core Data     ← DUPLICATE!
💾   - 'Ravintolat': Has 0 items in Core Data
💾   - 'Ravintolat': Has 5 items in Core Data      ← DUPLICATE!

ForEach<Array<List>, UUID, ...>: the ID DEDC8DEB-3F41-4D0B-882C-416C04ED66B1 occurs multiple times
ForEach<Array<List>, UUID, ...>: the ID 832E4158-5381-4874-9E9F-A2B3C0979725 occurs multiple times
ForEach<Array<List>, UUID, ...>: the ID 7974CDBC-5BAB-45FA-9B8F-4D50EE39EA24 occurs multiple times
ForEach<Array<List>, UUID, ...>: the ID 0C837AAC-CEDD-4B1F-A739-3DB92DFF75C0 occurs multiple times
```

### Why Delete Removes Both
1. Multiple `ListEntity` records exist in Core Data with the same `id`
2. `loadData()` fetches all of them and creates multiple `List` objects with same UUID
3. SwiftUI's `ForEach` displays both (with warnings)
4. When deleting, `deleteList(withId:)` only archives the first match
5. BUT `lists.removeAll { $0.id == id }` removes ALL lists from the array with that ID
6. Result: Both UI instances disappear even though only one Core Data record was archived

## Solution

### 1. Added Duplicate List Cleanup Function
**File**: `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

Created `removeDuplicateLists()` function (similar to existing `removeDuplicateItems()`):

```swift
func removeDuplicateLists() {
    // Fetch all lists
    let allLists = try context.fetch(request)
    
    // Group by UUID
    var listsById: [UUID: [ListEntity]] = [:]
    for list in allLists {
        listsById[list.id, default: []].append(list)
    }
    
    // Remove duplicates, keeping most recent modifiedAt
    for (id, lists) in listsById where lists.count > 1 {
        let sorted = lists.sorted { 
            ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) 
        }
        let toKeep = sorted.first!
        let toRemove = sorted.dropFirst()
        
        for duplicate in toRemove {
            // Transfer items from duplicate to kept list
            if let items = duplicate.items as? Set<ItemEntity> {
                for item in items {
                    item.list = toKeep  // Reassign orphaned items
                }
            }
            context.delete(duplicate)
        }
    }
    
    saveData()
    loadData()  // Reload to reflect changes
}
```

**Key Features:**
- Groups lists by UUID to find duplicates
- Keeps the most recently modified version
- **Transfers items** from duplicate lists to the kept list (prevents data loss)
- Deletes duplicate `ListEntity` records
- Reloads data to refresh UI

### 2. Updated App Launch Sequence
**Files**: 
- `ListAll/ListAll/ViewModels/MainViewModel.swift` (iOS)
- `ListAll/ListAllWatch Watch App/ViewModels/WatchMainViewModel.swift` (watchOS)

**Before:**
```swift
init() {
    loadLists()
    dataManager.removeDuplicateItems()  // Only cleaned items
    loadLists()
}
```

**After:**
```swift
init() {
    loadLists()
    dataManager.removeDuplicateLists()  // NEW: Clean lists first
    dataManager.removeDuplicateItems()  // Then clean items
    loadLists()
}
```

**Rationale:** Clean lists before items to ensure items can be properly reassigned to surviving lists.

## Expected Behavior After Fix

### On Launch:
```
🧹 [iOS] Checking for duplicate lists and items on launch...
🧹 [iOS] Removed 1 duplicate(s) of list: Sovellusideat
🧹 [iOS] Removed 1 duplicate(s) of list: Grillaus
🧹 [iOS] Removed 1 duplicate(s) of list: Matkapohja
🧹 [iOS] Removed 1 duplicate(s) of list: Ravintolat
🧹 [iOS] Total duplicate lists removed: 4
✅ [iOS] No duplicate items found in Core Data
🔄 [iOS] Reloading lists after cleanup...
💾 [iOS] DataManager: Fetched 13 lists from Core Data
```

### After Cleanup:
- ✅ Each list appears only once in UI
- ✅ No SwiftUI ForEach warnings
- ✅ Deleting a list only deletes that list
- ✅ All items preserved (transferred to surviving list)
- ✅ Item counts are accurate

## Files Modified

1. **CoreDataManager.swift** (iOS & watchOS)
   - Added `removeDuplicateLists()` function
   - Enhanced cleanup to handle both lists and items

2. **MainViewModel.swift** (iOS)
   - Updated launch sequence to clean lists before items
   - Enhanced logging for diagnostics

3. **WatchMainViewModel.swift** (watchOS)
   - Updated launch sequence to clean lists before items
   - Enhanced logging for diagnostics

## Testing

### Manual Test Steps:
1. Launch app (should see cleanup logs)
2. Verify no duplicate lists in main view
3. Verify all items are present and correctly assigned
4. Delete a list - verify only that list is deleted
5. Relaunch app - verify no more cleanup needed (no duplicates remain)

### Expected Results:
- ✅ No SwiftUI ForEach warnings in console
- ✅ Each list appears exactly once
- ✅ Correct item counts displayed
- ✅ Delete operation works as expected

## Root Cause Investigation

The duplicate `ListEntity` records were likely caused by:
1. **CloudKit sync conflicts** - Two devices creating/updating the same list simultaneously
2. **Merge policy issues** - Core Data's merge policy not properly handling CloudKit imports
3. **Relationship inconsistencies** - Some duplicate lists had items, others didn't (CloudKit sync timing)

The fix addresses the symptoms (removes duplicates) and provides ongoing protection (runs on every launch).

## Future Prevention

Consider:
1. **Unique constraint** on `ListEntity.id` in Core Data model (requires migration)
2. **Better merge policy** to prevent CloudKit from creating duplicates
3. **Batch operations** to reduce chances of race conditions during sync
4. **Monitoring** to alert if duplicates are detected frequently
