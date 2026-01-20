---
title: macOS SwiftUI Performance Optimization
date: 2026-01-06
severity: MEDIUM
category: macos
tags: [performance, thumbnails, coredata, prefetching, async, caching]
symptoms:
  - UI freezing when loading images
  - Slow list rendering with many items
  - N+1 query problem with relationships
root_cause: Synchronous thumbnail creation blocking main thread; missing relationship prefetching
solution: Use async thumbnail creation with Task.detached; add nested relationships to prefetching
files_affected:
  - ListAll/Services/ImageService.swift
  - ListAll/Services/CoreDataManager.swift
  - ListAllMac/Views/MacMainView.swift
  - ListAllMac/Views/MacImageGalleryView.swift
related:
  - macos-memory-management-patterns.md
---

## Async Thumbnail Pattern

```swift
func createThumbnailAsync(from data: Data, size: CGSize) async -> NSImage? {
    let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString

    // Fast path: check cache first
    if let cached = thumbnailCache.object(forKey: cacheKey) {
        return cached
    }

    // Background processing
    return await Task.detached(priority: .userInitiated) { [self] in
        guard let image = NSImage(data: data) else { return nil }
        let thumbnail = createThumbnail(from: image, size: size)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }.value
}
```

**Key points:**
- Check cache on current thread first (avoids context switch)
- Use `Task.detached` for true background execution
- NSCache is thread-safe for cache writes
- Use `.userInitiated` for user-visible work

## Core Data Relationship Prefetching

```swift
// Before: Only prefetches items
request.relationshipKeyPathsForPrefetching = ["items"]

// After: Prefetches items AND images
request.relationshipKeyPathsForPrefetching = ["items", "items.images"]
```

Nested key paths eliminate individual fetches when traversing relationship chains.

## @ViewBuilder for Complex Views

```swift
@ViewBuilder
private func makeItemRow(item: Item) -> some View {
    MacItemRowView(item: item, ...)
}
```

Benefits: faster compilation, enables conditional building, better error messages.

## Performance Baselines

| Operation | Time | Notes |
|-----------|------|-------|
| Filter 1000 items | ~0.25ms | Excellent |
| Sort 1000 items (3 ways) | ~1ms | Acceptable |
| Thumbnail cache hit (100x) | ~1.2ms | NSCache overhead |
| Batch thumbnails (20 new) | ~5ms cold, ~0.25ms cached | Cache effective |

## Good Patterns Already Present

- NSCache with limits: `countLimit = 50`, `totalCostLimit = 50MB`
- LazyVGrid for galleries: only renders visible cells
- Debounced remote changes: 0.5s prevents UI thrashing
- Transaction-based updates: prevents layout recursion
- Deferred sheet loading: content loads after animation

## When NOT to Optimize

- SwiftUI.List for items: built-in virtualization works for <1000 items
- Full array replacement on sync: required for SwiftUI observation
- Redundant loadItems() calls: ensures data consistency
