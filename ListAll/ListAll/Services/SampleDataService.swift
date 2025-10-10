import Foundation

/// Service for providing sample list templates to help new users get started
class SampleDataService {
    /// Sample list template definition
    struct SampleListTemplate {
        let name: String
        let icon: String
        let description: String
        let sampleItems: [SampleItem]
    }
    
    /// Sample item definition
    struct SampleItem {
        let title: String
        let description: String?
        let quantity: Int?
    }
    
    /// Available sample list templates
    static let templates: [SampleListTemplate] = [
        SampleListTemplate(
            name: "Shopping List",
            icon: "cart",
            description: "Your grocery essentials",
            sampleItems: [
                SampleItem(title: "Milk", description: "2% or whole milk", quantity: 1),
                SampleItem(title: "Bread", description: "Whole wheat", quantity: 1),
                SampleItem(title: "Eggs", description: "Large, free-range", quantity: 12),
                SampleItem(title: "Apples", description: "Honeycrisp or Gala", quantity: 6),
                SampleItem(title: "Coffee", description: "Medium roast", quantity: 1),
                SampleItem(title: "Butter", description: "Unsalted", quantity: 1),
                SampleItem(title: "Chicken Breast", description: "Organic, boneless", quantity: 2),
                SampleItem(title: "Olive Oil", description: "Extra virgin", quantity: 1)
            ]
        ),
        SampleListTemplate(
            name: "To-Do List",
            icon: "checkmark.circle",
            description: "Get things done",
            sampleItems: [
                SampleItem(title: "Review weekly goals", description: "Check progress on quarterly objectives", quantity: nil),
                SampleItem(title: "Respond to emails", description: "Clear inbox before noon", quantity: nil),
                SampleItem(title: "Call dentist", description: "Schedule 6-month cleaning appointment", quantity: nil),
                SampleItem(title: "Update project documentation", description: "Add new features to README", quantity: nil),
                SampleItem(title: "Plan weekend activities", description: "Research hiking trails or museums", quantity: nil),
                SampleItem(title: "Order birthday gift", description: "For mom's birthday next month", quantity: nil)
            ]
        ),
        SampleListTemplate(
            name: "Packing List",
            icon: "suitcase",
            description: "Travel essentials",
            sampleItems: [
                SampleItem(title: "Passport & Travel Documents", description: "Check expiration dates", quantity: nil),
                SampleItem(title: "Phone Charger", description: "USB-C or Lightning", quantity: 1),
                SampleItem(title: "Toiletries", description: "Toothbrush, toothpaste, shampoo", quantity: nil),
                SampleItem(title: "Medications", description: "Include prescriptions and pain relievers", quantity: nil),
                SampleItem(title: "Comfortable Shoes", description: "For walking and exploring", quantity: 2),
                SampleItem(title: "Weather-appropriate Clothing", description: "Check forecast for destination", quantity: nil),
                SampleItem(title: "Sunglasses & Sunscreen", description: "SPF 30+", quantity: nil),
                SampleItem(title: "Book or E-reader", description: "For travel entertainment", quantity: 1)
            ]
        )
    ]
    
    /// Create a list from a template
    /// - Parameter template: The template to use
    /// - Returns: A new list populated with template items
    static func createListFromTemplate(_ template: SampleListTemplate) -> List {
        // Create the list
        let list = List(name: template.name)
        
        // Note: Items are not created here, as they need to be saved via DataManager
        // This method is primarily for creating a list structure without persistence
        
        return list
    }
    
    /// Save a template list and its items to the data repository
    /// - Parameters:
    ///   - template: The template to save
    ///   - dataManager: The data manager to use for saving
    /// - Returns: The created list with items
    static func saveTemplateList(_ template: SampleListTemplate, using dataManager: DataManager = DataManager.shared) -> List {
        // Create the list
        let list = List(name: template.name)
        
        // Save the list first
        dataManager.addList(list)
        
        // Create and save items
        template.sampleItems.enumerated().forEach { index, sampleItem in
            var item = Item(title: sampleItem.title, listId: list.id)
            item.itemDescription = sampleItem.description
            item.quantity = sampleItem.quantity ?? 1
            item.orderNumber = index
            dataManager.addItem(item, to: list.id)
        }
        
        // Reload data and get the updated list
        dataManager.loadData()
        if let updatedList = dataManager.lists.first(where: { $0.id == list.id }) {
            return updatedList
        }
        
        return list
    }
}

