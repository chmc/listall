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
    let coreDataManager = CoreDataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}
