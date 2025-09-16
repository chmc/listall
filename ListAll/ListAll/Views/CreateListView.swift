import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var listName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        
        // TODO: Implement actual list creation
        // For now, just dismiss the view
        dismiss()
    }
}

#Preview {
    CreateListView()
}
