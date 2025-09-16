//
//  ListAllApp.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import SwiftUI

@main
struct ListAllApp: App {
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
