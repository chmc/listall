---
name: watch-connectivity
description: WatchConnectivity patterns for iPhone-Watch communication. Use when implementing or debugging iOS to watchOS data sync.
---

# WatchConnectivity Patterns

## Communication Methods

| Method | When to Use | Delivery |
|--------|-------------|----------|
| `sendMessage` | Real-time when reachable | Immediate |
| `transferUserInfo` | Guaranteed delivery | Queued |
| `updateApplicationContext` | Latest state only | Replaces previous |
| `transferFile` | Large data/files | Queued |

## Pattern: Check Reachability First

```swift
func syncToWatch(_ data: SyncData) {
    guard WCSession.default.activationState == .activated else {
        pendingSync = data  // Queue for later
        return
    }

    if WCSession.default.isReachable {
        // Real-time sync when watch is active
        WCSession.default.sendMessage(
            data.toDictionary(),
            replyHandler: nil
        )
    } else {
        // Guaranteed delivery when watch becomes available
        WCSession.default.transferUserInfo(data.toDictionary())
    }
}
```

## Session Activation

```swift
class WatchConnectivityService: NSObject, WCSessionDelegate {
    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            Logger.watch.error("Activation failed: \(error)")
            return
        }

        switch state {
        case .activated:
            syncPendingData()
        case .inactive, .notActivated:
            break
        @unknown default:
            break
        }
    }
}
```

**Ordering (ListAll):** `WatchConnectivityService.init(session:)` only sets the delegate. View models call
`activate()` after registering their incoming-data observers; otherwise queued transfers are delivered before anyone
listens and are lost. Send on `activationDidCompleteWith`, never on a timer: `activate()` is asynchronous, and the old
`asyncAfter(3.0)` send always hit `activationState != .activated` and silently returned
(`documentation/learnings/watchos-initial-sync-request.md`).

## Testing

- **Fake session**: the service takes a `WatchSessionProtocol`; see `FakeWatchSession` in
  `ListAllTests/WatchConnectivityInitialSyncTests.swift` (iOS) and `ListAllWatch Watch AppTests/WatchFullSyncRequestTests.swift`.
- **Round trip**: `testListsPayloadRoundTripsThroughReceivingService` hands the exact `sendListsData` payload to the
  receiving service's `didReceiveUserInfo` and checks the decoded lists.
- **Simulator limit**: `transferUserInfo` is not delivered between simulators (Apple docs; 5 transfers, 0 received).
  `sendMessage` works there. Verify requests/sends from the logs (`log stream --predicate 'subsystem == "com.listall"'`),
  cover delivery with the round-trip test, and do the final check on a device.

## Boundary Validation

```swift
// Always validate at boundary
func handleWatchMessage(_ message: [String: Any]) {
    guard let text = message["text"] as? String,
          !text.isEmpty,
          text.count <= 1000 else {
        Logger.sync.error("Invalid message format")
        return
    }
    createItem(text: text)
}
```

## Common Failures

### "Messages not received by Watch"
- **Cause**: Session not activated or watch not reachable
- **Fix**: Check `WCSession.default.activationState` and `isReachable`
- **Prevention**: Use `transferUserInfo` for guaranteed delivery

### "Watch shows stale data"
- **Cause**: `applicationContext` not updated
- **Fix**: Call `updateApplicationContext` after changes
- **Prevention**: Update context on every relevant data change

### "Watch stays empty until something changes on the iPhone"
- **Cause**: Data was only sent on edits; a launch-time send ran before activation
- **Fix**: Send on activation / `sessionWatchStateDidChange`; watch sends `fullSyncRequest` on launch and refresh
- **Prevention**: Every empty state that depends on the other device needs a way to fetch the data

### "Session activation fails"
- **Cause**: Watch not paired or app not installed on watch
- **Fix**: Check `isPaired` and `isWatchAppInstalled`
- **Prevention**: Handle all activation states gracefully

## Antipatterns

### Fire-and-Forget
```swift
// BAD: No error handling
WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: nil)

// GOOD: Handle failures
WCSession.default.sendMessage(data, replyHandler: nil) { error in
    Logger.sync.error("Send failed: \(error)")
    self.queueForRetry(data)
}
```

### Inconsistent Transforms
```swift
// BAD: Different formats in different places
// In WatchService:
let dict = ["text": item.text, "done": item.isChecked]
// In CloudService:
let dict = ["itemText": item.text, "completed": item.isChecked]

// GOOD: Centralized transformation
extension Item {
    func toSyncPayload() -> SyncPayload {
        SyncPayload(text: text, isCompleted: isChecked)
    }
}
```
