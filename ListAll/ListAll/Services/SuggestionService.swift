import Foundation

struct ItemSuggestion {
    let title: String
    let description: String?
    let frequency: Int
    let lastUsed: Date
    let score: Double
    
    init(title: String, description: String? = nil, frequency: Int = 1, lastUsed: Date = Date(), score: Double = 0.0) {
        self.title = title
        self.description = description
        self.frequency = frequency
        self.lastUsed = lastUsed
        self.score = score
    }
}

class SuggestionService: ObservableObject {
    @Published var suggestions: [ItemSuggestion] = []
    
    private let dataRepository: DataRepository
    
    init(dataRepository: DataRepository = DataRepository()) {
        self.dataRepository = dataRepository
    }
    
    // MARK: - Public Methods
    
    func getSuggestions(for searchText: String, in list: List? = nil) {
        guard !searchText.isEmpty else {
            suggestions = []
            return
        }
        
        let allItems = getAllItems(from: list)
        let matchingSuggestions = generateSuggestions(from: allItems, searchText: searchText)
        
        suggestions = matchingSuggestions
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0 }
    }
    
    func getRecentItems(limit: Int = 20) -> [ItemSuggestion] {
        let allItems = dataRepository.getAllLists().flatMap { $0.items }
        return allItems
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .compactMap { item in
                guard !item.title.isEmpty else { return nil }
                return ItemSuggestion(
                    title: item.title,
                    description: item.itemDescription,
                    frequency: 1,
                    lastUsed: item.modifiedAt ?? item.createdAt,
                    score: 1.0
                )
            }
    }
    
    func clearSuggestions() {
        suggestions = []
    }
    
    // MARK: - Private Methods
    
    private func getAllItems(from list: List?) -> [Item] {
        if let specificList = list {
            return specificList.items
        } else {
            return dataRepository.getAllLists().flatMap { $0.items }
        }
    }
    
    private func generateSuggestions(from items: [Item], searchText: String) -> [ItemSuggestion] {
        let searchLower = searchText.lowercased()
        var suggestionMap: [String: ItemSuggestion] = [:]
        
        for item in items {
            guard !item.title.isEmpty else { continue }
            
            let titleLower = item.title.lowercased()
            let matchScore = calculateMatchScore(searchText: searchLower, itemTitle: titleLower)
            
            if matchScore > 0 {
                let key = item.title.lowercased()
                
                if let existing = suggestionMap[key] {
                    // Update existing suggestion with higher frequency
                    suggestionMap[key] = ItemSuggestion(
                        title: item.title,
                        description: item.itemDescription,
                        frequency: existing.frequency + 1,
                        lastUsed: max(existing.lastUsed, item.modifiedAt ?? item.createdAt),
                        score: max(existing.score, matchScore)
                    )
                } else {
                    // Create new suggestion
                    suggestionMap[key] = ItemSuggestion(
                        title: item.title,
                        description: item.itemDescription,
                        frequency: 1,
                        lastUsed: item.modifiedAt ?? item.createdAt,
                        score: matchScore
                    )
                }
            }
        }
        
        return Array(suggestionMap.values)
    }
    
    private func calculateMatchScore(searchText: String, itemTitle: String) -> Double {
        // Exact match gets highest score
        if itemTitle == searchText {
            return 100.0
        }
        
        // Prefix match gets high score
        if itemTitle.hasPrefix(searchText) {
            return 90.0
        }
        
        // Contains match gets medium score
        if itemTitle.contains(searchText) {
            return 70.0
        }
        
        // Fuzzy match using edit distance
        let fuzzyScore = fuzzyMatchScore(searchText: searchText, itemTitle: itemTitle)
        if fuzzyScore > 0.6 {
            return fuzzyScore * 50.0 // Scale to 0-50 range
        }
        
        return 0.0
    }
    
    private func fuzzyMatchScore(searchText: String, itemTitle: String) -> Double {
        let distance = levenshteinDistance(searchText, itemTitle)
        let maxLength = max(searchText.count, itemTitle.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return max(0.0, similarity)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        // Initialize first row and column
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
}