//
//  ListAllWatchApp.swift
//  ListAllWatch Watch App
//
//  Created by Aleksi Sutela on 19.10.2025.
//

import SwiftUI

@main
struct ListAllWatch_Watch_AppApp: App {
    init() {
        // Initialize Core Data on app launch
        _ = CoreDataManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WatchListsView()
        }
    }
}
