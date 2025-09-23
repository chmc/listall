import Foundation

extension String {
    
    /// Returns true if the string is empty or contains only whitespace
    var isBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Returns the string trimmed of leading and trailing whitespace
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns a URL if the string is a valid URL
    var asURL: URL? {
        // Don't treat empty strings or single words as URLs
        guard !self.isEmpty && !self.isBlank else { return nil }
        
        // First try direct URL creation
        if let url = URL(string: self), url.scheme != nil {
            // Only return URLs that have a proper scheme
            return url
        }
        
        // If that fails, try adding a scheme for common cases
        if self.hasPrefix("www.") && self.contains(".") {
            return URL(string: "https://" + self)
        }
        
        // For URLs without protocol but with proper domain structure
        if self.contains(".") && !self.hasPrefix("/") && !self.hasPrefix("www.") {
            // Check if it looks like a domain (contains at least one dot and no spaces)
            let components = self.components(separatedBy: ".")
            if components.count >= 2 && !self.contains(" ") && self.count > 3 {
                return URL(string: "https://" + self)
            }
        }
        
        return nil
    }
    
    /// Capitalizes the first letter of the string
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}
