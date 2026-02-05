//
//  ListAllMacApp.swift
//  ListAllMac
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct ListAllMacApp: App {
    /// AppDelegate adapter for macOS Services menu registration
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Check if running in unit test environment (not UI tests)
    private static let isUnitTesting: Bool = {
        // XCTestConfigurationFilePath is set for unit tests but we also check we're NOT in UI test mode
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil &&
        !ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }()

    /// Lazy wrapper to prevent DataManager initialization during unit tests.
    /// @StateObject properties initialize BEFORE init() runs, so we can't use init() checks.
    /// This wrapper defers DataManager.shared access until first use in the view body.
    private class DataManagerWrapper: ObservableObject {
        lazy var instance: DataManager = DataManager.shared
    }

    @StateObject private var dataManagerWrapper = DataManagerWrapper()

    /// Convenience accessor for views that need DataManager
    private var dataManager: DataManager {
        dataManagerWrapper.instance
    }

    init() {
        print("🚀 ListAllMacApp.init() STARTING")
        print("🔍 Arguments: \(ProcessInfo.processInfo.arguments)")

        // CRITICAL: Skip full app initialization during UNIT tests
        // Unit tests inject their own Core Data stacks and don't need the full app lifecycle
        // This prevents singleton initialization issues and memory corruption from
        // repeated test host launches
        if ListAllMacApp.isUnitTesting {
            print("🧪 ListAllMacApp: Unit test mode - skipping full app initialization")
            return
        }

        // CRITICAL: Force app activation during UI tests
        // macOS UI tests launch the app in background by default, causing test timeouts
        // NOTE: We cannot call NSApp.setActivationPolicy() here in init() because
        // NSApplication may not be fully initialized yet. This causes assertion failures.
        // The activation is handled in AppDelegate.applicationDidFinishLaunching() instead.
        if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
            print("🧪 ListAllMacApp.init(): UI test mode detected - activation will happen in AppDelegate")
        }

        // CRITICAL: Force CoreDataManager initialization FIRST to ensure UITEST_MODE is detected
        // before any data operations. The isUITest flag is evaluated during lazy initialization.
        _ = CoreDataManager.shared.persistentContainer

        // Pre-warm ImageService to avoid first-use delay when opening edit dialogs
        // The singleton initialization and cache setup takes time on first access
        _ = ImageService.shared

        // Setup UI test environment if needed
        setupUITestEnvironment()

        print("🚀 ListAllMacApp.init() COMPLETED")
    }

    var body: some Scene {
        WindowGroup {
            // CRITICAL: Unit tests must not access singletons (DataManager, CoreDataManager)
            // This prevents App Groups permission dialogs on unsigned test builds
            if Self.isUnitTesting {
                Text("Unit Test Mode")
                    .frame(width: 200, height: 100)
            } else {
                MacMainView()
                    .environmentObject(dataManager)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .onContinueUserActivity("io.github.chmc.ListAll.viewing-list") { activity in
                        handleIncomingActivity(activity)
                    }
                    .onContinueUserActivity("io.github.chmc.ListAll.viewing-item") { activity in
                        handleIncomingActivity(activity)
                    }
                    .onContinueUserActivity("io.github.chmc.ListAll.browsing-lists") { activity in
                        handleIncomingActivity(activity)
                    }
            }
        }
        .commands {
            // Add macOS-specific menu commands
            AppCommands()
        }

        #if os(macOS)
        Settings {
            // CRITICAL: Unit tests must not access DataManager to avoid App Groups dialogs
            if Self.isUnitTesting {
                Text("Settings disabled in unit test mode")
                    .frame(width: 200, height: 100)
            } else {
                MacSettingsView()
                    .environmentObject(dataManager)
            }
        }

        // Quick Entry Window (Task 12.10)
        // A floating window for quickly adding items from anywhere
        Window("Quick Entry", id: "quickEntry") {
            if Self.isUnitTesting {
                Text("Quick Entry disabled in unit test mode")
                    .frame(width: 200, height: 100)
            } else {
                QuickEntryView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #endif
    }

    // MARK: - Handoff Support

    /// Handle incoming Handoff activity from another device
    /// - Parameter activity: The NSUserActivity to process
    private func handleIncomingActivity(_ activity: NSUserActivity) {
        guard let target = HandoffService.extractNavigationTarget(from: activity) else {
            print("⚠️ Handoff: Could not extract navigation target from activity")
            return
        }

        switch target {
        case .mainLists:
            print("💻 Handoff: Navigating to main lists")
            // No navigation needed - already at root

        case .list(let id, let name):
            print("💻 Handoff: Navigating to list '\(name ?? "unknown")' (\(id))")
            // Post notification that MacMainView can respond to
            NotificationCenter.default.post(
                name: NSNotification.Name("HandoffNavigateToList"),
                object: nil,
                userInfo: ["listId": id]
            )

        case .item(let id, let listId, let title):
            print("💻 Handoff: Navigating to item '\(title ?? "unknown")' (\(id)) in list (\(listId))")
            NotificationCenter.default.post(
                name: NSNotification.Name("HandoffNavigateToItem"),
                object: nil,
                userInfo: ["itemId": id, "listId": listId]
            )
        }
    }

    // MARK: - UI Test Environment Setup

    /// Configure the app for UI testing with deterministic data
    private func setupUITestEnvironment() {
        // Check if running in UI test mode using UITEST_MODE (same as iOS)
        guard UITestDataService.isUITesting else {
            return
        }

        print("🧪 UI Test mode detected - UI tests using isolated database")

        // CRITICAL: AppleLanguages is already set by Fastlane's localize_simulator(true)
        // before app launch. We should NOT override it here.
        // Just log what it's set to for debugging purposes.
        if let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] {
            print("🧪 AppleLanguages already set by simulator: \(appleLanguages)")
        } else {
            // Fallback: If for some reason AppleLanguages isn't set, default to English
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            print("🧪 Set AppleLanguages to [en] (fallback default)")
        }

        // Disable iCloud sync during UI tests to prevent interference
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")

        // Clear existing data to ensure clean state
        clearAllData()

        // Only populate test data if not skipped (for empty state screenshots)
        if !ProcessInfo.processInfo.arguments.contains("SKIP_TEST_DATA") {
            populateTestData()
        } else {
            print("🧪 Skipping test data population for empty state screenshot")
        }
    }

    /// Clear all existing data from the data store
    /// SAFETY: This method verifies we're using the isolated test database before clearing
    private func clearAllData() {
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.viewContext

        // CRITICAL SAFETY CHECK: Verify we're using the test database before clearing
        if let storeURL = coreDataManager.persistentContainer.persistentStoreDescriptions.first?.url {
            let storeFileName = storeURL.lastPathComponent
            guard storeFileName.contains("UITests") || storeURL.absoluteString.contains("/dev/null") else {
                print("🛑 SAFETY: Refusing to clear data - not using test database!")
                print("🛑 Current database: \(storeFileName)")
                fatalError("Attempted to clear production data during UI tests. Database file: \(storeFileName)")
            }
            print("✅ Safety verified: Using test database '\(storeFileName)'")
        }

        // Delete all existing lists (which will cascade delete items and images)
        let listRequest: NSFetchRequest<NSFetchRequestResult> = ListEntity.fetchRequest()
        let listDeleteRequest = NSBatchDeleteRequest(fetchRequest: listRequest)

        do {
            try context.execute(listDeleteRequest)
            try context.save()
            print("🧪 Cleared existing data for UI tests")
        } catch {
            print("❌ Failed to clear data for UI tests: \(error)")
        }
    }

    /// Populate the data store with deterministic test data
    private func populateTestData() {
        let testLists = UITestDataService.generateTestData()

        // Add each test list to the data manager
        for list in testLists {
            dataManager.addList(list)

            // Add items for each list
            for item in list.items {
                dataManager.addItem(item, to: list.id)
            }
        }

        // Force reload to ensure UI shows the test data
        dataManager.loadData()

        print("🧪 Populated \(testLists.count) test lists with deterministic data")
    }
}

