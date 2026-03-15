import SwiftUI

// MARK: - Deprecated NavigationLink Wrapper
/// Wraps `NavigationLink(destination:isActive:label:)` to isolate its deprecation warning.
///
/// `NavigationView` requires the old `NavigationLink(isActive:)` API for programmatic
/// navigation. The newer `navigationDestination(isPresented:)` is a NavigationStack-only
/// modifier that silently does nothing inside NavigationView.
///
/// By placing the deprecated call inside this struct's `body` (which is a protocol
/// requirement), the deprecation warning is contained and does not propagate to callers.
struct DeprecatedNavigationLink<Destination: View>: View {
    let isActive: Binding<Bool>
    @ViewBuilder let destination: () -> Destination

    @available(iOS, deprecated: 16.0, message: "Migrate to NavigationStack when minimum deployment target is iOS 16+")
    var body: some View {
        NavigationLink(
            destination: destination(),
            isActive: isActive,
            label: { EmptyView() }
        )
        .hidden()
    }
}
