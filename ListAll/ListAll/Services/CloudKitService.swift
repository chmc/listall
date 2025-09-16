//
//  CloudKitService.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation
import CloudKit
import CoreData

class CloudKitService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let container = CKContainer(identifier: "iCloud.io.github.chmc.ListAll")
    private let dataManager = DataManager.shared
    
    init() {
        // CloudKit is configured through Core Data's CloudKit integration
        // This service will handle additional CloudKit operations if needed
    }
    
    func sync() {
        isSyncing = true
        syncError = nil
        
        // CloudKit sync is handled automatically by Core Data
        // This method can be used for manual sync triggers or status updates
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSyncing = false
            self.lastSyncDate = Date()
        }
    }
    
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }
}
