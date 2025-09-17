import SwiftUI

struct ListRowView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @State private var itemCount: Int = 0
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
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
        .contextMenu {
            Button(action: {
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: {
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditListView(list: list, mainViewModel: mainViewModel)
        }
        .alert("Delete List", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                mainViewModel.deleteList(list)
            }
        } message: {
            Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone.")
        }
    }
    
    private func updateItemCount() {
        itemCount = list.items.count // Removed optional chaining since items is non-optional
    }
}

#Preview {
    SwiftUI.List {
        ListRowView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
    }
}
