import SwiftUI

struct DestinationListPickerView: View {
    enum Action {
        case move
        case copy
    }
    
    let action: Action
    let itemCount: Int
    let currentListId: UUID
    let onSelect: (List?) -> Void
    let onCancel: () -> Void
    @ObservedObject var mainViewModel: MainViewModel
    @State private var showingCreateNewList = false
    @State private var newListName = ""
    @State private var validationError: String?
    @State private var pendingNewList: List? // Track newly created list
    @FocusState private var isTextFieldFocused: Bool
    
    private var actionTitle: String {
        action == .move ? "Move Items" : "Copy Items"
    }
    
    private var actionVerb: String {
        action == .move ? "move" : "copy"
    }
    
    private var availableLists: [List] {
        mainViewModel.lists.filter { $0.id != currentListId }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: Theme.Spacing.sm) {
                    Text("\(actionTitle)")
                        .font(Theme.Typography.title)
                        .padding(.top, Theme.Spacing.lg)
                    
                    Text("Select a destination list to \(actionVerb) \(itemCount) item(s)")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.bottom, Theme.Spacing.md)
                
                Divider()
                
                // List selection
                if availableLists.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Spacer()
                        
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.secondary)
                        
                        Text("No Other Lists")
                            .font(Theme.Typography.title)
                        
                        Text("Create a new list to \(actionVerb) items to")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondary)
                        
                        Spacer()
                    }
                } else {
                    SwiftUI.List {
                        ForEach(availableLists) { list in
                            Button(action: {
                                onSelect(list)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(list.name)
                                            .font(Theme.Typography.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(list.itemCount) items")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Theme.Colors.secondary)
                                        .font(.system(size: 14))
                                }
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Create new list button
                VStack(spacing: Theme.Spacing.sm) {
                    Button(action: {
                        showingCreateNewList = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Create New List")
                                .font(Theme.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.primary)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Colors.background)
        }
        .sheet(isPresented: $showingCreateNewList, onDismiss: {
            // When sheet dismisses, if we created a new list, notify parent
            if let newList = pendingNewList {
                onSelect(newList)
                pendingNewList = nil
            }
        }) {
            createNewListSheet
        }
    }
    
    private var createNewListSheet: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Create a new list to \(actionVerb) items to")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.lg)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("List Name")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondary)
                    
                    TextField("Enter list name", text: $newListName)
                        .textFieldStyle(.plain)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(Theme.CornerRadius.sm)
                        .autocapitalization(.sentences)
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                if let error = validationError {
                    Text(error)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
                
                Spacer()
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        newListName = ""
                        validationError = nil
                        showingCreateNewList = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createNewList()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                // Use task for focus - runs in async context after view appears
                // Brief sleep allows keyboard animation to settle
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                isTextFieldFocused = true
            }
        }
    }
    
    private func createNewList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate
        if trimmedName.isEmpty {
            validationError = "Please enter a list name"
            return
        }
        
        if trimmedName.count > 100 {
            validationError = "List name must be 100 characters or less"
            return
        }
        
        // Create the list
        do {
            let newList = try mainViewModel.addList(name: trimmedName)
            // Store the new list to be handled in onDismiss
            pendingNewList = newList
            // Reset state
            newListName = ""
            validationError = nil
            // Dismiss sheet - onDismiss will call onSelect
            showingCreateNewList = false
        } catch {
            validationError = error.localizedDescription
        }
    }
}

#Preview {
    DestinationListPickerView(
        action: .move,
        itemCount: 5,
        currentListId: UUID(),
        onSelect: { _ in },
        onCancel: { },
        mainViewModel: MainViewModel()
    )
}
