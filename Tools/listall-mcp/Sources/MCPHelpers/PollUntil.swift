import Foundation

/// Re-evaluates `condition` every `interval` seconds until it returns true or `timeout` passes.
/// Checks once immediately, so a condition that already holds costs no wait.
/// - Returns: true if the condition held before the timeout
public func pollUntil(
    timeout: TimeInterval,
    interval: TimeInterval = 0.25,
    condition: () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
        if await condition() {
            return true
        }
        if Date() >= deadline {
            return false
        }
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}
