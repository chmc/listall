# ListAll App - Frontend Design

## Design Principles

### User Experience
- **Simplicity First:** Clean, uncluttered interface focusing on core functionality
- **Consistency:** Uniform design patterns across all screens
- **Accessibility:** Full VoiceOver support and accessibility compliance
- **Performance:** Smooth animations and responsive interactions
- **Intuitive Navigation:** Clear information hierarchy and logical flow

### Visual Design
- **Modern iOS Design:** Follow Apple's Human Interface Guidelines
- **Adaptive Layout:** Support for different screen sizes and orientations
- **Dark Mode:** Full support for light and dark appearance
- **Typography:** System fonts with appropriate hierarchy
- **Color Scheme:** Subtle, non-distracting colors with good contrast

## Screen Architecture

### Main Navigation
- **Tab Bar:** Primary navigation between main sections
- **Navigation Stack:** Hierarchical navigation within each section
- **Modal Presentations:** For creation, editing, and sharing flows

### Screen Hierarchy
```
MainView (TabView)
├── ListsView (Lists List)
│   ├── ListView (Items List)
│   │   ├── ItemDetailView (Item Details)
│   │   └── ItemEditView (Edit Item)
│   ├── CreateListView (New List)
│   └── ListSettingsView (List Options)
├── SearchView (Global Search)
├── SettingsView (App Settings)
└── ExportView (Data Management)
```

## Core Views

### 1. ListsView (Main Screen)
**Purpose:** Display all user's lists in order of preference

**Layout:**
- Navigation bar with "Edit" button and "+" button
- List of list rows with drag-to-reorder capability
- Empty state with onboarding for new users

**List Row Components:**
- List name (primary text)
- Item count (secondary text)
- Crossed out item count (if any, shown in parentheses)
- Chevron indicator for navigation
- Swipe actions: Delete, Share, Duplicate

**Interactions:**
- Tap to open list
- Long press to enter edit mode
- Swipe for quick actions
- Drag to reorder lists

### 2. ListView (Items List)
**Purpose:** Display items within a specific list

**Layout:**
- Navigation bar with list name, back button, and options menu
- Toggle button for showing/hiding crossed out items
- List of item rows
- Floating action button for adding new items

**Item Row Components:**
- Checkbox (for crossing out items)
- Item title (primary text)
- Quantity (secondary text, formatted as integer if present)
- Image count indicator (if item has images)
- Drag handle for reordering

**Interactions:**
- Tap checkbox to cross out/uncross item
- Tap row to view item details
- Long press to enter edit mode
- Swipe for quick actions (delete, duplicate)
- Drag to reorder items

### 3. ItemDetailView (Item Details)
**Purpose:** Show full details of a selected item

**Layout:**
- Navigation bar with back button and edit button
- Scrollable content area
- Title section
- Description section (with clickable URLs)
- Quantity section
- Images gallery (if any)
- Action buttons (Edit, Delete, Duplicate)

**Content Sections:**
- **Title:** Large, prominent text
- **Description:** Multi-line text with URL detection (supports extensive notes up to 50,000 characters)
- **Quantity:** Highlighted quantity information (formatted as integer)
- **Images:** Grid layout of item images
- **Metadata:** Creation and modification dates

### 4. CreateListView (New List)
**Purpose:** Create a new list or clone an existing one

**Layout:**
- Navigation bar with "Cancel" and "Create" buttons
- Form fields for list details
- Optional: Template selection for cloning

**Form Fields:**
- List name (required, text field)
- Description (optional, text view)
- Template selection (if cloning)

### 5. ItemEditView (Edit Item)
**Purpose:** Create or edit an item

**Layout:**
- Navigation bar with "Cancel" and "Save" buttons
- Form fields for item details
- Image management section
- Suggestion list (for new items)

**Form Fields:**
- Title (required, text field)
- Description (optional, multi-line text view supporting up to 50,000 characters)
- Quantity (optional, integer number field)
- Images (photo picker integration)

