//
//  WatchFilterPicker.swift
//  ListAllWatch Watch App
//
//  Created by AI Assistant on 21.10.2025.
//

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Extension to add watchOS-specific display properties
extension ItemFilterOption {
    /// Short label for compact watchOS display
    var shortLabel: String {
        switch self {
        case .all:
            return "All"
        case .active:
            return "Active"
        case .completed:
            return "Done"
        case .hasDescription:
            return "Desc"
        case .hasImages:
            return "Images"
        }
    }
    
    /// Filter options relevant for watchOS
    static var watchOSOptions: [ItemFilterOption] {
        return [.all, .active, .completed]
    }
}

/// Compact filter picker for watchOS
struct WatchFilterPicker: View {
    @Binding var selectedFilter: ItemFilterOption
    let onFilterChange: (ItemFilterOption) -> Void
    
    var body: some View {
        Picker(selection: Binding(
            get: { selectedFilter },
            set: { newValue in
                WatchHapticManager.shared.playFilterChange()
                withAnimation(WatchAnimationManager.filterChange) {
                    selectedFilter = newValue
                    onFilterChange(newValue)
                }
            }
        )) {
            ForEach(ItemFilterOption.watchOSOptions) { option in
                Label(option.shortLabel, systemImage: option.systemImage)
                    .tag(option)
            }
        } label: {
            Text("Filter")
        }
        .pickerStyle(.navigationLink)
        .accessibilityLabel("Filter items")
        .accessibilityHint("Choose which items to display")
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var filter: ItemFilterOption = .all
        
        var body: some View {
            VStack {
                WatchFilterPicker(selectedFilter: $filter) { newFilter in
                    print("Filter changed to: \(newFilter)")
                }
            }
        }
    }
    
    return PreviewWrapper()
}

