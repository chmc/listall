import Foundation

struct ItemSuggestion {
    let title: String
    let description: String?
    let frequency: Int
    let lastUsed: Date
    let score: Double
    let recencyScore: Double
    let frequencyScore: Double
    let totalOccurrences: Int // Total times this item appears across all lists
    let averageUsageGap: TimeInterval // Average time between uses
    
    init(title: String, 
         description: String? = nil, 
         frequency: Int = 1, 
         lastUsed: Date = Date(), 
         score: Double = 0.0,
         recencyScore: Double = 0.0,
         frequencyScore: Double = 0.0,
         totalOccurrences: Int = 1,
         averageUsageGap: TimeInterval = 0.0) {
        self.title = title
        self.description = description
        self.frequency = frequency
        self.lastUsed = lastUsed
        self.score = score
        self.recencyScore = recencyScore
        self.frequencyScore = frequencyScore
        self.totalOccurrences = totalOccurrences
        self.averageUsageGap = averageUsageGap
    }
}

// MARK: - Suggestion Cache Management

private class SuggestionCache {
    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize = 100
    private let cacheExpiryTime: TimeInterval = 300 // 5 minutes
    
    private struct CacheEntry {
        let suggestions: [ItemSuggestion]
        let timestamp: Date
        let searchContext: String // Includes list ID and search parameters
    }
    
    func getCachedSuggestions(for key: String) -> [ItemSuggestion]? {
        guard let entry = cache[key] else { return nil }
        
        // Check if cache entry is still valid
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiryTime {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry.suggestions
    }
    
    func cacheSuggestions(_ suggestions: [ItemSuggestion], for key: String, context: String) {
        // Clean up old entries if cache is getting too large
        if cache.count >= maxCacheSize {
            let oldestKey = cache.min { first, second in
                first.value.timestamp < second.value.timestamp
            }?.key
            
            if let keyToRemove = oldestKey {
                cache.removeValue(forKey: keyToRemove)
            }
        }
        
        cache[key] = CacheEntry(
            suggestions: suggestions,
            timestamp: Date(),
            searchContext: context
        )
    }
    
    func clearCache() {
        cache.removeAll()
    }
    
    func invalidateCache(for searchText: String) {
        // Remove all cache entries that might be affected by this search
        let keysToRemove = cache.keys.filter { key in
            key.contains(searchText.lowercased()) || searchText.lowercased().contains(key)
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
}

class SuggestionService: ObservableObject {
    @Published var suggestions: [ItemSuggestion] = []
    
    private let dataRepository: DataRepository
    private let suggestionCache = SuggestionCache()
    
    // Advanced suggestion configuration
    private let recencyWeight: Double = 0.3
    private let frequencyWeight: Double = 0.4
    private let matchWeight: Double = 0.3
    private let maxRecencyDays: Double = 30.0 // Items older than 30 days get reduced recency score
    
    init(dataRepository: DataRepository = DataRepository()) {
        self.dataRepository = dataRepository
        // Temporarily disable notification observers to fix test issues
        // setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: NSNotification.Name("ItemDataChanged"),
            object: nil
        )
    }
    
    @objc private func handleDataChange() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            self?.invalidateCacheForDataChanges()
            self?.suggestions = []
        }
    }
    
    // MARK: - Public Methods
    
