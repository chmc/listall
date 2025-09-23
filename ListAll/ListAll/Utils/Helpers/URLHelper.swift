import Foundation
import SwiftUI

/// Helper utility for URL detection and handling in text
struct URLHelper {
    
    /// Detects URLs in a given text string and returns them as an array
    static func detectURLs(in text: String) -> [URL] {
        var urls: [URL] = []
        
        // Use NSDataDetector to find URLs
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches ?? [] {
            if let url = match.url {
                urls.append(url)
            }
        }
        
        // Also check for URLs that might not be detected by NSDataDetector
        // But be more conservative to avoid false positives
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            // Only check words that look like they could be URLs
            if word.contains(".") && word.count > 3 {
                if let url = word.asURL, !urls.contains(url) {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    /// Checks if a string contains any URLs
    static func containsURL(_ text: String) -> Bool {
        return !detectURLs(in: text).isEmpty
    }
    
    /// Opens a URL in the default browser
    static func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    /// Creates an attributed string with clickable links for URLs that can wrap properly
    static func createAttributedString(from text: String, 
                                     font: UIFont = UIFont.systemFont(ofSize: 16),
                                     textColor: UIColor = .label,
                                     linkColor: UIColor = .systemBlue) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create paragraph style that forces character-level wrapping ANYWHERE
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping // Break anywhere, even within words/URLs
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 0
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.headIndent = 0
        paragraphStyle.tailIndent = 0
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.minimumLineHeight = font.lineHeight
        paragraphStyle.maximumLineHeight = font.lineHeight * 1.2
        
        // Set default attributes with FORCED line breaking
        attributedString.addAttributes([
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: text.count))
        
        // Find and style URLs - but DON'T override the paragraph style
        let urls = detectURLs(in: text)
        for url in urls {
            let urlString = url.absoluteString
            var searchStartIndex = 0
            
            // Find all occurrences of this URL
            while searchStartIndex < text.count {
                let remainingRange = NSRange(location: searchStartIndex, length: text.count - searchStartIndex)
                let foundRange = (text as NSString).range(of: urlString, options: [], range: remainingRange)
                
                if foundRange.location == NSNotFound {
                    break
                }
                
                // Apply URL attributes WITHOUT changing the paragraph style
                attributedString.addAttributes([
                    .foregroundColor: linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: url
                ], range: foundRange)
                
                searchStartIndex = foundRange.location + foundRange.length
            }
        }
        
        return attributedString
    }
}

/// SwiftUI view for displaying text with clickable URLs using UILabel approach
struct ClickableTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let linkColor: UIColor
    let lineLimit: Int?
    
    init(text: String, 
         font: UIFont = UIFont.systemFont(ofSize: 16),
         textColor: UIColor = .label,
         linkColor: UIColor = .systemBlue,
         lineLimit: Int? = nil) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.linkColor = linkColor
        self.lineLimit = lineLimit
    }
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0 // Allow unlimited lines
        label.lineBreakMode = .byCharWrapping // Force character-level breaking
        label.font = font
        label.textColor = textColor
        label.backgroundColor = .clear
        label.isUserInteractionEnabled = true
        
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        // Check if text contains URLs
        if URLHelper.containsURL(text) {
            // Create attributed string with clickable URLs
            let attributedString = URLHelper.createAttributedString(
                from: text,
                font: font,
                textColor: textColor,
                linkColor: linkColor
            )
            uiView.attributedText = attributedString
            
            // Add tap gesture for URL handling
            uiView.gestureRecognizers?.removeAll()
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            uiView.addGestureRecognizer(tapGesture)
        } else {
            // Plain text without URLs
            uiView.text = text
            uiView.gestureRecognizers?.removeAll()
        }
        
        // Ensure proper line breaking
        uiView.lineBreakMode = .byCharWrapping
        uiView.numberOfLines = 0
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: ClickableTextView
        
        init(_ parent: ClickableTextView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let label = gesture.view as? UILabel,
                  let attributedText = label.attributedText else { return }
            
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            let textStorage = NSTextStorage(attributedString: attributedText)
            
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            textContainer.lineBreakMode = label.lineBreakMode
            
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            let locationOfTouchInLabel = gesture.location(in: label)
            let textBoundingBox = layoutManager.usedRect(for: textContainer)
            let textContainerOffset = CGPoint(x: (label.bounds.width - textBoundingBox.width) * 0.0, 
                                            y: (label.bounds.height - textBoundingBox.height) * 0.0)
            let locationOfTouchInTextContainer = CGPoint(x: locationOfTouchInLabel.x - textContainerOffset.x,
                                                       y: locationOfTouchInLabel.y - textContainerOffset.y)
            let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInTextContainer, 
                                                               in: textContainer, 
                                                               fractionOfDistanceBetweenInsertionPoints: nil)
            
            // Check if tapped character has a link attribute
            if indexOfCharacter < attributedText.length {
                if let url = attributedText.attribute(.link, at: indexOfCharacter, effectiveRange: nil) as? URL {
                    URLHelper.openURL(url)
                }
            }
        }
    }
}
