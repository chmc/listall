import Testing
import Foundation
@testable import MCPHelpers

/// Records how many operations run inside the gate at the same time
private actor ConcurrencyProbe {
    private(set) var current = 0
    private(set) var maximum = 0
    private(set) var order: [Int] = []

    func enter(_ id: Int) {
        current += 1
        maximum = max(maximum, current)
        order.append(id)
    }

    func leave() {
        current -= 1
    }
}

/// Lets a test hold the gate until it decides to release it
private actor Latch {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

@Suite("Serial Gate", .timeLimit(.minutes(1)))
struct SerialGateTests {
    @Test func concurrentOperationsDoNotOverlap() async throws {
        let gate = SerialGate()
        let probe = ConcurrencyProbe()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in 0..<8 {
                group.addTask {
                    try await gate.run {
                        await probe.enter(id)
                        try await Task.sleep(nanoseconds: 10_000_000)
                        await probe.leave()
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(await probe.maximum == 1)
        #expect(await probe.order.count == 8)
    }

    /// New callers keep arriving while the gate is handed from one waiter to the next
    @Test func staggeredArrivalsDoNotOverlap() async throws {
        let gate = SerialGate()
        let probe = ConcurrencyProbe()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in 0..<12 {
                group.addTask {
                    try await gate.run {
                        await probe.enter(id)
                        try await Task.sleep(nanoseconds: 3_000_000)
                        await probe.leave()
                    }
                }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            try await group.waitForAll()
        }

        #expect(await probe.maximum == 1)
        #expect(await probe.order.count == 12)
    }

    @Test func waitersRunInArrivalOrder() async throws {
        let gate = SerialGate()
        let probe = ConcurrencyProbe()
        let latch = Latch()

        let holder = Task { try await gate.run { await latch.wait() } }
        try await Task.sleep(nanoseconds: 20_000_000)

        var waiters: [Task<Void, Error>] = []
        for id in 0..<5 {
            waiters.append(Task { try await gate.run { await probe.enter(id); await probe.leave() } })
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        await latch.open()
        try await holder.value
        for waiter in waiters { try await waiter.value }

        #expect(await probe.order == [0, 1, 2, 3, 4])
    }

    @Test func cancelledWaiterDoesNotRunAndReleasesGate() async throws {
        let gate = SerialGate()
        let probe = ConcurrencyProbe()
        let latch = Latch()

        let holder = Task { try await gate.run { await latch.wait() } }
        try await Task.sleep(nanoseconds: 20_000_000)

        let cancelled = Task { try await gate.run { await probe.enter(1); await probe.leave() } }
        try await Task.sleep(nanoseconds: 20_000_000)
        let next = Task { try await gate.run { await probe.enter(2); await probe.leave() } }
        try await Task.sleep(nanoseconds: 20_000_000)

        cancelled.cancel()
        await latch.open()
        try await holder.value

        await #expect(throws: CancellationError.self) { try await cancelled.value }
        try await next.value
        #expect(await probe.order == [2])
    }

    @Test func returnsOperationResult() async throws {
        let gate = SerialGate()
        let value = try await gate.run { 42 }
        #expect(value == 42)
    }

    @Test func errorReleasesGate() async throws {
        struct Failure: Error {}
        let gate = SerialGate()

        await #expect(throws: Failure.self) {
            try await gate.run { throw Failure() }
        }

        // Gate must be usable again after a failed operation
        let value = try await gate.run { "next" }
        #expect(value == "next")
    }
}
