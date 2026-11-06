import Foundation
import Combine
import WatchConnectivity
import os.log

/// The parts of WCSession the service uses, so tests can substitute a fake session
protocol WatchSessionProtocol: AnyObject {
    var delegate: WCSessionDelegate? { get set }
    var activationState: WCSessionActivationState { get }
    var isReachable: Bool { get }
    #if os(iOS)
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    #endif
    /// True while a full lists transfer is still queued for the paired device
    var hasOutstandingListsTransfer: Bool { get }
    func activate()
    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)?,
                     errorHandler: ((Error) -> Void)?)
    /// Queues a transferUserInfo transfer (delivered in order, even if not reachable)
    func queueUserInfo(_ userInfo: [String: Any])
}

extension WCSession: WatchSessionProtocol {
    var hasOutstandingListsTransfer: Bool {
        outstandingUserInfoTransfers.contains {
            $0.isTransferring && $0.userInfo[WatchConnectivityService.MessageKey.dataType] as? String
                == WatchConnectivityService.DataType.fullSync
        }
    }

    func queueUserInfo(_ userInfo: [String: Any]) {
        _ = transferUserInfo(userInfo)
    }
}

/// Service for handling communication between iOS and watchOS apps using WatchConnectivity framework
/// This service provides direct device-to-device communication when both devices are paired and in range
/// Complements CloudKit sync by providing instant notifications of data changes
class WatchConnectivityService: NSObject, ObservableObject {
    
    // MARK: - Timestamp Helper
    
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    // MARK: - Singleton
    
    static let shared = WatchConnectivityService(session: WCSession.isSupported() ? WCSession.default : nil)

    // MARK: - Properties
    
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var isActivated: Bool = false
    
    #if os(iOS)
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
    #endif
    
    #if os(iOS)
    /// Supplies the iPhone's current lists when the watch needs a full sync
    /// (session activation, watch app install, or a request from the watch)
    var listsProvider: (() -> [List])?
    #endif

    private let session: WatchSessionProtocol?
    private let logger = Logger(subsystem: "com.listall", category: "WatchConnectivity")

    // MARK: - Message Keys

    fileprivate enum MessageKey {
        static let syncNotification = "syncNotification"
        static let timestamp = "timestamp"
        static let listsData = "listsData"
        static let dataType = "dataType"
    }

    fileprivate enum DataType {
        static let fullSync = "fullSync"
        /// Sent by the watch to ask the iPhone for its current lists
        static let fullSyncRequest = "fullSyncRequest"
    }

    // MARK: - Initialization

    /// Sets the delegate but does not activate. Call `activate()` only after the incoming data
    /// observers are registered, otherwise queued transfers are delivered to nobody and lost.
    init(session: WatchSessionProtocol?) {
        self.session = session
        super.init()

        if let session = session {
            session.delegate = self
        } else {
            logger.warning("WatchConnectivity is not supported on this device")
        }
    }

    /// Activates the session (no-op if already activated)
    func activate() {
        guard let session = session, session.activationState == .notActivated else { return }
        session.activate()
        logger.info("WatchConnectivity session activation requested")
    }

    // MARK: - Public Methods

    #if os(iOS)
    /// Sends language preference to watchOS
    func sendLanguagePreference(_ languageCode: String) {
        guard let session = session else {
            logger.warning("Cannot send language preference: WatchConnectivity not supported")
            return
        }
        
        guard session.isPaired, session.isWatchAppInstalled else {
            logger.info("Cannot send language preference: watch not paired or app not installed")
            return
        }
        
        let message: [String: Any] = ["language": languageCode]
        
        if session.isReachable {
            // Watch is reachable, send immediately
            session.sendMessage(message, replyHandler: { reply in
                self.logger.info("Language preference sent successfully: \(languageCode)")
            }, errorHandler: { error in
                self.logger.error("Failed to send language preference: \(error.localizedDescription)")
            })
        } else {
            // Watch not reachable, queue for background delivery
            session.queueUserInfo(message)
            logger.info("Queued language preference for background delivery: \(languageCode)")
        }
    }
    #endif
    
    /// Sends a sync notification to the paired device
    /// This notifies the other device that data has changed and it should reload
    func sendSyncNotification() {
        guard let session = session else {
            logger.warning("Cannot send sync notification: WatchConnectivity not supported")
            return
        }
        
        guard session.isReachable else {
            logger.info("Cannot send sync notification: paired device is not reachable")
            return
        }
        
        let message: [String: Any] = [
            MessageKey.syncNotification: true,
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            self.logger.info("Sync notification sent successfully, received reply: \(reply)")
        }, errorHandler: { error in
            self.logger.error("Failed to send sync notification: \(error.localizedDescription)")
        })
        
