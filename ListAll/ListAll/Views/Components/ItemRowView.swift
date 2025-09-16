//
//  ItemRowView.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import SwiftUI

struct ItemRowView: View {
    let item: Item
    @StateObject private var viewModel: ItemViewModel
    
    init(item: Item) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: ItemViewModel(item: item))
    }
    
    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack {
                // Checkbox
                Button(action: {
                    viewModel.toggleCrossedOut()
                }) {
                    Image(systemName: item.isCrossedOut ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCrossedOut ? .green : .secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isCrossedOut)
                        .foregroundColor(item.isCrossedOut ? .secondary : .primary)
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if item.quantity > 1 {
                        Text("Qty: \(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Quantity badge
                if item.quantity > 1 {
                    Text("\(item.quantity)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    SwiftUI.List {
        ItemRowView(item: Item(title: "Sample Item"))
    }
}