    func getSuggestions(for searchText: String, in list: List? = nil, limit: Int? = nil) {
        guard !searchText.isEmpty else {
            suggestions = []
            return
        }
        
        // Create cache key
        let listId = list?.id.uuidString ?? "global"
        let limitKey = limit != nil ? "_limit\(limit!)" : "_unlimited"
        let cacheKey = "\(searchText.lowercased())_\(listId)\(limitKey)"
        
        // Check cache first (temporarily disabled to ensure fresh data after deletions)
        // TODO: Re-enable cache after fixing deletion synchronization
        // if let cachedSuggestions = suggestionCache.getCachedSuggestions(for: cacheKey) {
        //     suggestions = cachedSuggestions
        //     return
        // }
        
        // Phase 14 Enhancement: Search current list first, then expand to all lists if needed
        let allItems = getAllItems(from: list)
        var matchingSuggestions = generateAdvancedSuggestions(from: allItems, searchText: searchText)
        
        // If we have less than 3 suggestions from current list, expand search to all lists
        if matchingSuggestions.count < 3 && list != nil {
            let globalItems = getAllItems(from: nil) // Search all lists
            let globalSuggestions = generateAdvancedSuggestions(from: globalItems, searchText: searchText)
            
            // Merge suggestions, prioritizing current list items
            var combinedSuggestions: [ItemSuggestion] = []
            var addedSuggestionKeys: Set<String> = []
            
            // Add current list suggestions first (higher priority)
            for suggestion in matchingSuggestions {
                // Create unique key based on title + description to avoid duplicating identical items
                let key = "\(suggestion.title.lowercased())|\(suggestion.description ?? "")"
                if !addedSuggestionKeys.contains(key) {
                    combinedSuggestions.append(suggestion)
                    addedSuggestionKeys.insert(key)
                }
            }
            
            // Add global suggestions that aren't already included
            for suggestion in globalSuggestions {
                // Create unique key based on title + description to avoid duplicating identical items
                let key = "\(suggestion.title.lowercased())|\(suggestion.description ?? "")"
                if !addedSuggestionKeys.contains(key) {
                    // Slightly reduce score for global items to prioritize current list
                    let globalSuggestion = ItemSuggestion(
                        title: suggestion.title,
                        description: suggestion.description,
                        frequency: suggestion.frequency,
                        lastUsed: suggestion.lastUsed,
                        score: suggestion.score * 0.9, // Reduced score for global items
                        recencyScore: suggestion.recencyScore,
                        frequencyScore: suggestion.frequencyScore,
                        totalOccurrences: suggestion.totalOccurrences,
                        averageUsageGap: suggestion.averageUsageGap
                    )
                    combinedSuggestions.append(globalSuggestion)
                    addedSuggestionKeys.insert(key)
                }
            }
            
            matchingSuggestions = combinedSuggestions
        }
        
        let sortedSuggestions = matchingSuggestions.sorted { $0.score > $1.score }
        
        let finalSuggestions: [ItemSuggestion]
        if let limit = limit {
            finalSuggestions = Array(sortedSuggestions.prefix(limit))
        } else {
            // Show all matching suggestions (Phase 14 requirement)
            finalSuggestions = sortedSuggestions
        }
        
        // Cache the results
        let context = "search:\(searchText)_list:\(listId)_limit:\(limit?.description ?? "unlimited")"
        suggestionCache.cacheSuggestions(finalSuggestions, for: cacheKey, context: context)
        
        suggestions = finalSuggestions
    }
    
    func getRecentItems(limit: Int = 20) -> [ItemSuggestion] {
        let allItems = dataRepository.getAllLists().flatMap { $0.items }
        let now = Date()
        
        // Group items by title to calculate frequency and recency
        var itemGroups: [String: [Item]] = [:]
        for item in allItems {
            guard !item.title.isEmpty else { continue }
            let key = item.title.lowercased()
            itemGroups[key, default: []].append(item)
        }
        
        return itemGroups.compactMap { (title, items) -> ItemSuggestion? in
            let mostRecentItem = items.max { $0.createdAt < $1.createdAt }
            guard let recentItem = mostRecentItem else { return nil }
            
            let lastUsed = recentItem.modifiedAt
            let recencyScore = calculateRecencyScore(for: lastUsed, currentTime: now)
            let frequencyScore = calculateFrequencyScore(frequency: items.count, maxFrequency: 10)
            
            // Calculate average usage gap
            let sortedDates = items.map { $0.createdAt }.sorted()
            let averageGap = calculateAverageUsageGap(dates: sortedDates)
            
            let combinedScore = (recencyScore * recencyWeight) + (frequencyScore * frequencyWeight)
            
            return ItemSuggestion(
                title: recentItem.title,
                description: recentItem.itemDescription,
                frequency: items.count,
                lastUsed: lastUsed,
                score: combinedScore,
                recencyScore: recencyScore,
                frequencyScore: frequencyScore,
                totalOccurrences: items.count,
                averageUsageGap: averageGap
            )
        }
        .sorted { $0.score > $1.score }
        .prefix(limit)
        .map { $0 }
    }
    