**Smart Suggestions:**
- Show previously used items as suggestions
- Allow selection from suggestions with pre-filled details
- Enable editing of suggested items before adding

## UI Components

### Custom Components

#### ItemRowView
**Purpose:** Reusable component for displaying items in lists

**Props:**
- Item data
- Show crossed out state
- Show image count
- Tap handler
- Long press handler

**Features:**
- Animated checkbox interaction
- Strikethrough text for crossed out items
- Image count badge
- Drag handle for reordering

#### ListRowView
**Purpose:** Reusable component for displaying lists

**Props:**
- List data
- Item counts
- Tap handler
- Swipe actions

**Features:**
- Primary and secondary text
- Item count display
- Swipe actions (delete, share, duplicate)
- Drag handle for reordering

#### ImagePickerView
**Purpose:** Handle image selection and management

**Features:**
- Camera integration
- Photo library access
- Image compression
- Thumbnail generation
- Multiple image selection

#### SuggestionListView
**Purpose:** Display smart suggestions for new items

**Features:**
- Filtered list of previous items
- Highlight matching text
- Pre-fill form data
- Allow editing before adding

### System Components

#### Navigation
- **NavigationView:** Standard iOS navigation
- **TabView:** Main app navigation
- **Sheet:** Modal presentations
- **Alert:** Confirmations and alerts

#### Input Controls
- **TextField:** Single-line text input
- **TextEditor:** Multi-line text input
- **Toggle:** Boolean settings
- **Picker:** Selection from options

#### Display Components
- **List:** Primary data display
- **ScrollView:** Scrollable content
- **LazyVStack:** Performance-optimized lists
- **Grid:** Image galleries

## User Flows

### 1. Create New List
1. User taps "+" button on main screen
2. CreateListView appears as modal
3. User enters list name
4. User taps "Create"
5. New list appears in main list
6. User is taken to the new list

### 2. Add Item to List
1. User opens a list
2. User taps "+" button
3. ItemEditView appears as modal
4. User types item name
5. App shows suggestions (if any)
6. User either selects suggestion or continues typing
7. User fills in additional details (optional)
8. User adds images (optional)
9. User taps "Save"
10. Item appears in list

### 3. Cross Out Item
1. User taps checkbox next to item
2. Item animates to crossed out state
3. Item moves to bottom of visible items
4. Item count updates

### 4. Share List
1. User taps options menu on list
2. User selects "Share"
3. System share sheet appears
4. User chooses sharing method
5. List data is exported and shared

### 5. Export Data
1. User goes to Settings
2. User taps "Export Data"
3. ExportView appears
4. User selects export options
5. User chooses export method (file or clipboard)
6. Data is exported in selected format

## Accessibility Features

### VoiceOver Support
- All interactive elements have proper labels
- Logical reading order
- Custom actions for complex interactions
- Hints for non-obvious interactions

### Dynamic Type
- Support for all system text sizes
- Proper text scaling
- Maintained layout integrity

### Color and Contrast
- High contrast mode support
- Color-blind friendly design
- Sufficient color contrast ratios

### Motor Accessibility
- Large touch targets (minimum 44pt)
- Support for Switch Control
- Voice Control compatibility

## Performance Considerations

### List Performance
- Lazy loading for large lists
- Efficient cell reuse
- Smooth scrolling with proper prefetching

### Image Handling
- Thumbnail generation for list views
- Lazy loading of full images
- Memory management for image data

### Animation Performance
- Smooth 60fps animations
- Proper animation timing
- Reduced motion support

## Responsive Design

### iPhone Support
- iPhone SE to iPhone Pro Max
- Portrait and landscape orientations
- Safe area handling

### iPad Support
- Adaptive layouts for larger screens
- Split view compatibility
- Drag and drop support

### Future Platform Considerations
- **watchOS:** Simplified list view with complications
- **macOS:** Multi-window support and keyboard shortcuts
- **Android:** Material Design adaptation
