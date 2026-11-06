import XCTest
import WatchConnectivity
@testable import ListAllWatch_Watch_App

/// Fake WCSession so the watch request routing can be tested without a paired iPhone.
final class FakeWatchSession: WatchSessionProtocol {
    weak var delegate: WCSessionDelegate?
    var activationState: WCSessionActivationState = .activated
    var isReachable = true
    var hasOutstandingListsTransfer = false
    var sendMessageError: Error?

    private(set) var activateCallCount = 0
    private(set) var sentMessages: [[String: Any]] = []
    private(set) var queuedUserInfos: [[String: Any]] = []

    func activate() {
        activateCallCount += 1
    }

    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)?,
                     errorHandler: ((Error) -> Void)?) {
        sentMessages.append(message)
        if let sendMessageError {
            errorHandler?(sendMessageError)
        }
    }

    func queueUserInfo(_ userInfo: [String: Any]) {
        queuedUserInfos.append(userInfo)
    }
}

/// Tests that the watch asks the iPhone for its lists instead of waiting for an iPhone-side change.
final class WatchFullSyncRequestTests: XCTestCase {

    private var session: FakeWatchSession!
    private var service: WatchConnectivityService!

    override func setUp() {
        super.setUp()
        session = FakeWatchSession()
        service = WatchConnectivityService(session: session)
    }

    override func tearDown() {
        service = nil
        session = nil
        super.tearDown()
    }

    private func isRequest(_ payload: [String: Any]?) -> Bool {
        payload?["dataType"] as? String == "fullSyncRequest"
    }

    func testReachableRequestUsesSendMessage() {
        service.requestFullSync()

        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertTrue(isRequest(session.sentMessages.first))
        XCTAssertTrue(session.queuedUserInfos.isEmpty)
    }

    func testUnreachableRequestIsQueued() {
        session.isReachable = false

        service.requestFullSync()

        XCTAssertTrue(session.sentMessages.isEmpty)
        XCTAssertEqual(session.queuedUserInfos.count, 1)
        XCTAssertTrue(isRequest(session.queuedUserInfos.first))
    }

    /// Unsent watch changes must reach the iPhone before its reply, otherwise the reply
    /// (without those changes) would delete them on the watch.
    func testRequestQueuesBehindOutstandingListsTransfer() {
        session.hasOutstandingListsTransfer = true

        service.requestFullSync()

        XCTAssertTrue(session.sentMessages.isEmpty)
        XCTAssertEqual(session.queuedUserInfos.count, 1)
        XCTAssertTrue(isRequest(session.queuedUserInfos.first))
    }

    func testSendMessageFailureFallsBackToQueue() {
        session.sendMessageError = NSError(domain: WCErrorDomain, code: WCError.notReachable.rawValue)

        service.requestFullSync()

        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertEqual(session.queuedUserInfos.count, 1)
        XCTAssertTrue(isRequest(session.queuedUserInfos.first))
    }

    func testNotActivatedSessionDoesNotRequest() {
        session.activationState = .notActivated

        service.requestFullSync()

        XCTAssertTrue(session.sentMessages.isEmpty)
        XCTAssertTrue(session.queuedUserInfos.isEmpty)
    }

    /// The OS transport (transferUserInfo) is not delivered between simulators, so this covers
    /// everything around it: the exact payload sendListsData queues is handed to the receiving
    /// service's didReceiveUserInfo and must come out as the same lists.
    func testListsPayloadRoundTripsThroughReceivingService() {
        var list = List(name: "Groceries")
        list.items = [Item(title: "Milk", listId: list.id), Item(title: "Bread", listId: list.id)]
        service.sendListsData([list])
        guard let payload = session.queuedUserInfos.first else {
            return XCTFail("sendListsData queued no transfer")
        }

        let receiver = WatchConnectivityService(session: FakeWatchSession())
        let received = expectation(forNotification: NSNotification.Name("WatchConnectivityListsDataReceived"),
                                   object: nil) { notification in
            guard let lists = notification.userInfo?["lists"] as? [List], lists.count == 1 else { return false }
            return lists[0].id == list.id
                && lists[0].name == "Groceries"
                && Set(lists[0].items.map(\.title)) == ["Milk", "Bread"]
        }

        receiver.session(WCSession.default, didReceiveUserInfo: payload)

        wait(for: [received], timeout: 2.0)
    }

    func testActivationRequestsFullSync() {
        service.handleActivationCompleted()

        XCTAssertEqual(session.sentMessages.count, 1)
        XCTAssertTrue(isRequest(session.sentMessages.first))
    }
}
