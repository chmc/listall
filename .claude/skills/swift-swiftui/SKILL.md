---
name: swift-swiftui
description: "General Swift and SwiftUI conventions for this codebase: concurrency, state management with ObservableObject, view composition. Use when writing or reviewing Swift/SwiftUI code."
---

# Swift & SwiftUI Conventions in ListAll

Match the code that is already there; `documentation/ARCHITECTURE.md` has the layers (MVVM + repository, Core Data with `NSPersistentCloudKitContainer`, ~85% shared code via target membership).

## State Management
- ViewModels are `ObservableObject` classes with `@Published` properties, owned with `@StateObject` and passed with `@ObservedObject` / `@EnvironmentObject`. The codebase has no `@Observable` types; migrating is a separate decision, not something to do in passing.
- Services are `static let shared` singletons behind protocols (`CoreDataManaging`, `DataManaging`, `CloudSyncProviding`), so tests can inject fakes. Add new services the same way and depend on the protocol, not the concrete type.
- Prefer value types (struct) for models that don't come from Core Data.

## Concurrency
- UI state changes happen on the main thread: `@MainActor` or `DispatchQueue.main.async`, as the surrounding code does.
- Core Data work goes through the context's queue. `perform` is asynchronous: code after it runs before the block. Use `performAndWait` when the next line depends on the result. Mixing them up has caused repeated sync and ordering bugs (`documentation/learnings/macos-cloudkit-sync-race-condition.md`, `swift-testing-coredata-mainactor.md`).
- Coalesce bursts of sync notifications into one reload with a cancellable `DispatchWorkItem` and `[weak self]` (see `WatchMainViewModel.scheduleSyncReload()`).
- Prefer async/await to nested completion handlers in new code.

## Views and Errors
- Keep views small; extract subviews when a body grows past what fits on a screen.
- Don't force unwrap. Handle or surface errors; don't swallow them silently.
- Platform differences go behind `#if os(...)` in shared files, not in copied files.
