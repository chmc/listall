#if os(iOS)
import UIKit
#endif
import SwiftUI
import Combine

// MARK: - Haptic Feedback Types
#if os(iOS)
enum HapticFeedbackType {
    case success           // Successful operations (create, save)
    case warning           // Warning operations
    case error            // Error operations
    case selection        // Selection changes
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)  // Impact feedback
    case notification(UINotificationFeedbackGenerator.FeedbackType)  // Notification feedback

    // Convenience cases for common operations
    static let itemCrossed = HapticFeedbackType.impact(.light)
    static let itemUncrossed = HapticFeedbackType.impact(.light)
    static let itemCreated = HapticFeedbackType.notification(.success)
    static let itemDeleted = HapticFeedbackType.notification(.warning)
    static let listCreated = HapticFeedbackType.notification(.success)
    static let listDeleted = HapticFeedbackType.notification(.warning)
    static let listArchived = HapticFeedbackType.notification(.warning)
    static let selectionModeToggled = HapticFeedbackType.selection
    static let itemSelected = HapticFeedbackType.selection
    static let dragStarted = HapticFeedbackType.impact(.medium)
    static let dragDropped = HapticFeedbackType.impact(.light)
}
#else
// macOS stub - no haptic feedback support
enum HapticFeedbackType {
    case success
    case warning
    case error
    case selection
    case impact
    case notification

    // Convenience cases for common operations
    static let itemCrossed = HapticFeedbackType.impact
    static let itemUncrossed = HapticFeedbackType.impact
    static let itemCreated = HapticFeedbackType.notification
    static let itemDeleted = HapticFeedbackType.notification
    static let listCreated = HapticFeedbackType.notification
    static let listDeleted = HapticFeedbackType.notification
    static let listArchived = HapticFeedbackType.notification
    static let selectionModeToggled = HapticFeedbackType.selection
    static let itemSelected = HapticFeedbackType.selection
    static let dragStarted = HapticFeedbackType.impact
    static let dragDropped = HapticFeedbackType.impact
}
#endif

// MARK: - Haptic Manager
class HapticManager: ObservableObject {

    // MARK: - Singleton
    static let shared = HapticManager()

    // MARK: - Properties
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Constants.UserDefaultsKeys.hapticsEnabled)
        }
    }

    #if os(iOS)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    #endif

    // MARK: - Initialization
    private init() {
        // Load user preference
        self.isEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hapticsEnabled)

        // Default to true if not set (first launch)
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.hapticsEnabled) == nil {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hapticsEnabled)
        }

        #if os(iOS)
        // Prepare generators
        prepareGenerators()
        #endif
    }

    // MARK: - Public Methods

    /// Trigger haptic feedback
    func trigger(_ type: HapticFeedbackType) {
        #if os(iOS)
        guard isEnabled else { return }

        switch type {
        case .success:
            notification.notificationOccurred(.success)

        case .warning:
            notification.notificationOccurred(.warning)

        case .error:
            notification.notificationOccurred(.error)

        case .selection:
            selection.selectionChanged()

        case .impact(let style):
            triggerImpact(style: style)

        case .notification(let notificationType):
            notification.notificationOccurred(notificationType)
        }
        #endif
        // macOS: No-op - haptics not supported
    }

    /// Prepare generators for upcoming haptic feedback (reduces latency)
    func prepare(for type: HapticFeedbackType) {
        #if os(iOS)
        guard isEnabled else { return }

        switch type {
        case .success, .warning, .error, .notification:
            notification.prepare()

        case .selection:
            selection.prepare()

        case .impact(let style):
            getImpactGenerator(for: style).prepare()
        }
        #endif
        // macOS: No-op
    }

    // MARK: - Convenience Methods

    /// Trigger haptic for item crossed out
    func itemCrossed() {
        trigger(.itemCrossed)
    }

    /// Trigger haptic for item uncrossed
    func itemUncrossed() {
        trigger(.itemUncrossed)
    }

    /// Trigger haptic for item created
    func itemCreated() {
        trigger(.itemCreated)
    }

    /// Trigger haptic for item deleted
    func itemDeleted() {
        trigger(.itemDeleted)
    }

    /// Trigger haptic for list created
    func listCreated() {
        trigger(.listCreated)
    }

    /// Trigger haptic for list deleted
    func listDeleted() {
        trigger(.listDeleted)
    }

    /// Trigger haptic for list archived
    func listArchived() {
        trigger(.listArchived)
    }

    /// Trigger haptic for selection mode toggled
    func selectionModeToggled() {
        trigger(.selectionModeToggled)
    }

    /// Trigger haptic for item selected in selection mode
    func itemSelected() {
        trigger(.itemSelected)
    }

    /// Trigger haptic for drag started
    func dragStarted() {
        trigger(.dragStarted)
    }

    /// Trigger haptic for drag dropped
    func dragDropped() {
        trigger(.dragDropped)
    }

    // MARK: - Private Methods

    #if os(iOS)
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        selection.prepare()
        notification.prepare()
    }

    private func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = getImpactGenerator(for: style)
        generator.impactOccurred()
    }

    private func getImpactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return impactLight
        case .medium:
            return impactMedium
        case .heavy:
            return impactHeavy
        case .soft:
            return impactSoft
        case .rigid:
            return impactRigid
        @unknown default:
            return impactMedium
        }
    }
    #endif
}

// MARK: - SwiftUI View Extension
#if os(iOS)
extension View {
    /// Add haptic feedback to a view action
    @available(iOS 17.0, *)
    func haptic(_ type: HapticFeedbackType, when condition: Bool = true) -> some View {
        self.onChange(of: condition) { _, newValue in
            if newValue {
                HapticManager.shared.trigger(type)
            }
        }
    }

    /// Add haptic feedback to a view action (iOS 16 compatible)
    func haptic16(_ type: HapticFeedbackType, when condition: Bool = true) -> some View {
        self.onChange(of: condition) { newValue in
            if newValue {
                HapticManager.shared.trigger(type)
            }
        }
    }
}
#endif
