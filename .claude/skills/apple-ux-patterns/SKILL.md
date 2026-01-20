---
name: apple-ux-patterns
description: Apple UX interaction patterns for state communication, feedback, gestures, and animations. Use when implementing user interactions, handling states, or designing user flows.
---

# Apple UX Interaction Patterns

> **Scope**: iOS, iPadOS, macOS, watchOS. Does not cover visionOS spatial interaction patterns.

## State Communication

### Loading States

**Timing Guidelines:**
- <0.5s: No indicator needed
- 0.5-2s: Activity indicator only
- 2-10s: Activity indicator + descriptive text
- >10s: Determinate progress if possible

**Patterns:**
```swift
// Skeleton loading (instant feedback)
List(items) { item in
    ItemRow(item: item)
}
.redacted(reason: isLoading ? .placeholder : [])

// Progress view (determinate)
ProgressView(value: progress, total: 1.0)

// Activity indicator (indeterminate)
ProgressView()
```

**Antipatterns:**
- Blank/static screens during loading
- No feedback for operations >0.5s
- Progress bar for unknown duration
- Blocking entire UI unnecessarily

### Empty States

**Patterns:**
```swift
// iOS 17+ ContentUnavailableView
ContentUnavailableView(
    "No Items Yet",
    systemImage: "list.bullet",
    description: Text("Tap + to add your first item")
)
```

- First-run: Welcome message + clear CTA
- No results: Acknowledge search, suggest alternatives
- No content: Explain why, show how to add

**Antipatterns:**
- Generic "No data" without explanation
- Empty white screen
- No action path forward

### Error States

**Patterns:**
- **Inline errors**: Below field, icon + text (not color alone)
- **Validation timing**: "Reward early, punish late" (validate on blur, not while typing)
- **Recovery actions**: Always provide next steps

```swift
// Inline validation
TextField("Email", text: $email)
    .border(emailError != nil ? Color.red : Color.clear)

if let error = emailError {
    Label(error, systemImage: "exclamationmark.triangle")
        .foregroundColor(.red)
        .font(.caption)
}
```

**Antipatterns:**
- Vague messages ("Error 500")
- Color-only indicators
- No recovery path
- Validating while typing

### Success States

**Patterns:**
- Passive confirmation: Item moves, count updates, checkbox checked
- Brief haptic: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
- Non-blocking banner for important actions (auto-dismiss 2-3s)

**Antipatterns:**
- Modal alert for routine successes
- No feedback for destructive actions
- Success message blocking workflow

---

## User Feedback

### Haptic Feedback

> **Platform**: iOS/iPadOS only. macOS has no Taptic Engine. watchOS uses `WKInterfaceDevice.current().play()` instead.

**Three Categories (iOS/iPadOS):**

| Type | Use Case | Styles |
|------|----------|--------|
| Impact | UI interactions | light, medium, heavy, rigid, soft |
| Selection | Picker scrolling | single style |
| Notification | Success/warning/error | success, warning, error |

```swift
// Prepare for performance
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.prepare()
generator.impactOccurred()

// SwiftUI (iOS 17+)
Button("Delete") { }
    .sensoryFeedback(.warning, trigger: showConfirmation)
```

**Antipatterns:**
- Haptic on every tap (overwhelming)
- Wrong type for context
- Not preparing generator (noticeable lag)
- Haptics without visual feedback

### Visual Feedback

**Patterns:**
- Instant response to touch down
- Selection: Checkmarks + blue highlight
- Drag: Item lifts (shadow, scale), drop targets highlight
- Focus: Subtle border on focused field

**Antipatterns:**
- No visual response to touch
- Delayed feedback (>100ms)
- Over-the-top animations
- Unclear selection state

---

## Confirmation & Destructive Actions

### Confirmation Dialogs

**When to Use:**
- Destructive actions (delete, discard)
- Irreversible actions
- Actions with significant consequences

```swift
.confirmationDialog(
    "Delete this item?",
    isPresented: $showingConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) { deleteItem() }
    Button("Cancel", role: .cancel) { }
}
```

**Antipatterns:**
- Confirmation for every action (fatigue)
- Vague text ("Are you sure?")
- Destructive as default button
- No cancel option

### Undo vs Confirmation

**Prefer Undo When:**
- Action is immediately visible
- Undo is technically feasible
- User is in active workflow

```swift
func deleteItem() {
    let item = selectedItem
    items.remove(at: index)
    showUndoBanner(message: "Item deleted") {
        items.insert(item, at: index)
    }
}
```

