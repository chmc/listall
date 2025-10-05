import UIKit
import LinkPresentation

/// Custom activity item source that provides better control over sharing
class TextActivityItemSource: NSObject, UIActivityItemSource {
    let text: String
    let subject: String
    
    init(text: String, subject: String) {
        self.text = text
        self.subject = subject
        super.init()
    }
    
    // Required: Return placeholder during initialization
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return text
    }
    
    // Required: Return actual item when activity is selected
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return text
    }
    
    // Optional: Provide subject for email/messages
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return subject
    }
    
    // Optional: Provide thumbnail
    @available(iOS 13.0, *)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = subject
        return metadata
    }
}

/// Custom activity item source for files
class FileActivityItemSource: NSObject, UIActivityItemSource {
    let fileURL: URL
    let filename: String
    
    init(fileURL: URL, filename: String) {
        self.fileURL = fileURL
        self.filename = filename
        super.init()
    }
    
    // Required: Return placeholder during initialization
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }
    
    // Required: Return actual item when activity is selected
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return fileURL
    }
    
    // Optional: Provide data type identifier
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if filename.hasSuffix(".json") {
            return "public.json"
        } else if filename.hasSuffix(".txt") {
            return "public.plain-text"
        }
        return "public.data"
    }
    
    // Optional: Provide subject/filename
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return filename
    }
    
    // Optional: Provide thumbnail
    @available(iOS 13.0, *)
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = filename
        metadata.originalURL = fileURL
        return metadata
    }
}

