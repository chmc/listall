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
            return NSLocalizedString("All", comment: "watchOS filter option - all items")
        case .active:
            return NSLocalizedString("Active", comment: "watchOS filter option - active items")
        case .completed:
            return NSLocalizedString("Done", comment: "watchOS filter option - completed items")
        case .hasDescription:
            return NSLocalizedString("Desc", comment: "watchOS filter option - items with description (short)")
        case .hasImages:
            return NSLocalizedString("Images", comment: "watchOS filter option - items with images")
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
                    .accessibilityIdentifier("WatchFilter_\(option.rawValue)")
            }
        } label: {
            Text(NSLocalizedString("Filter", comment: "watchOS filter picker label"))
        }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier("WatchFilterPicker")
        .accessibilityLabel(NSLocalizedString("Filter items", comment: "watchOS accessibility label for filter picker"))
        .accessibilityHint(NSLocalizedString("Choose which items to display", comment: "watchOS accessibility hint for filter picker"))
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var filter: ItemFilterOption = .all
        
        var body: some View {
            VStack {
                WatchFilterPicker(selectedFilter: $filter) { newFilter in
                    // Filter changed
                }
            }
        }
    }
    
    return PreviewWrapper()
}

