# Smart Suggestions Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 13/13 | macOS 13/13 (Complete)

---

## Feature Matrix

| Feature | iOS | macOS | Implementation |
|---------|:---:|:-----:|----------------|
| Title Matching | ✅ | ✅ | Shared Service |
| Fuzzy Matching | ✅ | ✅ | Shared Service |
| Frequency Scoring | ✅ | ✅ | Shared Service |
| Recency Scoring | ✅ | ✅ | Shared Service |
| Combined Scoring | ✅ | ✅ | Shared Service |
| Cache (5 min TTL) | ✅ | ✅ | Shared Service |
| Cross-List Search | ✅ | ✅ | Shared Service |
| Exclude Current Item | ✅ | ✅ | Shared Service |
| Recent Items List | ✅ | ✅ | Shared Service |
| Suggestion UI | ✅ | ✅ | Platform UI |
| Collapse/Expand Toggle | ✅ | ✅ | Platform UI |
| Score Indicators | ✅ | ✅ | Platform UI |
| Hot Item Indicator | ✅ | ✅ | Platform UI |

---

## How It Works

1. User types 2+ characters in item title field
2. SuggestionService queries all items across lists
3. Scoring algorithm considers:
   - Title similarity (fuzzy matching)
   - Frequency (how often item appears)
   - Recency (when last used)
4. Top suggestions displayed with indicators
5. Selecting suggestion fills title, quantity, description

---

## Implementation Files

**Shared**:
- `Services/SuggestionService.swift` - All suggestion logic

**iOS**:
- `Views/Components/SuggestionListView.swift`

**macOS**:
- `ListAllMac/Views/Components/MacSuggestionListView.swift`
