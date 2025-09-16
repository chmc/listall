import SwiftUI

struct ListView: View {
    let list: List
    @StateObject private var viewModel: ListViewModel
    
    init(list: List) {
        self.list = list
        self._viewModel = StateObject(wrappedValue: ListViewModel(list: list))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading items...")
            } else if viewModel.items.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Items Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Add your first item to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                SwiftUI.List {
                    ForEach(viewModel.items) { item in
                        ItemRowView(item: item)
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: Add create item functionality
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadItems()
        }
    }
}

#Preview {
    NavigationView {
        ListView(list: List(name: "Sample List"))
    }
}
