---
name: swiftui-patterns
description: SwiftUI patterns and antipatterns for List, ForEach, onMove, and data binding. Use when debugging SwiftUI issues or implementing list features.
---

# SwiftUI List/ForEach Patterns

## Critical: onMove Drag-and-Drop

### Pattern (Works)
```swift
// Direct @Published array binding
ForEach(viewModel.items) { item in ... }
.onMove(perform: viewModel.moveItems)

func moveItems(from source: IndexSet, to destination: Int) {
    items.move(fromOffsets: source, toOffset: destination)  // Immediate
    saveToStorage()  // Async after
}
```

### Antipattern (Broken)
```swift
// Computed property as data source - SwiftUI loses drag state!
var displayedItems: [Item] { someCondition ? itemsA : itemsB }
ForEach(viewModel.displayedItems) { item in ... }  // BUG!
.onMove(perform: viewModel.moveItems)
```

### Why Computed Properties Break onMove

1. SwiftUI's drag system maintains internal state during drag
2. When onMove fires, SwiftUI expects immediate data source update
3. Computed properties recalculate on every access
4. If any re-evaluation returns old order, SwiftUI reverts visual state
5. **Solution**: Use direct @Published array, not computed property

## Multiple Sources of Truth

### Antipattern
```swift
// TWO separate arrays that can diverge!
class ViewModel {
    @Published var items: [Item] = []  // ViewModel's copy
}
class DataManager {
    var items: [Item] = []  // DataManager's copy
}

func loadItems() {
    items = dataManager.items  // Copies can diverge!
}
```

### Pattern
```swift
// Single source of truth
class ViewModel {
    @Published var items: [Item] = []  // THE source
}
// OR use @FetchRequest for Core Data
```

## Identifiable/Hashable

### Pattern (Correct)
```swift
extension Item: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)  // ID only - stable during mutations
    }
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
}
```

### Antipattern (Broken)
```swift
extension Item: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(orderNumber)  // BUG: Changes during drag!
    }
}
```

When `orderNumber` is in hash, SwiftUI thinks dragged item is "new" object.

## @Published Trigger Timing

### Pattern
Update in-memory state first, then persist asynchronously:
```swift
func updateItem(_ item: Item) {
    items[index] = item  // Immediate UI update
    Task { await saveToDatabase() }  // Async persistence
}
```

### Antipattern
```swift
func updateItem(_ item: Item) {
    saveToDatabase()     // May not complete before re-render
    items[index] = item  // UI might show stale data
}
```

## Notification Observer Chains

### Antipattern
```swift
// Multiple observers for same data - reload cascades
.onReceive(notification1) { loadData() }
.onReceive(notification2) { loadData() }
.onReceive(notification3) { loadData() }
```

### Pattern
Single source of reload, debounced, with mutation protection:
```swift
var isMutating = false

func loadData() {
    guard !isMutating else { return }  // Skip during mutation
    // ... load
}
```

## Debugging Checklist

When a SwiftUI feature misbehaves:

1. **Is data source computed or stored?** Computed = potential bug
2. **Are there multiple copies of state?** Multiple = race condition
3. **What notifications/observers exist?** Each is reload trigger
4. **Is there async work during mutation?** Async = timing issues
5. **What's the hash/equality implementation?** Changing hash = identity loss
6. **Works in Preview but fails on device?** Preview has different timing
