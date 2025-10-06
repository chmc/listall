import SwiftUI

struct ArchivedListView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingRestoreConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // List name header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "archivebox")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                        Text("Archived")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            
            // Item count subtitle
            HStack {
                Text("\(list.itemCount) \(list.itemCount == 1 ? "item" : "items")")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 4)
            .padding(.bottom, Theme.Spacing.sm)
            
            Divider()
                .padding(.horizontal, Theme.Spacing.md)
            
            // Items list (readonly)
            if list.items.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondary)
                    
                    Text("No Items")
                        .font(Theme.Typography.title)
                    
                    Text("This list was empty when archived")
                        .font(Theme.Typography.body)
                        .emptyStateStyle()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(list.sortedItems) { item in
                            ArchivedItemRowView(item: item)
                            
                            if item.id != list.sortedItems.last?.id {
                                Divider()
                                    .padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.sm)
                }
            }
        }
        .navigationTitle("Archived List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingRestoreConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .alert("Restore List", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") {
                mainViewModel.restoreList(list)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Do you want to restore \"\(list.name)\" to your active lists?")
        }
    }
}

// MARK: - Archived Item Row View (Readonly)
struct ArchivedItemRowView: View {
    let item: Item
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Crossed out indicator (static)
            Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isCrossedOut ? .green : .gray)
                .font(.system(size: 22))
                .padding(.top, 2)
            
            // Item content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.displayTitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(item.isCrossedOut ? Theme.Colors.secondary : .primary)
                    .strikethrough(item.isCrossedOut)
                
                // Description
                if item.hasDescription {
                    Text(item.displayDescription)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                        .lineLimit(2)
                }
                
                // Quantity
                if item.quantity > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(Theme.Typography.caption)
                        Text("Qty: \(item.quantity)")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.secondary)
                }
                
                // Images indicator
                if item.hasImages {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(Theme.Typography.caption)
                        Text("\(item.images.count) \(item.images.count == 1 ? "image" : "images")")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        ArchivedListView(
            list: List(name: "Sample Archived List"),
            mainViewModel: MainViewModel()
        )
    }
}

