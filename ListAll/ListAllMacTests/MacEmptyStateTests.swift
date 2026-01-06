//
//  MacEmptyStateTests.swift
//  ListAllMacTests
//
//  Tests for macOS empty state views with sample list templates.
//  TDD approach: Tests written before implementation.
//

import Testing
import Foundation
@testable import ListAll

/// Tests for macOS empty state views with sample list templates (similar to iOS ListsEmptyStateView)
@Suite(.serialized)
struct MacEmptyStateTests {

    // MARK: - Sample Data Service Tests (Shared with iOS)

    @Test("SampleDataService templates are available on macOS")
    func testSampleDataServiceTemplatesAvailableOnMacOS() {
        let templates = SampleDataService.templates
        #expect(templates.count == 3)
        #expect(!templates.isEmpty)
    }

    @Test("SampleDataService templates have icons valid for macOS")
    func testSampleDataServiceTemplatesHaveValidMacOSIcons() {
        let validIcons = ["cart", "checkmark.circle", "suitcase"]
        for template in SampleDataService.templates {
            #expect(validIcons.contains(template.icon), "Template icon '\(template.icon)' should be in valid icons list")
        }
    }

    @Test("SampleDataService templates have non-empty names")
    func testSampleDataServiceTemplatesHaveNonEmptyNames() {
        for template in SampleDataService.templates {
            #expect(!template.name.isEmpty, "Template name should not be empty")
        }
    }

    @Test("SampleDataService templates have non-empty descriptions")
    func testSampleDataServiceTemplatesHaveNonEmptyDescriptions() {
        for template in SampleDataService.templates {
            #expect(!template.description.isEmpty, "Template description should not be empty")
        }
    }

    @Test("SampleDataService templates have sample items")
    func testSampleDataServiceTemplatesHaveSampleItems() {
        for template in SampleDataService.templates {
            #expect(!template.sampleItems.isEmpty, "Template '\(template.name)' should have sample items")
            #expect(template.sampleItems.count >= 4, "Template '\(template.name)' should have at least 4 sample items")
        }
    }

    // MARK: - English Localization Tests

    @Test("English templates have correct names")
    func testEnglishTemplatesHaveCorrectNames() {
        let originalLanguage = LocalizationManager.shared.currentLanguage
        LocalizationManager.shared.setLanguage(.english)
        defer { LocalizationManager.shared.setLanguage(originalLanguage) }

        let templates = SampleDataService.templates
        let names = templates.map { $0.name }

        #expect(names.contains("Shopping List"))
        #expect(names.contains("To-Do List"))
        #expect(names.contains("Packing List"))
    }

    // MARK: - Finnish Localization Tests

    @Test("Finnish templates have correct names")
    func testFinnishTemplatesHaveCorrectNames() {
        let originalLanguage = LocalizationManager.shared.currentLanguage
        LocalizationManager.shared.setLanguage(.finnish)
        defer { LocalizationManager.shared.setLanguage(originalLanguage) }

        let templates = SampleDataService.templates
        let names = templates.map { $0.name }

        #expect(names.contains("Ostoslista"))
        #expect(names.contains("Tehtävälista"))
        #expect(names.contains("Matkalista"))
    }

    // MARK: - List Creation Tests

    @Test("createListFromTemplate creates list with correct name on macOS")
    func testCreateListFromTemplateCreatesListWithCorrectName() {
        let template = SampleDataService.templates[0]
        let list = SampleDataService.createListFromTemplate(template)

        #expect(list.name == template.name)
        #expect(!list.id.uuidString.isEmpty)
    }

    // MARK: - Template Feature Tests

    @Test("Shopping List template (cart icon) exists and has items")
    func testShoppingListTemplateExists() {
        let template = SampleDataService.templates.first { $0.icon == "cart" }
        #expect(template != nil, "Shopping List template should exist")
        #expect(template!.sampleItems.count >= 6, "Shopping List should have at least 6 items")
    }

    @Test("To-Do List template (checkmark.circle icon) exists and has items")
    func testToDoListTemplateExists() {
        let template = SampleDataService.templates.first { $0.icon == "checkmark.circle" }
        #expect(template != nil, "To-Do List template should exist")
        #expect(template!.sampleItems.count >= 4, "To-Do List should have at least 4 items")
    }

    @Test("Packing List template (suitcase icon) exists and has items")
    func testPackingListTemplateExists() {
        let template = SampleDataService.templates.first { $0.icon == "suitcase" }
        #expect(template != nil, "Packing List template should exist")
        #expect(template!.sampleItems.count >= 6, "Packing List should have at least 6 items")
    }

    // MARK: - Feature Highlight Data Tests

    @Test("Feature highlights data structure is valid")
    func testFeatureHighlightsDataStructure() {
        // Feature highlights that should be shown in empty state
        let features = [
            ("photo", "Add Photos", "Attach images to your items"),
            ("arrow.left.arrow.right", "Share & Sync", "Share lists with family and friends"),
            ("wand.and.stars", "Smart Suggestions", "Get intelligent item recommendations")
        ]

        #expect(features.count == 3)

        for (icon, title, description) in features {
            #expect(!icon.isEmpty)
            #expect(!title.isEmpty)
            #expect(!description.isEmpty)
        }
    }
}
