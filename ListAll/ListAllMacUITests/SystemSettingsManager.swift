//
//  SystemSettingsManager.swift
//  ListAllMacUITests
//
//  Manages saving and restoring macOS system appearance settings for UI tests.
//  Ensures the user's appearance preference (dark/light mode) is restored after tests complete.
//

import Foundation

/// Manages macOS system appearance settings for UI tests.
/// Saves the user's appearance setting BEFORE tests run and restores it AFTER tests complete.
final class SystemSettingsManager {

    // MARK: - Private Properties

    /// Stores the original appearance setting before tests modified it.
    /// nil = not yet saved, "Dark" = was in dark mode, "Light" = was in light mode
    private static var savedAppearance: String?

    /// Flag to prevent saving multiple times
    private static var hasSaved = false

    /// Flag to prevent restoring multiple times
    private static var hasRestored = false

    // MARK: - Public API

    /// Saves the current macOS system appearance setting.
    /// Call this ONCE at the START of the test suite, before any appearance changes.
    /// Safe to call multiple times - only the first call has any effect.
    static func saveSystemAppearance() {
        guard !hasSaved else {
            print("[SystemSettingsManager] Appearance already saved, skipping")
            return
        }

        hasSaved = true

        print("[SystemSettingsManager] Saving current system appearance...")

        // Read current appearance using: defaults read -g AppleInterfaceStyle
        // Returns "Dark" if dark mode, exits with code 1 if light mode
        let result = runDefaultsCommand(arguments: ["read", "-g", "AppleInterfaceStyle"])

        if result.exitCode == 0 {
            let appearance = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            savedAppearance = appearance
            print("[SystemSettingsManager] Saved appearance: \(appearance)")
        } else {
            // Exit code 1 means the key doesn't exist, which means light mode
            savedAppearance = "Light"
            print("[SystemSettingsManager] Saved appearance: Light (default)")
        }
    }

    /// Restores the previously saved macOS system appearance setting.
    /// Call this ONCE at the END of the test suite, after all tests complete.
    /// Safe to call multiple times - only the first call has any effect.
    static func restoreSystemAppearance() {
        guard !hasRestored else {
            print("[SystemSettingsManager] Appearance already restored, skipping")
            return
        }

        guard hasSaved else {
            print("[SystemSettingsManager] No appearance was saved, nothing to restore")
            return
        }

        hasRestored = true

        guard let appearance = savedAppearance else {
            print("[SystemSettingsManager] No saved appearance found, nothing to restore")
            return
        }

        print("[SystemSettingsManager] Restoring system appearance to: \(appearance)")

        if appearance == "Dark" {
            // Restore dark mode: defaults write -g AppleInterfaceStyle Dark
            let result = runDefaultsCommand(arguments: ["write", "-g", "AppleInterfaceStyle", "Dark"])
            if result.exitCode == 0 {
                print("[SystemSettingsManager] Successfully restored dark mode")
            } else {
                print("[SystemSettingsManager] WARNING: Failed to restore dark mode: \(result.output)")
            }
        } else {
            // Restore light mode: defaults delete -g AppleInterfaceStyle
            let result = runDefaultsCommand(arguments: ["delete", "-g", "AppleInterfaceStyle"])
            if result.exitCode == 0 {
                print("[SystemSettingsManager] Successfully restored light mode")
            } else if result.output.contains("does not exist") {
                // This is fine - key already doesn't exist, so we're in light mode
                print("[SystemSettingsManager] Light mode already active (key doesn't exist)")
            } else {
                print("[SystemSettingsManager] WARNING: Failed to restore light mode: \(result.output)")
            }
        }

        // Notify the system to apply the appearance change
        notifyAppearanceChange()
    }

    /// Resets the internal state to allow saving/restoring again.
    /// Used primarily for testing the manager itself.
    static func reset() {
        savedAppearance = nil
        hasSaved = false
        hasRestored = false
        print("[SystemSettingsManager] State reset")
    }

    /// Returns the currently saved appearance, for debugging purposes.
    static var currentSavedAppearance: String? {
        return savedAppearance
    }

    // MARK: - Private Helpers

    /// Result of running a defaults command
    private struct CommandResult {
        let exitCode: Int32
        let output: String
    }

    /// Runs a `defaults` command with the given arguments.
    /// - Parameter arguments: Arguments to pass to the defaults command
    /// - Returns: CommandResult with exit code and output
    private static func runDefaultsCommand(arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return CommandResult(exitCode: process.terminationStatus, output: output)
        } catch {
            print("[SystemSettingsManager] Error running defaults command: \(error)")
            return CommandResult(exitCode: -1, output: error.localizedDescription)
        }
    }

    /// Notifies the system that appearance settings have changed.
    /// This helps ensure the change takes effect immediately.
    private static func notifyAppearanceChange() {
        // Post a distributed notification to trigger appearance update
        // This is the same notification that System Preferences posts
        DistributedNotificationCenter.default().post(
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Give the system a moment to process the notification
        Thread.sleep(forTimeInterval: 0.5)
    }
}