// MARK: - AppDelegate for Services Registration

/// AppDelegate handles macOS-specific lifecycle events.
/// Primary purpose: Register the ServicesProvider for system-wide Services menu integration.
/// Also handles fallback window creation for macOS Tahoe where SwiftUI WindowGroup may fail.
class AppDelegate: NSObject, NSApplicationDelegate {

    /// The services provider instance (must be retained for Services menu to work)
    private var servicesProvider: ServicesProvider?

    /// Fallback window for macOS Tahoe bug workaround
    /// On macOS 26.x (Tahoe), SwiftUI's WindowGroup may not create initial windows.
    /// This property holds a manually-created window as a fallback.
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Detect test environment
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITest = ProcessInfo.processInfo.arguments.contains("UITEST_MODE")

        // Skip ONLY for unit tests (test environment WITHOUT UITEST_MODE)
        // UI tests need AppDelegate to run for window creation
        if isTestEnvironment && !isUITest {
            print("🧪 AppDelegate: Unit test mode - skipping full initialization")
            return
        }

        // CRITICAL: Always set activation policy to .regular on macOS Tahoe+
        // This is required for SwiftUI WindowGroup to create windows properly.
        // Previously only done for UI tests, but macOS 26.x requires it for all launches.
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if isUITest {
            print("🧪 AppDelegate: UI test mode - app activated to foreground")
        }

