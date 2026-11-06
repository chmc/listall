import Testing
import Foundation
@testable import MCPHelpers

@Suite("Poll Until")
struct PollUntilTests {
    actor Counter {
        var value = 0
        func increment() -> Int {
            value += 1
            return value
        }
    }

    @Test func returnsImmediatelyWhenConditionHolds() async {
        let counter = Counter()
        let result = await pollUntil(timeout: 5, interval: 0.01) {
            _ = await counter.increment()
            return true
        }
        #expect(result)
        #expect(await counter.value == 1)
    }

    @Test func returnsTrueWhenConditionBecomesTrue() async {
        let counter = Counter()
        let result = await pollUntil(timeout: 5, interval: 0.01) {
            await counter.increment() >= 3
        }
        #expect(result)
        #expect(await counter.value == 3)
    }

    @Test func returnsFalseAfterTimeout() async {
        let start = Date()
        let result = await pollUntil(timeout: 0.2, interval: 0.05) { false }
        #expect(!result)
        #expect(Date().timeIntervalSince(start) >= 0.2)
    }
}
