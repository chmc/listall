# macOS SwiftUI Performance Optimization

## Date: 2026-01-06

## Context
Implemented performance optimization for the ListAll macOS app (Task 11.4). The goal was to optimize list rendering and image loading/caching following TDD principles.

## Key Learnings

### 1. Async Thumbnail Creation Pattern

**Problem**: Synchronous thumbnail creation blocks the main thread when loading multiple images.

**Solution**: Create an async variant that uses `Task.detached` for background processing:

```swift
func createThumbnailAsync(from data: Data, size: CGSize) async -> NSImage? {
    let cacheKey = "\(data.hashValue)_\(Int(size.width))x\(Int(size.height))" as NSString

    // Fast path: check cache on current thread
    if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
        return cachedThumbnail
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

**Key Points**:
- Check cache on current thread first (fast path avoids context switch)
- Use `Task.detached` for true background execution (not just async)
- NSCache is thread-safe, so cache writes can happen on any thread
- Use `.userInitiated` priority for user-visible work

### 2. Core Data Relationship Prefetching

**Problem**: N+1 query problem when loading lists with items that have images.

**Solution**: Add nested relationships to `relationshipKeyPathsForPrefetching`:

```swift
// Before: Only prefetches items
request.relationshipKeyPathsForPrefetching = ["items"]

// After: Prefetches items AND their images in single query
request.relationshipKeyPathsForPrefetching = ["items", "items.images"]
```

**Key Points**:
- Nested key paths like `"items.images"` are supported
- This eliminates individual fetches when accessing images through items
- Apply to ALL fetch requests that access the relationship chain

### 3. @ViewBuilder for Complex View Functions

**Pattern**: Use `@ViewBuilder` for functions that return complex views:

```swift
// Without @ViewBuilder - harder for type checker
private func makeItemRow(item: Item) -> some View {
    MacItemRowView(item: item, ...)
}

// With @ViewBuilder - helps SwiftUI's type inference
@ViewBuilder
private func makeItemRow(item: Item) -> some View {
    MacItemRowView(item: item, ...)
}
```

**Benefits**:
- Faster compilation (type checker has more hints)
- Enables conditional view building with `if/else`
- Better error messages when view building fails

### 4. Performance Testing Best Practices

**Use XCTest measure block for benchmarks**:
```swift
func testFilteringPerformance() {
    let list = createTestList(withItemCount: 1000)

    measure {
        let result = list.items.filter { !$0.isCrossedOut }
        XCTAssertGreaterThan(result.count, 0)
    }
}
```

**Key Points**:
- `measure` runs block 10 times and reports statistics
- Use unique data each iteration to avoid cache effects
- Clear caches before tests when measuring cold-start performance
- Test realistic scenarios (filter + sort together)

### 5. Good Patterns Already in Codebase

The codebase already had many good performance patterns:

1. **NSCache with limits**: `countLimit = 50`, `totalCostLimit = 50MB`
2. **LazyVGrid for galleries**: Only renders visible cells
3. **Debounced remote changes**: 0.5s debounce prevents UI thrashing
4. **Transaction-based updates**: `withTransaction(Transaction(animation: nil))` prevents layout recursion
5. **Deferred sheet loading**: Sheet content loads after animation completes

### 6. When NOT to Optimize

Some patterns that seemed like issues but were actually fine:

1. **SwiftUI.List for items**: Built-in virtualization is efficient for typical list sizes (<1000)
2. **Full array replacement on sync**: Required for SwiftUI observation to work correctly
3. **Redundant loadItems() calls**: Ensures data consistency, acceptable overhead

## Performance Baselines Established

| Operation | Average Time | Notes |
|-----------|-------------|-------|
| Filter 1000 items | ~0.25ms | Excellent |
| Sort 1000 items (3 ways) | ~1ms | Acceptable |
| Thumbnail cache hit (100x) | ~1.2ms | NSCache overhead |
| Batch thumbnails (20 new) | ~5ms cold, ~0.25ms cached | Cache effective |
| Model conversion (100 items) | ~0.7ms | Entity→Model |
| Realistic workflow | ~0.1ms | Create + filter + sort |

## Files Modified
- `ImageService.swift` - Added async thumbnail method
- `CoreDataManager.swift` - Enhanced relationship prefetching
- `MacMainView.swift` - Added @ViewBuilder
- `MacImageGalleryView.swift` - Use async thumbnails

## Test Coverage
- Created `PerformanceBenchmarkTests.swift` with 21 tests
- All 463 macOS unit tests pass

## Related Resources
- [Apple WWDC: Demystify SwiftUI Performance](https://developer.apple.com/videos/play/wwdc2023/10160/)
- [Core Data Best Practices](https://developer.apple.com/documentation/coredata/optimizing_core_data_performance)
- [NSCache Documentation](https://developer.apple.com/documentation/foundation/nscache)
