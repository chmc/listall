import Foundation

class SuggestionService: ObservableObject {
    @Published var suggestions: [String] = []
    
    private let dataManager = DataManager.shared
    
    init() {
        // Initialize with empty suggestions
    }
    
    func getSuggestions(for searchText: String) {
        guard !searchText.isEmpty else {
            suggestions = []
            return
        }
        
        let allItems = dataManager.lists.flatMap { $0.items }
        let matchingItems = allItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
        }
        
        suggestions = Array(Set(matchingItems.map { $0.title }))
            .filter { !$0.isEmpty }
            .prefix(10)
            .map { String($0) }
    }
    
    func getRecentItems() -> [String] {
        let allItems = dataManager.lists.flatMap { $0.items }
        return allItems
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .compactMap { $0.title }
            .filter { !$0.isEmpty }
    }
}