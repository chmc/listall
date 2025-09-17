import SwiftUI

struct ListRowView: View {
    let list: List
    @State private var itemCount: Int = 0
    
    var body: some View {
        NavigationLink(destination: ListView(list: list)) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(list.name) // Removed nil coalescing operator since name is non-optional
                        .font(Theme.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(itemCount) items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                }
                
                Spacer()
                
                Image(systemName: Constants.UI.chevronIcon)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondary)
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            updateItemCount()
        }
    }
    
    private func updateItemCount() {
        itemCount = list.items.count // Removed optional chaining since items is non-optional
    }
}

#Preview {
    SwiftUI.List {
        ListRowView(list: List(name: "Sample List"))
    }
}
