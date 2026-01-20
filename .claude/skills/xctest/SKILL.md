---
name: xctest
description: XCTest and XCUITest patterns for iOS/watchOS testing. Use when writing unit tests, UI tests, or debugging test failures.
---

# XCTest Best Practices

## Test Structure

### Arrange-Act-Assert Pattern
```swift
func testAddItemToList_incrementsCount() {
    // Arrange
    let list = List(name: "Groceries")
    let initialCount = list.items.count

    // Act
    list.addItem(Item(text: "Milk"))

    // Assert
    XCTAssertEqual(list.items.count, initialCount + 1)
}
```

### Naming Convention
Format: `test<MethodOrBehavior>_<Scenario>_<ExpectedOutcome>`
- Good: `testLogin_withInvalidCredentials_showsErrorMessage`
- Bad: `testLogin1`, `testLoginStuff`

## Assertions

### Use Specific Assertions
```swift
// GOOD: Clear failure messages
XCTAssertEqual(items.count, 3, "Expected 3 items after adding")
XCTAssertTrue(list.isEmpty)
XCTAssertNil(error)
XCTAssertThrowsError(try service.save(invalidItem))

// Use XCTUnwrap for safe optionals
let item = try XCTUnwrap(list.items.first, "List should have item")
XCTAssertEqual(item.text, "Milk")

// BAD: Generic with poor failure messages
XCTAssert(items.count == 3)  // "XCTAssertTrue failed"
```

## Async Testing

### Modern async/await
```swift
func testFetchItems_returnsItems() async throws {
    let mockAPI = MockAPI()
    mockAPI.itemsToReturn = [Item(text: "Test")]
    let service = ItemService(api: mockAPI)

    let items = try await service.fetchItems()

    XCTAssertEqual(items.count, 1)
}
```

### Expectations for callbacks
```swift
func testAsyncOperation_completesWithSuccess() {
    let expectation = expectation(description: "completes")

    service.performAsync { result in
        XCTAssertTrue(result.isSuccess)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
}
```

## UI Testing

### Accessibility Identifiers
```swift
// In production code
Button("Add Item")
    .accessibilityIdentifier("addItemButton")

// In UI test
let addButton = app.buttons["addItemButton"]
XCTAssertTrue(addButton.exists)
addButton.tap()
```

### Wait for Elements
```swift
// GOOD: Wait with timeout
let element = app.staticTexts["Welcome"]
XCTAssertTrue(element.waitForExistence(timeout: 10))

// BAD: Fixed delay
sleep(3)  // Flaky and slow
```

## Antipatterns

### Multiple behaviors in one test
```swift
// BAD: Tests too many things
func testListOperations() {
    list.addItem(item1)
    XCTAssertEqual(list.count, 1)
    list.addItem(item2)
    XCTAssertEqual(list.count, 2)
    list.removeItem(item1)
    XCTAssertEqual(list.count, 1)
}

// GOOD: Focused tests
func testAddItem_incrementsCount() { ... }
func testRemoveItem_decrementsCount() { ... }
```

### Force unwrapping
```swift
// BAD: Crashes on failure
let item = list.items.first!

// GOOD: Safe unwrap
let item = try XCTUnwrap(list.items.first)
```

### No timeouts
```swift
// BAD: Can hang forever
wait(for: [exp], timeout: .infinity)

// GOOD: Reasonable timeout
wait(for: [exp], timeout: 30.0)
```

## Deterministic Test Data

```swift
// GOOD: Fixed, reproducible data
let testItem = Item(
    id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
    text: "Test Item",
    createdAt: Date(timeIntervalSince1970: 1700000000)
)

// BAD: Random data
let testItem = Item(
    id: UUID(),  // Different every run
    text: "Item \(Int.random(in: 1...100))"
)
```
