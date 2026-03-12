//
//  MacSidebarCountFormatTests.swift
//  ListAllMacTests
//
//  Tests for sidebar count format change: "4 (6)" → "4/6"
//

import Testing
import Foundation
@testable import ListAll

struct MacSidebarCountFormatTests {

    // MARK: - Helper to create a list with items

    private func makeList(name: String = "Test", activeCount: Int, crossedOutCount: Int) -> ListAll.List {
        var list = ListAll.List(name: name)
        for i in 0..<activeCount {
            var item = Item(title: "Active \(i)")
            item.isCrossedOut = false
            list.items.append(item)
        }
        for i in 0..<crossedOutCount {
            var item = Item(title: "Done \(i)")
            item.isCrossedOut = true
            list.items.append(item)
        }
        return list
    }

    // MARK: - Count Format Tests

    @Test("Count format shows active/total when some items are crossed out")
    func countFormatWithMixedItems() {
        let list = makeList(activeCount: 4, crossedOutCount: 2)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "4/6")
    }

    @Test("Count format shows total only when all items are active")
    func countFormatAllActive() {
        let list = makeList(activeCount: 5, crossedOutCount: 0)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "5/5")
    }

    @Test("Count format shows 0/N when all items are crossed out")
    func countFormatAllCrossedOut() {
        let list = makeList(activeCount: 0, crossedOutCount: 3)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "0/3")
    }

    @Test("Count format shows 0/0 for empty list")
    func countFormatEmptyList() {
        let list = makeList(activeCount: 0, crossedOutCount: 0)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "0/0")
    }

    @Test("Count format shows 1/1 for single active item")
    func countFormatSingleItem() {
        let list = makeList(activeCount: 1, crossedOutCount: 0)
        let result = MacSidebarFormatting.itemCountText(for: list)
        #expect(result == "1/1")
    }
}
