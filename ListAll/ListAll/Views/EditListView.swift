import SwiftUI

struct EditListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mainViewModel: MainViewModel
    @State private var listName: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isUpdating = false
    
    let list: List
    
    init(list: List, mainViewModel: MainViewModel) {
        self.list = list
        self.mainViewModel = mainViewModel
        self._listName = State(initialValue: list.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityIdentifier("EditListNameTextField")
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("EditCancelButton")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             isUpdating ||
                             listName.trimmingCharacters(in: .whitespacesAndNewlines) == list.name)
                    .accessibilityIdentifier("EditSaveButton")
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func updateList() {
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
        
        guard trimmedName != list.name else {
            dismiss()
            return
        }
        
        isUpdating = true
        
        do {
            try mainViewModel.updateList(list, name: trimmedName)
            dismiss()
        } catch {
            alertMessage = "Failed to update list: \(error.localizedDescription)"
            showingAlert = true
            isUpdating = false
        }
    }
}

#Preview {
    EditListView(list: List(name: "Sample List"), mainViewModel: MainViewModel())
}
