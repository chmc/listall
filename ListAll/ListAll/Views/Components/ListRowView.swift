import SwiftUI

struct ListRowView: View {
    let list: List
    @ObservedObject var mainViewModel: MainViewModel
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingDuplicateAlert = false
    
    private var listContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(list.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(.primary)
                
                Text("\(list.activeItemCount) (\(list.itemCount)) items")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    var body: some View {
        HStack {
            // Selection indicator
            if mainViewModel.isInSelectionMode {
                Button(action: {
                    mainViewModel.toggleSelection(for: list.id)
                }) {
                    Image(systemName: mainViewModel.selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mainViewModel.selectedLists.contains(list.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // List content
            if mainViewModel.isInSelectionMode {
                // In selection mode: Make entire row tappable for selection
                Button(action: {
                    mainViewModel.toggleSelection(for: list.id)
                }) {
                    listContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Normal mode: Use NavigationLink
                NavigationLink(destination: ListView(list: list, mainViewModel: mainViewModel)) {
                    listContent
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .if(!mainViewModel.isInSelectionMode) { view in
            view.contextMenu {
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
        }
        .if(!mainViewModel.isInSelectionMode) { view in
            view.swipeActions(edge: .trailing) {
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .if(!mainViewModel.isInSelectionMode) { view in
            view.swipeActions(edge: .leading) {
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

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
