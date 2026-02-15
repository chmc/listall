import Foundation
import AppKit
import MCPHelpers

// MARK: - Screenshot Storage

/// Service for managing screenshot storage in project folder
enum ScreenshotStorage {
    /// Maximum dimension for Claude API images (many-image requests limit to 2000px)
    static let maxImageDimension: CGFloat = 1800 // Keep under 2000px limit

    /// Resize image data if it exceeds the maximum dimension
    /// - Parameter imageData: Original PNG image data
    /// - Returns: Resized PNG image data (or original if already within limits)
    static func resizeImageIfNeeded(_ imageData: Data) -> Data {
        guard let image = NSImage(data: imageData) else {
            log("Failed to load image for resizing, returning original")
            return imageData
        }

        let size = image.size

        // Check if resizing is needed
        guard size.width > maxImageDimension || size.height > maxImageDimension else {
            log("Image \(Int(size.width))x\(Int(size.height)) is within limits, no resize needed")
            return imageData
        }

        // Calculate new size maintaining aspect ratio
        let scale = min(maxImageDimension / size.width, maxImageDimension / size.height)
        let newSize = NSSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )

        log("Resizing image from \(Int(size.width))x\(Int(size.height)) to \(Int(newSize.width))x\(Int(newSize.height))")

        // Create resized image
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            log("Failed to create bitmap rep for resizing, returning original")
            return imageData
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            log("Failed to create PNG from resized image, returning original")
            return imageData
        }

        log("Image resized successfully: \(imageData.count) -> \(pngData.count) bytes")
        return pngData
    }
    /// Project root path (where .listall-mcp folder will be created)
    static let projectRoot = "/Users/aleksi/source/listall"

    /// Base folder for MCP screenshots
    static let screenshotBaseFolder = ".listall-mcp"

    /// Current session folder (created once per session, shared across platforms and contexts)
    nonisolated(unsafe) private static var currentSessionFolder: URL?
    nonisolated(unsafe) private static var currentSessionContext: String?

    /// Index counter for screenshots within a session (keyed by platform)
    nonisolated(unsafe) private static var screenshotIndex: [String: Int] = [:]

    /// Timestamp of last screenshot for session timeout
    nonisolated(unsafe) private static var lastScreenshotTime: Date?

    /// Session timeout in seconds (15 minutes of inactivity creates new folder)
    /// Extended from 5 minutes to allow multi-platform testing with simulator boot times
    static let sessionTimeout: TimeInterval = 900

    /// Sanitize context string for use in folder/file names
    private static func sanitizeContext(_ context: String?) -> String {
        ContextSanitizer.sanitize(context)
    }

    /// Get or create the session folder for screenshots
    /// - Parameter context: Context string for folder name (only used for first screenshot in session)
    /// - Returns: URL to the session folder
    static func getOrCreateSessionFolder(context: String?) throws -> URL {
        let sanitizedContext = sanitizeContext(context)

        // Check for session timeout (5 minutes of inactivity)
        if let lastTime = lastScreenshotTime,
           Date().timeIntervalSince(lastTime) > sessionTimeout {
            log("Session timeout (\(Int(sessionTimeout))s), creating new folder")
            resetSession()
        }
        lastScreenshotTime = Date()

        // Reuse existing folder regardless of context change
        // Context only affects folder name on first screenshot
        if let folder = currentSessionFolder {
            return folder
        }

        // First screenshot in session - create new folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let folderName = "\(timestamp)-\(sanitizedContext)"
        let folderPath = URL(fileURLWithPath: projectRoot)
            .appendingPathComponent(screenshotBaseFolder)
            .appendingPathComponent(folderName)

        // Create folder if it doesn't exist
        try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true)

        currentSessionFolder = folderPath
        currentSessionContext = sanitizedContext
        screenshotIndex.removeAll()
        log("Created session screenshot folder: \(folderPath.path)")
        return folderPath
    }

    /// Reset the session (creates a new folder on next screenshot)
    static func resetSession() {
        currentSessionFolder = nil
        currentSessionContext = nil
        screenshotIndex.removeAll()
        lastScreenshotTime = nil
        log("Screenshot session reset")
    }

    /// Generate a screenshot filename with format: {platform}-{index:02d}-{context}.png
    /// - Parameters:
    ///   - platform: Platform identifier (e.g., "macos", "ios", "ipad", "watch")
    ///   - context: Context string (e.g., "main-view", "settings")
    /// - Returns: Filename with .png extension
    static func generateFilename(platform: String, context: String?) -> String {
        // Sanitize platform
        let sanitizedPlatform = platform
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        let sanitizedContext = sanitizeContext(context)

        // Get and increment index for this platform (within same session folder)
        let index = (screenshotIndex[sanitizedPlatform] ?? 0) + 1
        screenshotIndex[sanitizedPlatform] = index

        // Format: {platform}-{index:02d}-{context}.png for better sorting
        return "\(sanitizedPlatform)-\(String(format: "%02d", index))-\(sanitizedContext).png"
    }

    /// Save screenshot data to the project folder
    /// - Parameters:
    ///   - imageData: PNG image data
    ///   - context: Optional context for folder and filename
    ///   - platform: Platform identifier
    /// - Returns: Path where screenshot was saved
    static func saveScreenshot(
        imageData: Data,
        context: String?,
        platform: String
    ) throws -> String {
        let folder = try getOrCreateSessionFolder(context: context)
        let filename = generateFilename(platform: platform, context: context)
        let filePath = folder.appendingPathComponent(filename)

        try imageData.write(to: filePath)
        log("Saved screenshot to: \(filePath.path)")

        return filePath.path
    }
}
