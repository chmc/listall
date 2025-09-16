//
//  ListRowView.swift
//  ListAll
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import SwiftUI

struct ListRowView: View {
    let list: List
    @State private var itemCount: Int = 0
    
    var body: some View {
        NavigationLink(destination: ListView(list: list)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name ?? "Untitled List")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(itemCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            updateItemCount()
        }
    }
    
    private func updateItemCount() {
        itemCount = list.items?.count ?? 0
    }
}

#Preview {
    SwiftUI.List {
        ListRowView(list: List())
    }
}
