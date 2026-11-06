# Smart Suggestions Features

[< Back to Summary](./SUMMARY.md)

## Status: iOS 13/13 | iPad 13/13 | macOS 13/13 | watchOS N/A (Complete)

*Count = ✅ / applicable rows (N/A excluded). Suggestions appear while typing an item title; the watch app cannot add items.*

---

## Feature Matrix

| Feature | iOS | iPad | macOS | watchOS | Implementation |
|---------|:---:|:----:|:-----:|:-------:|----------------|
| Title Matching | ✅ | ✅ | ✅ | N/A | Shared Service |
| Fuzzy Matching | ✅ | ✅ | ✅ | N/A | Shared Service |
| Frequency Scoring | ✅ | ✅ | ✅ | N/A | Shared Service |
| Recency Scoring | ✅ | ✅ | ✅ | N/A | Shared Service |
| Combined Scoring | ✅ | ✅ | ✅ | N/A | Shared Service |
| Cache (5 min TTL) | ✅ | ✅ | ✅ | N/A | Shared Service |
| Cross-List Search | ✅ | ✅ | ✅ | N/A | Shared Service |
| Exclude Current Item | ✅ | ✅ | ✅ | N/A | Shared Service |
| Recent Items List | ✅ | ✅ | ✅ | N/A | Shared Service |
| Suggestion UI | ✅ | ✅ | ✅ | N/A | Platform UI |
| Collapse/Expand Toggle | ✅ | ✅ | ✅ | N/A | Platform UI |
| Score Indicators | ✅ | ✅ | ✅ | N/A | Platform UI |
| Hot Item Indicator | ✅ | ✅ | ✅ | N/A | Platform UI |

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

**iOS / iPad**:
- `Views/Components/SuggestionListView.swift`

**macOS**:
- `ListAllMac/Views/Components/MacSuggestionListView.swift`
