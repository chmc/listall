import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mainViewModel: MainViewModel
    @State private var listName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
            try mainViewModel.addList(name: trimmedName)
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
