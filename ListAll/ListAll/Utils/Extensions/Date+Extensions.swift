//
//  Date+Extensions.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Foundation

extension Date {
    
    /// Returns a formatted string representation of the date
    func customFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns a formatted string representation of the date for display in lists
    func listFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Returns a relative time string (e.g., "2 hours ago")
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
