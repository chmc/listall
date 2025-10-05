import SwiftUI
import UIKit

/// Direct UIActivityViewController presentation without sheet wrapper
/// This avoids SwiftUI sheet timing/state issues
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Return a transparent container
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present activity controller when items are available
        guard !activityItems.isEmpty else { return }
        
        // Check if already presenting to avoid duplicate presentations
        guard uiViewController.presentedViewController == nil else { return }
        
        // Create and present activity view controller
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Handle completion
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = CGRect(
                x: uiViewController.view.bounds.midX,
                y: uiViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        // Present immediately
        DispatchQueue.main.async {
            uiViewController.present(activityVC, animated: true)
        }
    }
}

