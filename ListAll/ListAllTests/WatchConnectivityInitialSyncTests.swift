import XCTest
import WatchConnectivity
@testable import ListAll

/// Fake WCSession so the iOS send decisions can be tested without a paired watch.
final class FakeWatchSession: WatchSessionProtocol {
    weak var delegate: WCSessionDelegate?
    var activationState: WCSessionActivationState = .activated
    var isReachable = false
    var isPaired = true
    var isWatchAppInstalled = true
    var hasOutstandingListsTransfer = false

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
    }

    func queueUserInfo(_ userInfo: [String: Any]) {
        queuedUserInfos.append(userInfo)
    }

    var queuedListsTransferCount: Int {
        queuedUserInfos.filter { $0["dataType"] as? String == "fullSync" }.count
    }
}

/// Tests that the iPhone pushes its lists to the watch without waiting for a local change
/// (the 3 s timer in MainViewModel.init never fired because the session was not yet activated).
final class WatchConnectivityInitialSyncTests: XCTestCase {

    private var session: FakeWatchSession!
    private var service: WatchConnectivityService!

    override func setUp() {
        super.setUp()
        session = FakeWatchSession()
        service = WatchConnectivityService(session: session)
        service.listsProvider = { [List(name: "Groceries")] }
    }

    override func tearDown() {
        service = nil
        session = nil
        super.tearDown()
    }

    func testInitDoesNotActivateSessionUntilAsked() {
        let freshSession = FakeWatchSession()
        let freshService = WatchConnectivityService(session: freshSession)

        XCTAssertEqual(freshSession.activateCallCount, 0)
        XCTAssertTrue(freshSession.delegate === freshService)

        freshSession.activationState = .notActivated
        freshService.activate()
        XCTAssertEqual(freshSession.activateCallCount, 1)
    }

    func testActivationSendsListsWhenWatchAppInstalled() {
        service.handleActivationCompleted()

        XCTAssertEqual(session.queuedListsTransferCount, 1)
    }

    func testActivationDoesNotSendWhenWatchAppNotInstalled() {
        session.isWatchAppInstalled = false

        service.handleActivationCompleted()

        XCTAssertEqual(session.queuedListsTransferCount, 0)
    }

    func testWatchStateChangeSendsListsWhenWatchAppInstalled() {
        service.handleWatchStateChanged()

        XCTAssertEqual(session.queuedListsTransferCount, 1)
    }

    func testFullSyncRequestMessageSendsLists() {
        service.handleIncomingPayload(["dataType": "fullSyncRequest"])

        XCTAssertEqual(session.queuedListsTransferCount, 1)
    }

    func testOtherPayloadsDoNotSendLists() {
        service.handleIncomingPayload(["syncNotification": true])
        service.handleIncomingPayload(["language": "fi"])

        XCTAssertEqual(session.queuedListsTransferCount, 0)
    }

    func testEmptyOrMissingProviderDoesNotSend() {
        service.listsProvider = { [] }
        service.handleActivationCompleted()

        service.listsProvider = nil
        service.handleIncomingPayload(["dataType": "fullSyncRequest"])

        XCTAssertEqual(session.queuedListsTransferCount, 0)
    }

    func testNotActivatedSessionDoesNotSend() {
        session.activationState = .notActivated

        service.handleIncomingPayload(["dataType": "fullSyncRequest"])

        XCTAssertEqual(session.queuedListsTransferCount, 0)
    }
}
