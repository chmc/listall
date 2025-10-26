import SwiftUI

struct EditListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mainViewModel: MainViewModel
    @State private var listName: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isUpdating = false
    @FocusState private var isListNameFieldFocused: Bool
    
    let list: List
    
    init(list: List, mainViewModel: MainViewModel) {
        self.list = list
        self.mainViewModel = mainViewModel
        self._listName = State(initialValue: list.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(String(localized: "List Details"))) {
                    TextField(String(localized: "List Name"), text: $listName)
                        .textFieldStyle(.plain)
                        .autocapitalization(.sentences)
                        .focused($isListNameFieldFocused)
                        .accessibilityIdentifier("EditListNameTextField")
                }
            }
            .navigationTitle(String(localized: "Edit List"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("EditCancelButton")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Save")) {
                        updateList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             isUpdating ||
                             listName.trimmingCharacters(in: .whitespacesAndNewlines) == list.name)
                    .accessibilityIdentifier("EditSaveButton")
                }
            }
        }
        .alert(String(localized: "Error"), isPresented: $showingAlert) {
            Button(String(localized: "OK")) { }
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
