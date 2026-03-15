import Foundation
import CoreData
@testable import ListAll

/// Test-specific ItemViewModel that uses isolated DataManager
class TestItemViewModel: ObservableObject {
    @Published var item: Item
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dataManager: TestDataManager
    private let dataRepository: TestDataRepository

    init(item: Item, dataManager: TestDataManager) {
        self.item = item
        self.dataManager = dataManager
        self.dataRepository = TestDataRepository(dataManager: dataManager)
    }

    func save() {
        dataManager.updateItem(item)
    }

    func toggleCrossedOut() {
        var updatedItem = item
        updatedItem.toggleCrossedOut()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }

    func updateItem(title: String, description: String, quantity: Int) {
        var updatedItem = item
        updatedItem.title = title
        updatedItem.itemDescription = description.isEmpty ? nil : description
        updatedItem.quantity = quantity
        updatedItem.updateModifiedDate()
        dataManager.updateItem(updatedItem)
        self.item = updatedItem
    }

    func duplicateItem(in list: List) -> Item? {
        guard item.listId != nil else { return nil }

        let duplicatedItem = dataRepository.createItem(
            in: list,
            title: "\(item.title) (Copy)",
            description: item.itemDescription ?? "",
            quantity: item.quantity
        )

        return duplicatedItem
    }

    func deleteItem() {
        dataRepository.deleteItem(item)
    }

    func validateItem() -> ValidationResult {
        return dataRepository.validateItem(item)
    }

    func refreshItem() {
        if let refreshedItem = dataRepository.getItem(by: item.id) {
            self.item = refreshedItem
        }
    }
}
