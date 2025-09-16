import SwiftUI

@main
struct ListAllApp: App {
    let dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
