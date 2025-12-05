//
//  ListAllMacApp.swift
//  ListAllMac
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import SwiftUI
import CoreData

@main
struct ListAllMacApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
