//
//  RealWorkspace.swift
//  ListAllMac
//
//  Created as part of MACOS_PLAN.md Phase 4: E2E Refactoring
//  Purpose: Production implementation of WorkspaceQuerying using NSWorkspace
//

import Foundation
import AppKit

/// Production implementation of WorkspaceQuerying protocol
/// Uses NSWorkspace.shared to query running applications
final class RealWorkspace: WorkspaceQuerying {

    /// Query all currently running applications
    /// - Returns: Array of RunningApp structs representing all running applications
    func runningApplications() -> [RunningApp] {
        return NSWorkspace.shared.runningApplications.map { nsApp in
            RunningApp(
                bundleIdentifier: nsApp.bundleIdentifier,
                localizedName: nsApp.localizedName,
                activationPolicy: nsApp.activationPolicy.rawValue
            )
        }
    }
}
