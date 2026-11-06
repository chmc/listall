---
title: Watch Stayed Empty Until an iPhone Change (Dead 3s Sync Timer)
date: 2026-11-06
severity: HIGH
category: watchos
tags:
  - watch-connectivity
  - initial-sync
  - wcsession-activation
  - transferUserInfo
  - simulator-limitation
symptoms:
  - Watch app shows "No Lists" although the iPhone has lists
  - Data appears on the watch only after editing something on the iPhone
  - Watch pull-to-refresh does nothing when there are no lists
  - Log "Cannot send lists data: session not activated" right after launch (iOS and watchOS)
root_cause: The "send lists 3s after launch" timer was the first code to touch WatchConnectivityService.shared, so the session was still activating and the send returned; the watch could not request data and the empty state had no refresh
solution: Activate the session after observers register, send lists on activation / watch-app install / watch request, add watch fullSyncRequest and an empty-state sync button
files_affected:
  - ListAll/ListAll/Services/WatchConnectivityService.swift
  - ListAll/ListAll/ViewModels/MainViewModel.swift
  - ListAll/ListAllWatch Watch App/ViewModels/WatchMainViewModel.swift
  - ListAll/ListAllWatch Watch App/Views/WatchListsView.swift
  - ListAll/ListAllWatch Watch App/Views/Components/WatchEmptyStateView.swift
related:
  - watchos-performance-baseline.md
---

## Problem

A user installed the watch app (Apple Watch Ultra 4) and it stayed empty. Lists arrived only after they
reordered items on the iPhone while the watch app was open. Pull-to-refresh on the empty watch screen did nothing.

## Root Cause

`WCSession.activate()` is asynchronous. The 3 s timer in `MainViewModel.init` (and the same one in
`WatchMainViewModel.init`) was the first access to `WatchConnectivityService.shared`, so it created the session
and called `sendListsData` before activation finished; the `activationState == .activated` guard returned.
Data therefore moved only on later edits. The watch had no way to ask for data (its refresh pushed watch data
to the iPhone), and the empty state was not wrapped in `WatchPullToRefreshView`.

```swift
// BAD - singleton created here, session not yet activated, send silently skipped
DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
    WatchConnectivityService.shared.sendListsData(self.dataManager.lists)
}

// GOOD - react to activation instead of guessing a delay
func session(_ session: WCSession, activationDidCompleteWith state: ...) {
    DispatchQueue.main.async { self.handleActivationCompleted() } // iOS: send, watch: request
}
```

## Solution

- `WatchConnectivityService.init(session:)` only sets the delegate; view models call `activate()` after their
  data observers are registered (otherwise queued transfers arrive before anyone listens and are lost).
- iOS sends `listsProvider()` on activation, on `sessionWatchStateDidChange` (watch app installed) and on a
  `fullSyncRequest` from the watch.
- watchOS `requestFullSync()` on activation / refresh / empty-state button. It queues the request behind any
  outstanding lists transfer so the iPhone sees watch edits before replying.
- The watch no longer pushes a full snapshot on launch/refresh (a stale snapshot deletes iPhone lists it lacks).
- `WatchSessionProtocol` lets unit tests use a fake session.

## Prevention

- [ ] Never send over WatchConnectivity on a timer; send from `activationDidCompleteWith`
- [ ] Register incoming-data observers before activating the session
- [ ] Every empty state that depends on another device needs an explicit way to fetch the data

## Simulator Limitation

`transferUserInfo` is not delivered between iOS and watchOS simulators (Apple docs: test data transfers on
paired devices). In the simulator you can verify the request (`sendMessage`) and that the iPhone sends
("Sending N lists ... via transferUserInfo"), but the lists only arrive on real devices.

Device-verified 2026-11-06: TestFlight 1.1.23 (108) on iPhone + Apple Watch Ultra 4; the lists appeared on the
watch without any change on the iPhone (user report).

## Known Gaps

- If the iPhone app is not running at all, the background launch creates no `MainViewModel`, so the session is
  not activated; the queued request is answered when the iPhone app is next opened.
- Payloads over 256 KB are silently skipped (`sendListsData`).

## Key Insight

> An asynchronous activation plus a fixed delay is a race you lose on the first launch: send on the activation callback.
