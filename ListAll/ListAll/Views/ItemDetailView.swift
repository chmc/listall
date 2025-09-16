//
//  ItemDetailView.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @StateObject private var viewModel: ItemViewModel
    
    init(item: Item) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: ItemViewModel(item: item))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(item.title ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                
                // Description
                if let description = item.itemDescription, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(description)
                            .font(.body)
                    }
                }
                
                // Quantity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(item.quantity)")
                        .font(.body)
                }
                
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCrossedOut ? .green : .secondary)
                        
                        Text(item.isCrossedOut ? "Completed" : "Pending")
                            .font(.body)
                    }
                }
                
                // Dates
                VStack(alignment: .leading, spacing: 8) {
                    Text("Created")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(item.createdAt.formatted())
                        .font(.body)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.toggleCrossedOut()
                }) {
                    Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ItemDetailView(item: Item(title: "Sample Item"))
    }
}