        print("🚀 AppDelegate: Registering Services provider")

        // CRITICAL: Create and register the services provider
        // This must be done AFTER the app is fully initialized
        servicesProvider = ServicesProvider.shared
        NSApplication.shared.servicesProvider = servicesProvider

        print("✅ AppDelegate: Services provider registered")

        // IMPORTANT: Only ONE service provider can be registered per app.
        // The ServicesProvider class handles ALL services defined in Info.plist.

        // Request notification permissions for service feedback
        requestNotificationPermissions()

        // WORKAROUND: macOS Tahoe (26.x) SwiftUI WindowGroup bug
        // SwiftUI may not create initial window on app launch.
        // For UI tests, create window IMMEDIATELY to avoid launch timeout.
        // For normal use, wait 1 second to give SwiftUI a chance.
        if isUITest {
            print("🧪 AppDelegate: UI test mode - creating window immediately")
            ensureMainWindowExists()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.ensureMainWindowExists()
            }
        }
    }

    /// Ensure the main window exists, creating a fallback if SwiftUI failed to create one.
    /// This is a workaround for macOS Tahoe (26.x) where SwiftUI WindowGroup
    /// may not create the initial window on app launch.
    private func ensureMainWindowExists() {
        // Check if SwiftUI already created a window
        let existingWindows = NSApp.windows.filter { window in
            // Filter out panels, sheets, and other non-main windows
            window.isVisible && !window.isSheet && window.styleMask.contains(.titled)
        }

        if !existingWindows.isEmpty {
            print("✅ AppDelegate: SwiftUI created \(existingWindows.count) window(s) - no fallback needed")
            return
        }

        print("⚠️ AppDelegate: No SwiftUI windows detected - creating fallback window (macOS Tahoe workaround)")

        // Create the main window manually using NSHostingController
        let contentView = MacMainView()
            .environmentObject(DataManager.shared)
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)

        let hostingController = NSHostingController(rootView: contentView)

        // Create window with standard macOS app styling
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "ListAll"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("MainWindow")

        // Set minimum size for usability
        window.minSize = NSSize(width: 800, height: 600)

        // Make window key and visible
        window.makeKeyAndOrderFront(nil)

        // Retain the window
        self.fallbackWindow = window

        print("✅ AppDelegate: Fallback window created and displayed")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// Request permission to show notifications for Services feedback
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("⚠️ Notification permissions error: \(error)")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
    }
}
