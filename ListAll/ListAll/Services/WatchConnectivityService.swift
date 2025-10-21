import Foundation
import Combine
import WatchConnectivity
import os.log

/// Service for handling communication between iOS and watchOS apps using WatchConnectivity framework
/// This service provides direct device-to-device communication when both devices are paired and in range
/// Complements CloudKit sync by providing instant notifications of data changes
class WatchConnectivityService: NSObject, ObservableObject {
    
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
        
        // Check if this is a sync notification
        if message[MessageKey.syncNotification] as? Bool == true {
            handleIncomingSyncNotification(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        logger.info("Received message with reply handler from paired device: \(message)")
        
        // Check if this is a sync notification
        if message[MessageKey.syncNotification] as? Bool == true {
            handleIncomingSyncNotification(message)
        }
        
        // Send acknowledgment reply
        replyHandler(["received": true])
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

