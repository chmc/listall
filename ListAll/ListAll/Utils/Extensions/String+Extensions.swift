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
        // First try direct URL creation
        if let url = URL(string: self) {
            return url
        }
        
        // If that fails, try adding a scheme for common cases
        if self.hasPrefix("www.") {
            return URL(string: "https://" + self)
        }
        
        // For file paths, try file:// scheme
        if self.hasPrefix("/") {
            return URL(string: "file://" + self)
        }
        
        return nil
    }
    
    /// Capitalizes the first letter of the string
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}
