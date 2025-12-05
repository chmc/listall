//
//  ContentView.swift
//  ListAllMac
//
//  Created by Aleksi Sutela on 5.12.2025.
//

import SwiftUI
import CoreData

/// Placeholder ContentView for macOS target.
/// This will be replaced with MacMainView in a later task (Task 5.1).
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)],
        animation: .default)
    private var lists: FetchedResults<ListEntity>

    var body: some View {
        NavigationSplitView {
            SwiftUI.List {
                ForEach(lists) { list in
                    NavigationLink {
                        if let name = list.name {
                            Text("List: \(name)")
                        } else {
                            Text("Unnamed List")
                        }
                    } label: {
                        if let name = list.name {
                            Text(name)
                        } else {
                            Text("Unnamed List")
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addList) {
                        Label("Add List", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a list")
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private func addList() {
        withAnimation {
            let newList = ListEntity(context: viewContext)
            newList.id = UUID()
            newList.name = "New List"
            newList.createdAt = Date()
            newList.modifiedAt = Date()
            newList.orderNumber = Int32(lists.count)
            newList.isArchived = false

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