### Swipe Actions

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) { deleteItem(item) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    .swipeActions(edge: .leading) {
        Button { pinItem(item) } label: {
            Label("Pin", systemImage: "pin")
        }
        .tint(.yellow)
    }
}
```

- **Trailing edge**: Destructive (Delete, Archive)
- **Leading edge**: Contextual (Pin, Flag, Mark Read)
- Max 3 actions per edge

---

## Forms & Input

### Keyboard Types

```swift
TextField("Email", text: $email)
    .keyboardType(.emailAddress)
    .textContentType(.emailAddress)
    .submitLabel(.next)

TextField("Phone", text: $phone)
    .keyboardType(.phonePad)

TextField("Amount", text: $amount)
    .keyboardType(.decimalPad)
```

### Pickers

```swift
// Menu picker (compact, good for forms)
Picker("Category", selection: $category) {
    ForEach(categories) { Text($0.name).tag($0) }
}
.pickerStyle(.menu)

// Segmented (2-5 options only)
Picker("View", selection: $viewType) {
    Text("List").tag(ViewType.list)
    Text("Grid").tag(ViewType.grid)
}
.pickerStyle(.segmented)

// Date picker (compact)
DatePicker("Date", selection: $date)
    .datePickerStyle(.compact)
```

**Antipatterns:**
- Wrong keyboard type for field
- Labels that disappear (placeholder as label)
- No way to dismiss keyboard
- Wheel picker for many options

---

## Gestures

### Standard Gestures

| Gesture | Purpose |
|---------|---------|
| Tap | Select, activate |
| Long-press | Context menu, edit mode |
| Swipe | Navigate, reveal actions |
| Pinch | Zoom |
| Edge swipe (left) | Back navigation |

```swift
Text("Item")
    .contextMenu {
        Button("Edit", systemImage: "pencil") { }
        Button("Share", systemImage: "square.and.arrow.up") { }
        Button("Delete", systemImage: "trash", role: .destructive) { }
    }
```

**Antipatterns:**
- Custom gestures conflicting with system (edge swipe)
- Hidden gestures with no discoverability
- Gestures as only way to access features
- No button alternative for gesture actions

---

## Animation

### Timing Guidelines

- **Micro-interactions**: 100-200ms
- **Standard transitions**: 200-350ms
- **Complex animations**: 350-500ms
- **Never >500ms**: Feels sluggish

### Easing

```swift
// Standard transitions
.animation(.easeInOut(duration: 0.3), value: isExpanded)

// Interactive/playful
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)

// iOS 17+ presets
.animation(.smooth, value: isSelected)
.animation(.snappy, value: count)
```

### Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .easeInOut(duration: 0.3)
}

withAnimation(animation) {
    isExpanded.toggle()
}
```

**When Reduce Motion is enabled:**
- Remove parallax effects
- Use fade instead of motion
- Keep essential animations (progress indicators)

**Antipatterns:**
- Animations >500ms
- Animations blocking user interaction
- Decorative-only animations
- Ignoring Reduce Motion setting

---

## Onboarding

### Permission Requests

**Timing:**
- NOT on first launch
- Just-in-time when feature is used
- Explain benefit before system dialog
- One permission at a time

```swift
// Prime user before system dialog
struct CameraPermissionPrimer: View {
    var body: some View {
        VStack {
            Image(systemName: "camera")
            Text("Take Photos of Items")
            Text("Camera access lets you photograph items.")
            Button("Enable Camera") { requestCameraPermission() }
        }
    }
}
```

**Antipatterns:**
- All permissions on launch
- No explanation before request
- Requesting unnecessary permissions

### Feature Discovery

- Tooltips at point of use
- "What's New" on update
- Empty state onboarding
- Skip button always visible

---

## Search & Filtering

```swift
NavigationStack {
    List(filteredItems) { item in
        ItemRow(item)
    }
    .searchable(text: $searchText)
    .searchScopes($searchScope) {
        Text("All").tag(SearchScope.all)
        Text("Active").tag(SearchScope.active)
    }
}
```

**Patterns:**
- Search in navigation bar
- Scopes for filtering
- Show active filter count
- "Clear All" option

**Antipatterns:**
- Hidden search
- No way to clear filters
- Too many filter options

---

## Debug Checklist

When reviewing UX implementation:

1. **Loading**: Feedback for >0.5s operations?
2. **Empty States**: Helpful message + CTA?
3. **Errors**: Specific message + recovery?
4. **Haptics**: Appropriate type and timing?
5. **Destructive**: Confirmation or undo?
6. **Keyboard**: Correct type, dismissible?
7. **Animation**: <500ms, respects Reduce Motion?
8. **Gestures**: Discoverable, with alternatives?
9. **Permissions**: Just-in-time, explained?
