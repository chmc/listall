import Foundation
import Combine
import WatchConnectivity
import os.log

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
    
    static let shared = WatchConnectivityService()
    
    // MARK: - Properties
    
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var isActivated: Bool = false
    
    #if os(iOS)
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
    #endif
    
    private let session: WCSession?
    private let logger = Logger(subsystem: "com.listall", category: "WatchConnectivity")
    
    // MARK: - Message Keys
    
    private enum MessageKey {
        static let syncNotification = "syncNotification"
        static let timestamp = "timestamp"
        static let listsData = "listsData"
        static let dataType = "dataType"
    }
    
    private enum DataType {
        static let fullSync = "fullSync"
    }
    
    // MARK: - Initialization
    
    override init() {
        // Initialize session if supported on this device
        if WCSession.isSupported() {
            self.session = WCSession.default
        } else {
            self.session = nil
            logger.warning("WatchConnectivity is not supported on this device")
        }
        
        super.init()
        
        // Activate session if available
        if let session = session {
            session.delegate = self
            session.activate()
            logger.info("WatchConnectivity session activation requested")
        }
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
            _ = session.transferUserInfo(message)
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
        let ts = Self.timestamp()
        
        guard let session = session else {
            #if os(iOS)
            print("[\(ts)] ❌ [iOS] Cannot send lists data: WatchConnectivity not supported")
            #elseif os(watchOS)
            print("[\(ts)] ❌ [watchOS] Cannot send lists data: WatchConnectivity not supported")
            #endif
            logger.warning("Cannot send lists data: WatchConnectivity not supported")
            return
        }
        
        guard session.activationState == .activated else {
            #if os(iOS)
            print("[\(ts)] ❌ [iOS] Cannot send lists data: session not activated (state: \(session.activationState.rawValue))")
            #elseif os(watchOS)
            print("[\(ts)] ❌ [watchOS] Cannot send lists data: session not activated (state: \(session.activationState.rawValue))")
            #endif
            logger.warning("Cannot send lists data: session not activated")
            return
        }
        
        #if os(iOS)
        print("[\(ts)] 📤 [iOS] Session state: activated=\(session.activationState == .activated), reachable=\(session.isReachable)")
        print("[\(ts)] 📤 [iOS] Encoding \(lists.count) lists...")
        #elseif os(watchOS)
        print("[\(ts)] 📤 [watchOS] Session state: activated=\(session.activationState == .activated), reachable=\(session.isReachable)")
        print("[\(ts)] 📤 [watchOS] Encoding \(lists.count) lists...")
        #endif
        
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
                
                if list.items.count != cleanedList.items.count {
                    #if os(iOS)
                    print("[\(ts)] 🧹 [iOS] Deduplicated '\(list.name)': \(list.items.count) → \(cleanedList.items.count) items")
                    #elseif os(watchOS)
                    print("[\(ts)] 🧹 [watchOS] Deduplicated '\(list.name)': \(list.items.count) → \(cleanedList.items.count) items")
                    #endif
                }
                
                return cleanedList
            }
            
            if totalItemsBefore != totalItemsAfter {
                #if os(iOS)
                print("[\(ts)] 🧹 [iOS] Total deduplication: \(totalItemsBefore) → \(totalItemsAfter) items (removed \(totalItemsBefore - totalItemsAfter) duplicates)")
                #elseif os(watchOS)
                print("[\(ts)] 🧹 [watchOS] Total deduplication: \(totalItemsBefore) → \(totalItemsAfter) items (removed \(totalItemsBefore - totalItemsAfter) duplicates)")
                #endif
            } else {
                #if os(iOS)
                print("[\(ts)] ✅ [iOS] No duplicates found during sync (\(totalItemsAfter) unique items)")
                #elseif os(watchOS)
                print("[\(ts)] ✅ [watchOS] No duplicates found during sync (\(totalItemsAfter) unique items)")
                #endif
            }
            
            // Log per-list item counts for verification
            #if os(iOS)
            print("[\(ts)] 📊 [iOS] Per-list item counts:")
            for list in deduplicatedLists {
                print("[\(ts)]   - '\(list.name)': \(list.items.count) items")
            }
            #elseif os(watchOS)
            print("[\(ts)] 📊 [watchOS] Per-list item counts:")
            for list in deduplicatedLists {
                print("[\(ts)]   - '\(list.name)': \(list.items.count) items")
            }
            #endif
            
            // Convert to lightweight sync models (exclude images)
            let syncData = deduplicatedLists.map { ListSyncData(from: $0) }
            
            // Encode lightweight data to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(syncData)
            
            let jsonSizeKB = Double(jsonData.count) / 1024.0
            let ts2 = Self.timestamp()
            #if os(iOS)
            print("[\(ts2)] 📤 [iOS] Encoded data size: \(String(format: "%.2f", jsonSizeKB)) KB")
            #elseif os(watchOS)
            print("[\(ts2)] 📤 [watchOS] Encoded data size: \(String(format: "%.2f", jsonSizeKB)) KB")
            #endif
            
            // CRITICAL: WatchConnectivity has size limits (practical limit ~256KB)
            // If data is too large, warn but don't send to avoid failures
            if jsonData.count > 256 * 1024 { // 256 KB limit
                #if os(iOS)
                print("[\(ts2)] ⚠️ [iOS] Data too large (\(String(format: "%.2f", jsonSizeKB)) KB) - skipping transfer")
                print("[\(ts2)] ⚠️ [iOS] WatchConnectivity limit is ~256KB. You have \(lists.count) lists with many items/images.")
                print("[\(ts2)] 💡 [iOS] Recommendation: Reduce image sizes or use CloudKit for large datasets")
                #elseif os(watchOS)
                print("[\(ts2)] ⚠️ [watchOS] Data too large (\(String(format: "%.2f", jsonSizeKB)) KB) - skipping transfer")
                #endif
                logger.warning("Data size (\(jsonSizeKB) KB) exceeds WatchConnectivity limit (256 KB)")
                return
            }
            
            // Create user info dictionary
            let userInfo: [String: Any] = [
                MessageKey.dataType: DataType.fullSync,
                MessageKey.listsData: jsonData,
                MessageKey.timestamp: Date().timeIntervalSince1970
            ]
            
            let ts3 = Self.timestamp()
            #if os(iOS)
            print("[\(ts3)] 📤 [iOS] Calling session.transferUserInfo()...")
            print("[\(ts3)] 📤 [iOS] Outstanding transfers before: \(session.outstandingUserInfoTransfers.count)")
            #elseif os(watchOS)
            print("[\(ts3)] 📤 [watchOS] Calling session.transferUserInfo()...")
            print("[\(ts3)] 📤 [watchOS] Outstanding transfers before: \(session.outstandingUserInfoTransfers.count)")
            #endif
            
            // Use transferUserInfo for reliable background transfer
            // This queues the transfer if the device is not reachable
            let transfer = session.transferUserInfo(userInfo)
            
            let ts4 = Self.timestamp()
            #if os(iOS)
            print("[\(ts4)] 📤 [iOS] transferUserInfo() called successfully")
            print("[\(ts4)] 📤 [iOS] Transfer isTransferring: \(transfer.isTransferring)")
            print("[\(ts4)] 📤 [iOS] Outstanding transfers after: \(session.outstandingUserInfoTransfers.count)")
            print("[\(ts4)] ✅ [iOS] Queued transfer of \(lists.count) lists (\(String(format: "%.2f", jsonSizeKB)) KB)")
            #elseif os(watchOS)
            print("[\(ts4)] 📤 [watchOS] transferUserInfo() called successfully")
            print("[\(ts4)] 📤 [watchOS] Transfer isTransferring: \(transfer.isTransferring)")
            print("[\(ts4)] 📤 [watchOS] Outstanding transfers after: \(session.outstandingUserInfoTransfers.count)")
            print("[\(ts4)] ✅ [watchOS] Queued transfer of \(lists.count) lists (\(String(format: "%.2f", jsonSizeKB)) KB)")
            #endif
            
            logger.info("📤 Sending \(lists.count) lists to paired device via transferUserInfo")
            
        } catch {
            let tsErr = Self.timestamp()
            #if os(iOS)
            print("[\(tsErr)] ❌ [iOS] Failed to encode lists data: \(error.localizedDescription)")
            #elseif os(watchOS)
            print("[\(tsErr)] ❌ [watchOS] Failed to encode lists data: \(error.localizedDescription)")
            #endif
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
        let ts = Self.timestamp()
        
        #if os(watchOS)
        print("[\(ts)] 📥 [watchOS] handleIncomingListsData started")
        #elseif os(iOS)
        print("[\(ts)] 📥 [iOS] handleIncomingListsData started")
        #endif
        
        logger.info("📥 Received lists data from paired device")
        
        guard let jsonData = userInfo[MessageKey.listsData] as? Data else {
            let tsErr = Self.timestamp()
            #if os(watchOS)
            print("[\(tsErr)] ❌ [watchOS] Failed to extract lists data from userInfo")
            #elseif os(iOS)
            print("[\(tsErr)] ❌ [iOS] Failed to extract lists data from userInfo")
            #endif
            logger.error("Failed to extract lists data from userInfo")
            return
        }
        
        let ts2 = Self.timestamp()
        let dataSize = Double(jsonData.count) / 1024.0
        #if os(watchOS)
        print("[\(ts2)] 📥 [watchOS] Extracted JSON data: \(String(format: "%.2f", dataSize)) KB")
        #elseif os(iOS)
        print("[\(ts2)] 📥 [iOS] Extracted JSON data: \(String(format: "%.2f", dataSize)) KB")
        #endif
        
        do {
            // Decode lightweight sync data from JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let syncData = try decoder.decode([ListSyncData].self, from: jsonData)
            
            // Convert to full List models (without images)
            let lists = syncData.map { $0.toList() }
            
            let ts3 = Self.timestamp()
            #if os(watchOS)
            print("[\(ts3)] ✅ [watchOS] Successfully decoded \(lists.count) lists from paired device")
            #elseif os(iOS)
            print("[\(ts3)] ✅ [iOS] Successfully decoded \(lists.count) lists from paired device")
            #endif
            
            logger.info("📥 Successfully decoded \(lists.count) lists from paired device")
            
            // Post notification with decoded lists for ViewModels to handle
            let ts4 = Self.timestamp()
            #if os(watchOS)
            print("[\(ts4)] 📥 [watchOS] Posting WatchConnectivityListsDataReceived notification...")
            #elseif os(iOS)
            print("[\(ts4)] 📥 [iOS] Posting WatchConnectivityListsDataReceived notification...")
            #endif
            
            DispatchQueue.main.async {
                let ts5 = Self.timestamp()
                #if os(watchOS)
                print("[\(ts5)] 📥 [watchOS] Notification posted to main thread")
                #elseif os(iOS)
                print("[\(ts5)] 📥 [iOS] Notification posted to main thread")
                #endif
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchConnectivityListsDataReceived"),
                    object: nil,
                    userInfo: ["lists": lists]
                )
            }
            
        } catch {
            let tsErr = Self.timestamp()
            #if os(watchOS)
            print("[\(tsErr)] ❌ [watchOS] Failed to decode lists data: \(error.localizedDescription)")
            #elseif os(iOS)
            print("[\(tsErr)] ❌ [iOS] Failed to decode lists data: \(error.localizedDescription)")
            #endif
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
        print("🌍 [watchOS] Received language update from iOS: \(languageCode)")
        
        // Save to watchOS's own UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.io.github.chmc.ListAll") {
            sharedDefaults.set(languageCode, forKey: "AppLanguage")
            sharedDefaults.synchronize()
            print("🌍 [watchOS] Saved language '\(languageCode)' to App Groups")
        }
        
        // Also save to standard UserDefaults as backup
        UserDefaults.standard.set(languageCode, forKey: "AppLanguage")
        UserDefaults.standard.synchronize()
        
        // Trigger WatchLocalizationManager to refresh
        DispatchQueue.main.async {
            WatchLocalizationManager.shared.refreshLanguage()
            print("🌍 [watchOS] Language refresh triggered")
        }
    }
    #endif
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let ts = Self.timestamp()
        
        #if os(watchOS)
        print("[\(ts)] 📥 [watchOS] didReceiveUserInfo CALLED - WATCH RECEIVED DATA!")
        print("[\(ts)] 📥 [watchOS] userInfo keys: \(userInfo.keys)")
        #elseif os(iOS)
        print("[\(ts)] 📥 [iOS] didReceiveUserInfo CALLED - iOS RECEIVED DATA!")
        print("[\(ts)] 📥 [iOS] userInfo keys: \(userInfo.keys)")
        #endif
        
        logger.info("📥 Received userInfo from paired device")
        
        // Check if this contains lists data
        if let dataType = userInfo[MessageKey.dataType] as? String {
            let ts2 = Self.timestamp()
            #if os(watchOS)
            print("[\(ts2)] 📥 [watchOS] dataType: \(dataType)")
            #elseif os(iOS)
            print("[\(ts2)] 📥 [iOS] dataType: \(dataType)")
            #endif
            
            if dataType == DataType.fullSync {
                let ts3 = Self.timestamp()
                #if os(watchOS)
                print("[\(ts3)] 📥 [watchOS] Calling handleIncomingListsData")
                #elseif os(iOS)
                print("[\(ts3)] 📥 [iOS] Calling handleIncomingListsData")
                #endif
                handleIncomingListsData(userInfo)
            }
        } else {
            let tsErr = Self.timestamp()
            #if os(watchOS)
            print("[\(tsErr)] ⚠️ [watchOS] No dataType found in userInfo")
            #elseif os(iOS)
            print("[\(tsErr)] ⚠️ [iOS] No dataType found in userInfo")
            #endif
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
    }
    #endif
}

