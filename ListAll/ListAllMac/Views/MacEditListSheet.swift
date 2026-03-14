//
//  MacEditListSheet.swift
//  ListAllMac
//
//  Sheet view for editing a list's name.
//

import SwiftUI

struct MacEditListSheet: View {
    let list: List
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String

    init(list: List, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.list = list
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: list.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit List")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            TextField("List Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .accessibilityLabel("List name")
                .accessibilityIdentifier("ListNameTextField")
                .onSubmit {
                    if !name.isEmpty {
                        onSave(name)
                    }
                }

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .accessibilityHint("Discards changes")
                .accessibilityIdentifier("CancelButton")

                Button("Save") {
                    onSave(name)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Saves changes")
                .accessibilityIdentifier("SaveButton")
            }
        }
        .padding(30)
        .frame(minWidth: 350)
        .accessibilityIdentifier("EditListSheet")
    }
}
