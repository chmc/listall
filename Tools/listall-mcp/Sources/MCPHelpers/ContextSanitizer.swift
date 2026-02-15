import Foundation

/// Sanitizes context strings for use in folder/file names
public enum ContextSanitizer {
    /// Sanitize context string for use in folder/file names
    /// Strips platform prefixes AND suffixes to keep folder names task-focused
    public static func sanitize(_ context: String?) -> String {
        guard let ctx = context, !ctx.isEmpty else {
            return "screenshot"
        }

        var cleaned = ctx.lowercased()
        let platformPatterns = ["macos", "ios", "iphone", "ipad", "watch", "watchos"]

        // Remove ALL platform prefixes (loop until none remain)
        var didStrip = true
        while didStrip {
            didStrip = false
            for prefix in platformPatterns {
                if cleaned.hasPrefix("\(prefix)-") {
                    cleaned = String(cleaned.dropFirst(prefix.count + 1))
                    didStrip = true
                    break
                }
            }
        }

        // Remove ALL platform suffixes (loop until none remain)
        didStrip = true
        while didStrip {
            didStrip = false
            for suffix in platformPatterns {
                if cleaned.hasSuffix("-\(suffix)") {
                    cleaned = String(cleaned.dropLast(suffix.count + 1))
                    didStrip = true
                    break
                }
            }
        }

        let result = cleaned
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()

        // Fallback if empty or bare platform name
        return result.isEmpty || platformPatterns.contains(result) ? "screenshot" : result
    }
}
