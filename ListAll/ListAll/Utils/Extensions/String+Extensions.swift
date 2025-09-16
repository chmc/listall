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
        return URL(string: self)
    }
    
    /// Capitalizes the first letter of the string
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}