        logger.info("Sending sync notification to paired device")
    }
    
    /// Sends actual list data to the paired device for synchronization
    /// Uses transferUserInfo for reliable background transfer that queues if device not reachable
    /// - Parameter lists: Array of List objects to sync
    func sendListsData(_ lists: [List]) {
        _ = Self.timestamp()
        
        guard let session = session else {
            logger.warning("Cannot send lists data: WatchConnectivity not supported")
            return
        }
        
        guard session.activationState == .activated else {
            logger.warning("Cannot send lists data: session not activated")
            return
        }
        
        do {
            // CRITICAL: Deduplicate items before syncing (fixes iOS duplicate item bug)
            var totalItemsBefore = 0
            var totalItemsAfter = 0
            let deduplicatedLists = lists.map { list -> List in
                var cleanedList = list
                totalItemsBefore += list.items.count
                
                // Remove duplicate items by keeping only unique IDs (most recent modifiedAt wins)
                var seenItems: [UUID: Item] = [:]
                for item in list.items {
                    if let existing = seenItems[item.id] {
                        // Keep the most recently modified version
                        if item.modifiedAt > existing.modifiedAt {
                            seenItems[item.id] = item
                        }
                    } else {
                        seenItems[item.id] = item
                    }
                }
                cleanedList.items = Array(seenItems.values)
                totalItemsAfter += cleanedList.items.count
                
                return cleanedList
            }
            
            // Convert to lightweight sync models (exclude images)
            let syncData = deduplicatedLists.map { ListSyncData(from: $0) }
            
            // Encode lightweight data to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(syncData)
            
            let jsonSizeKB = Double(jsonData.count) / 1024.0
            
            // CRITICAL: WatchConnectivity has size limits (practical limit ~256KB)
            // If data is too large, warn but don't send to avoid failures
            if jsonData.count > 256 * 1024 { // 256 KB limit
                logger.warning("Data size (\(jsonSizeKB) KB) exceeds WatchConnectivity limit (256 KB)")
                return
            }
            
            // Create user info dictionary
            let userInfo: [String: Any] = [
                MessageKey.dataType: DataType.fullSync,
                MessageKey.listsData: jsonData,
                MessageKey.timestamp: Date().timeIntervalSince1970
            ]
            
            // Use transferUserInfo for reliable background transfer
            // This queues the transfer if the device is not reachable
            session.queueUserInfo(userInfo)
            
            logger.info("📤 Sending \(lists.count) lists to paired device via transferUserInfo")
            
        } catch {
            logger.error("Failed to encode lists data: \(error.localizedDescription)")
        }
    }
    
    /// Returns true if the service is ready to communicate with the paired device
    var canCommunicate: Bool {
        guard let session = session else { return false }
        
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled && session.isReachable
        #else
        return session.isReachable
        #endif
    }

    // MARK: - Full Sync

    #if os(iOS)
    /// Sends the iPhone's current lists to the watch, if its app is installed.
    /// Empty results are not sent: the watch ignores them anyway.
    func sendCurrentListsToWatch() {
        guard let session = session,
              session.activationState == .activated,
              session.isWatchAppInstalled else { return }
        guard let lists = listsProvider?(), !lists.isEmpty else { return }
        sendListsData(lists)
    }
    #endif

    #if os(watchOS)
    /// Asks the iPhone for its current lists.
    /// While watch changes are still queued, the request is queued behind them so the iPhone
    /// receives them before replying; otherwise the reply would delete them on the watch.
    func requestFullSync() {
        guard let session = session, session.activationState == .activated else { return }

        let request: [String: Any] = [
            MessageKey.dataType: DataType.fullSyncRequest,
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        guard session.isReachable, !session.hasOutstandingListsTransfer else {
            session.queueUserInfo(request)
            logger.info("Queued full sync request for the iPhone")
            return
        }

        // sendMessage wakes the iPhone app in the background; queue if that fails
        session.sendMessage(request, replyHandler: nil) { [weak self] error in
            self?.logger.error("Full sync request failed, queueing: \(error.localizedDescription)")
            session.queueUserInfo(request)
        }
        logger.info("Requested full sync from the iPhone")
    }
    #endif

    /// Called on the main queue once the session is activated
    func handleActivationCompleted() {
        #if os(iOS)
        sendCurrentListsToWatch()
        #else
        requestFullSync()
        #endif
    }

    #if os(iOS)
    /// Called on the main queue when the watch app is installed/removed or pairing changes
    func handleWatchStateChanged() {
        sendCurrentListsToWatch()
    }
    #endif

    /// Called on the main queue for every message and userInfo from the paired device
    func handleIncomingPayload(_ payload: [String: Any]) {
        #if os(iOS)
        if payload[MessageKey.dataType] as? String == DataType.fullSyncRequest {
            logger.info("📥 Watch requested full sync")
            sendCurrentListsToWatch()
        }
        #endif
    }

    // MARK: - Private Methods
    
    private func updateReachabilityStatus() {
        guard let session = session else { return }
        
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        logger.info("Reachability status updated: \(session.isReachable)")
        
        #if os(iOS)
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        logger.info("iOS status - Paired: \(session.isPaired), Watch App Installed: \(session.isWatchAppInstalled)")
        #endif
    }
    
    private func handleIncomingSyncNotification(_ message: [String: Any]) {
        logger.info("Received sync notification from paired device")
        
        // Post notification to trigger data reload in DataRepository
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("WatchConnectivitySyncReceived"),
                object: nil,
                userInfo: message
            )
        }
    }
    
    private func handleIncomingListsData(_ userInfo: [String: Any]) {
        logger.info("📥 Received lists data from paired device")
        
        guard let jsonData = userInfo[MessageKey.listsData] as? Data else {
            logger.error("Failed to extract lists data from userInfo")
            return
        }
        
        do {
            // Decode lightweight sync data from JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let syncData = try decoder.decode([ListSyncData].self, from: jsonData)
            
            // Convert to full List models (without images)
            let lists = syncData.map { $0.toList() }
            
            logger.info("📥 Successfully decoded \(lists.count) lists from paired device")
            
            // Post notification with decoded lists for ViewModels to handle
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchConnectivityListsDataReceived"),
                    object: nil,
                    userInfo: ["lists": lists]
                )
            }
            
        } catch {
            logger.error("Failed to decode lists data: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isActivated = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isActivated = true
        }
        
        switch activationState {
        case .activated:
            logger.info("WCSession activated successfully")
            updateReachabilityStatus()
            DispatchQueue.main.async {
                self.handleActivationCompleted()
            }

        case .inactive:
            logger.warning("WCSession is inactive")
            
        case .notActivated:
            logger.warning("WCSession is not activated")
            
        @unknown default:
            logger.warning("WCSession activation state unknown")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        logger.info("Session reachability changed: \(session.isReachable)")
        updateReachabilityStatus()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.info("Received message from paired device: \(message)")
        DispatchQueue.main.async {
            self.handleIncomingPayload(message)
        }

        // Check if this is a language update from iOS
        #if os(watchOS)
        if let languageCode = message["language"] as? String {
            handleLanguageUpdate(languageCode)
            return
        }
        #endif
        
        // Check if this is a sync notification
        if message[MessageKey.syncNotification] as? Bool == true {
            handleIncomingSyncNotification(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        logger.info("Received message with reply handler from paired device: \(message)")
        DispatchQueue.main.async {
            self.handleIncomingPayload(message)
        }

        // Check if this is a language update from iOS
        #if os(watchOS)
        if let languageCode = message["language"] as? String {
            handleLanguageUpdate(languageCode)
            replyHandler(["received": true, "language": languageCode])
            return
        }
        #endif
        
        // Check if this is a sync notification
        if message[MessageKey.syncNotification] as? Bool == true {
            handleIncomingSyncNotification(message)
        }
        
        // Send acknowledgment reply
        replyHandler(["received": true])
    }
    
    #if os(watchOS)
    /// Handle language update from iOS
    private func handleLanguageUpdate(_ languageCode: String) {
        // Save to watchOS's own UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            sharedDefaults.set(languageCode, forKey: "AppLanguage")
            sharedDefaults.synchronize()
        }
        
        // Also save to standard UserDefaults as backup
        UserDefaults.standard.set(languageCode, forKey: "AppLanguage")
        UserDefaults.standard.synchronize()
        
        // Trigger WatchLocalizationManager to refresh
        DispatchQueue.main.async {
            WatchLocalizationManager.shared.refreshLanguage()
        }
    }
    #endif
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        logger.info("📥 Received userInfo from paired device")
        DispatchQueue.main.async {
            self.handleIncomingPayload(userInfo)
        }

        // Check if this contains lists data
        if let dataType = userInfo[MessageKey.dataType] as? String {
            if dataType == DataType.fullSync {
                handleIncomingListsData(userInfo)
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("Session deactivated, reactivating...")
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        logger.info("Watch state changed")
        updateReachabilityStatus()
        DispatchQueue.main.async {
            self.handleWatchStateChanged()
        }
    }
    #endif
}

