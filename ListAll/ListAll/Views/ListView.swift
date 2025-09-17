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
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.secondary)
                    
                    Text("No Items Yet")
                        .font(Theme.Typography.title)
                    
                    Text("Add your first item to get started")
                        .font(Theme.Typography.body)
                        .emptyStateStyle()
                }
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
                    Image(systemName: Constants.UI.addIcon)
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
