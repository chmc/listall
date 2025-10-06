import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mainViewModel: MainViewModel
    @State private var listName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    @FocusState private var isListNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(.plain)
                        .autocapitalization(.sentences)
                        .focused($isListNameFieldFocused)
                        .accessibilityIdentifier("ListNameTextField")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CancelButton")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    .accessibilityIdentifier("CreateButton")
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            isListNameFieldFocused = false
        }
        .onAppear {
            // Focus the list name field when the screen appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isListNameFieldFocused = true
            }
        }
    }
    
    private func createList() {
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a list name"
            showingAlert = true
            return
        }
        
        guard trimmedName.count <= 100 else {
            alertMessage = "List name must be 100 characters or less"
            showingAlert = true
            return
        }
        
        isCreating = true
        
        do {
            let newList = try mainViewModel.addList(name: trimmedName)
            // Trigger navigation to the newly created list
            mainViewModel.selectedListForNavigation = newList
            dismiss()
        } catch {
            alertMessage = "Failed to create list: \(error.localizedDescription)"
            showingAlert = true
            isCreating = false
        }
    }
}

#Preview {
    CreateListView(mainViewModel: MainViewModel())
}
