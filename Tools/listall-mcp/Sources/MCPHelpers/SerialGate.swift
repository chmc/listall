import Foundation

/// Runs async operations one at a time, in the order they reach the gate.
///
/// swift-sdk 0.11+ handles each request in its own Task, so tool calls can run
/// concurrently. Tool handlers share state (screenshot session, XCUITest bridge
/// temp files) that assumes one call at a time, as in swift-sdk 0.10.x.
/// A plain actor is not enough: actors are reentrant across `await`.
public actor SerialGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Throws `CancellationError` without running `operation` if the caller was
    /// cancelled while waiting (e.g. the client sent notifications/cancelled).
    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            // Hand the gate directly to the next waiter; isBusy stays true
            waiters.removeFirst().resume()
        }
    }
}
