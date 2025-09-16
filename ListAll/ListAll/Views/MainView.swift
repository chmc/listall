import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading lists...")
                } else if viewModel.lists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Lists Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Create your first list to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    SwiftUI.List {
                        ForEach(viewModel.lists) { list in
                            ListRowView(list: list)
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Add create list functionality
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadLists()
        }
    }
}

#Preview {
    MainView()
}