    func clearSuggestions() {
        suggestions = []
    }
    
    // MARK: - Cache Management
    
    func clearSuggestionCache() {
        suggestionCache.clearCache()
    }
    
    func invalidateCacheFor(searchText: String) {
        suggestionCache.invalidateCache(for: searchText)
    }
    
    // Invalidate cache when data changes (should be called when items are added/modified/deleted)
    func invalidateCacheForDataChanges() {
        suggestionCache.clearCache()
    }
    
    // MARK: - Private Methods
    
    private func getAllItems(from list: List?) -> [Item] {
        if let specificList = list {
            return specificList.items
        } else {
            return dataRepository.getAllLists().flatMap { $0.items }
        }
    }
    
    private func generateAdvancedSuggestions(from items: [Item], searchText: String) -> [ItemSuggestion] {
        let searchLower = searchText.lowercased()
        let now = Date()
        
        var suggestions: [ItemSuggestion] = []
        
        // Phase 14 Fix: Show individual items as separate suggestions, not grouped by title
        for item in items {
            guard !item.title.isEmpty else { continue }
            
            let matchScore = calculateMatchScore(searchText: searchLower, itemTitle: item.title.lowercased())
            
            if matchScore > 0 {
                let lastUsed = item.modifiedAt
                let recencyScore = calculateRecencyScore(for: lastUsed, currentTime: now)
                
                // For individual items, frequency is always 1
                let frequencyScore = calculateFrequencyScore(frequency: 1, maxFrequency: 10)
                
                // For individual items, no usage gap calculation needed
                let averageGap: TimeInterval = 0
                
                // Combine all scores with weights
                let combinedScore = (matchScore * matchWeight) + 
                                  (recencyScore * recencyWeight) + 
                                  (frequencyScore * frequencyWeight)
                
                let suggestion = ItemSuggestion(
                    title: item.title,
                    description: item.itemDescription,
                    frequency: 1, // Individual item frequency is always 1
                    lastUsed: lastUsed,
                    score: combinedScore,
                    recencyScore: recencyScore,
                    frequencyScore: frequencyScore,
                    totalOccurrences: 1, // Individual item occurrence is always 1
                    averageUsageGap: averageGap
                )
                
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
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
    
    // MARK: - Advanced Scoring Methods
    
    private func calculateRecencyScore(for date: Date, currentTime: Date) -> Double {
        let daysSinceLastUse = currentTime.timeIntervalSince(date) / 86400 // Convert to days
        
        if daysSinceLastUse < 0 {
            return 100.0 // Future date (edge case)
        }
        
        if daysSinceLastUse <= 1.0 {
            return 100.0 // Used within last day
        } else if daysSinceLastUse <= 7.0 {
            return 90.0 - (daysSinceLastUse - 1.0) * 10.0 // Linear decay over week
        } else if daysSinceLastUse <= maxRecencyDays {
            return 60.0 - ((daysSinceLastUse - 7.0) / (maxRecencyDays - 7.0)) * 50.0 // Decay to 10
        } else {
            return 10.0 // Minimum score for very old items
        }
    }
    
    private func calculateFrequencyScore(frequency: Int, maxFrequency: Int) -> Double {
        guard maxFrequency > 0 else { return 0.0 }
        
        let normalizedFrequency = min(Double(frequency), Double(maxFrequency))
        let baseScore = (normalizedFrequency / Double(maxFrequency)) * 100.0
        
        // Apply logarithmic scaling to prevent very frequent items from dominating
        let logScale = log(normalizedFrequency + 1) / log(Double(maxFrequency) + 1)
        return baseScore * 0.7 + logScale * 100.0 * 0.3
    }
    
    private func calculateAverageUsageGap(dates: [Date]) -> TimeInterval {
        guard dates.count > 1 else { return 0.0 }
        
        var totalGap: TimeInterval = 0.0
        for i in 1..<dates.count {
            totalGap += dates[i].timeIntervalSince(dates[i-1])
        }
        
        return totalGap / Double(dates.count - 1)
    }
}