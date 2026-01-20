---
name: swift-swiftui
description: Swift and SwiftUI patterns, antipatterns, and best practices. Use when writing or reviewing Swift/SwiftUI code.
---

# Swift & SwiftUI Best Practices

## Patterns (Do This)

### State Management
- Use `@Observable` macro (iOS 17+) for simple state instead of overusing Combine
- Use `@Environment` for dependency injection instead of singletons
- Prefer value types (struct) for models

### Async/Concurrency
- Prefer async/await over nested completion handlers
- Use `actor` for thread-safe shared mutable state instead of manual locks
- Use `TaskGroup` for concurrent operations instead of unbounded Task spawning

### SwiftUI Views
- Keep views small and focused, extract subviews
- Handle errors explicitly with Result or throws

### Error Handling
- Never force unwrap (!)
- Handle errors explicitly, never ignore them

## Antipatterns (Avoid This)

### State Management
- Callback hell with nested completion handlers
- Singletons everywhere with `shared` instances
- Massive 500+ line SwiftUI views

### Concurrency
- Force unwrapping (!) and ignoring errors
- Manual locks/semaphores for synchronization

### Code Structure
- God objects that do everything
- Mixing UI and business logic

## Code Examples

### Good: Async/Await
```swift
func fetchItems() async throws -> [Item] {
    let data = try await api.getData()
    return try JSONDecoder().decode([Item].self, from: data)
}
```

### Bad: Callback Hell
```swift
func fetchItems(completion: @escaping (Result<[Item], Error>) -> Void) {
    api.getData { result in
        switch result {
        case .success(let data):
            api.parseData(data) { parseResult in
                // More nesting...
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

### Good: Actor for Thread Safety
```swift
actor DataCache {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, data: Data) {
        cache[key] = data
    }
}
```

### Bad: Manual Locking
```swift
class DataCache {
    private var cache: [String: Data] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
}
```
