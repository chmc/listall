//
//  CloudSyncProviding.swift
//  ListAll
//
//  Protocol abstraction for CloudKitService to enable dependency injection and testing.
//

import Foundation
import Combine
import CloudKit

/// Protocol defining the interface for cloud synchronization services.
/// This abstraction allows tests to use mock implementations without triggering CloudKit access.
///
/// Note: This is a simplified protocol focused on the essential sync operations.
/// CloudKitService has its own SyncStatus enum which implementations can use internally.
protocol CloudSyncProviding: AnyObject, ObservableObject {
    // MARK: - Properties

    /// Whether a sync operation is currently in progress
    var isSyncing: Bool { get }

    /// Timestamp of the last successful sync
    var lastSyncDate: Date? { get }

    // MARK: - Sync Operations

    /// Trigger a manual sync operation
    func sync() async

    /// Check the current iCloud account status
    /// - Returns: The current CloudKit account status
    func checkAccountStatus() async -> CKAccountStatus
}
