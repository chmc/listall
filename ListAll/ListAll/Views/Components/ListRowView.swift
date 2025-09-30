import SwiftUI

struct ListRowView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingDuplicateAlert = false
    
    var body: some View {
        NavigationLink(destination: ListView(list: list)) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(list.name) // Removed nil coalescing operator since name is non-optional
                        .font(Theme.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(list.activeItemCount) (\(list.itemCount)) items")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .contextMenu {
            Button(action: {
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: {
                showingDuplicateAlert = true
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
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
        }
        .swipeActions(edge: .leading) {
            Button(action: {
                showingDuplicateAlert = true
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.green)
            
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
        .alert("Duplicate List", isPresented: $showingDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Duplicate") {
                do {
                    try mainViewModel.duplicateList(list)
                } catch {
                    // Handle error (could add error alert here if needed)
                    print("Error duplicating list: \(error)")
                }
            }
        } message: {
            Text("This will create a copy of \"\(list.name)\" with all its items.")
        }
    }
}

#Preview {
    SwiftUI.List {
        ListRowView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
    }
}
