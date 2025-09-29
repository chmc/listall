import Foundation
import SwiftUI

/// Represents a text component that can be either normal text or a URL
struct TextComponent {
    let text: String
    let isURL: Bool
    let url: URL?
    
    init(text: String, isURL: Bool = false, url: URL? = nil) {
        self.text = text
        self.isURL = isURL
        self.url = url
    }
}

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
    
    /// Parses text into components separating normal text from URLs
    static func parseTextComponents(from text: String) -> [TextComponent] {
        var components: [TextComponent] = []
        let urls = detectURLs(in: text)
        
        // If no URLs found, return the entire text as a single component
        guard !urls.isEmpty else {
            return [TextComponent(text: text)]
        }
        
        var processedLength = 0
        
        // Sort URLs by their position in the text
        let sortedURLRanges = urls.compactMap { url -> (url: URL, range: NSRange)? in
            let urlString = url.absoluteString
            let range = (text as NSString).range(of: urlString)
            return range.location != NSNotFound ? (url: url, range: range) : nil
        }.sorted { $0.range.location < $1.range.location }
        
        for (url, range) in sortedURLRanges {
            let urlString = url.absoluteString
            
            // Add text before the URL (if any)
            if range.location > processedLength {
                let beforeURLRange = NSRange(location: processedLength, length: range.location - processedLength)
                let beforeURLText = (text as NSString).substring(with: beforeURLRange)
                if !beforeURLText.isEmpty {
                    components.append(TextComponent(text: beforeURLText))
                }
            }
            
            // Add the URL component
            components.append(TextComponent(text: urlString, isURL: true, url: url))
            processedLength = range.location + range.length
        }
        
        // Add any remaining text after the last URL
        if processedLength < text.count {
            let remainingRange = NSRange(location: processedLength, length: text.count - processedLength)
            let remainingText = (text as NSString).substring(with: remainingRange)
            if !remainingText.isEmpty {
                components.append(TextComponent(text: remainingText))
            }
        }
        
        return components
    }
}

/// SwiftUI view for displaying mixed text with normal text and clickable URLs
struct MixedTextView: View {
    let text: String
    let font: Font
    let textColor: Color
    let linkColor: Color
    let isCrossedOut: Bool
    let opacity: Double
    
    init(text: String,
         font: Font = .body,
         textColor: Color = .primary,
         linkColor: Color = .blue,
         isCrossedOut: Bool = false,
         opacity: Double = 1.0) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.linkColor = linkColor
        self.isCrossedOut = isCrossedOut
        self.opacity = opacity
    }
    
    var body: some View {
        let components = URLHelper.parseTextComponents(from: text)
        
        // Use a flexible layout that wraps text components
        ViewThatFits(in: .horizontal) {
            // Try single line first
            HStack(spacing: 0) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    componentView(for: component)
                }
            }
            
            // Fall back to wrapping layout
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 0) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    componentView(for: component)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    @ViewBuilder
    private func componentView(for component: TextComponent) -> some View {
        if component.isURL, let url = component.url {
            // Clickable URL that opens in browser with explicit gesture priority
            Link(destination: url) {
                Text(component.text)
                    .font(font)
                    .foregroundColor(linkColor)
                    .underline()
                    .opacity(opacity)
                    .strikethrough(isCrossedOut, color: textColor.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle()) // Ensure clean button style
            .contentShape(Rectangle()) // Make the entire URL area tappable
            .allowsHitTesting(true) // Explicitly allow hit testing
        } else {
            // Normal text - not clickable, allows parent gestures
            Text(component.text)
                .font(font)
                .foregroundColor(textColor)
                .opacity(opacity)
                .strikethrough(isCrossedOut, color: textColor.opacity(0.7))
                .allowsHitTesting(false) // Allow gestures to pass through to parent
        }
    }
}

