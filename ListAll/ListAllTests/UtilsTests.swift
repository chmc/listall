//
//  UtilsTests.swift
//  ListAllTests
//
//  Created by Sutela Aleksi on 15.9.2025.
//

import Testing
import Foundation
@testable import ListAll

struct UtilsTests {
    
    // MARK: - ValidationHelper Tests
    
    @Test func testValidateListNameSuccess() async throws {
        let result = ValidationHelper.validateListName("Valid List Name")
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateListNameEmpty() async throws {
        let result = ValidationHelper.validateListName("")
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "List name cannot be empty")
    }
    
    @Test func testValidateListNameWhitespace() async throws {
        let result = ValidationHelper.validateListName("   ")
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "List name cannot be empty")
    }
    
    @Test func testValidateListNameTooLong() async throws {
        let longName = String(repeating: "a", count: 101)
        let result = ValidationHelper.validateListName(longName)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "List name must be 100 characters or less")
    }
    
    @Test func testValidateListNameExactly100Characters() async throws {
        let name = String(repeating: "a", count: 100)
        let result = ValidationHelper.validateListName(name)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemTitleSuccess() async throws {
        let result = ValidationHelper.validateItemTitle("Valid Item Title")
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemTitleEmpty() async throws {
        let result = ValidationHelper.validateItemTitle("")
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Item title cannot be empty")
    }
    
    @Test func testValidateItemTitleWhitespace() async throws {
        let result = ValidationHelper.validateItemTitle("   ")
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Item title cannot be empty")
    }
    
    @Test func testValidateItemTitleTooLong() async throws {
        let longTitle = String(repeating: "a", count: 201)
        let result = ValidationHelper.validateItemTitle(longTitle)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Item title must be 200 characters or less")
    }
    
    @Test func testValidateItemTitleExactly200Characters() async throws {
        let title = String(repeating: "a", count: 200)
        let result = ValidationHelper.validateItemTitle(title)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemDescriptionSuccess() async throws {
        let result = ValidationHelper.validateItemDescription("Valid description")
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemDescriptionEmpty() async throws {
        let result = ValidationHelper.validateItemDescription("")
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemDescriptionTooLong() async throws {
        let longDescription = String(repeating: "a", count: 1001)
        let result = ValidationHelper.validateItemDescription(longDescription)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Item description must be 1000 characters or less")
    }
    
    @Test func testValidateItemDescriptionExactly1000Characters() async throws {
        let description = String(repeating: "a", count: 1000)
        let result = ValidationHelper.validateItemDescription(description)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemQuantitySuccess() async throws {
        let result = ValidationHelper.validateItemQuantity(5)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidateItemQuantityZero() async throws {
        let result = ValidationHelper.validateItemQuantity(0)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Quantity must be at least 1")
    }
    
    @Test func testValidateItemQuantityNegative() async throws {
        let result = ValidationHelper.validateItemQuantity(-1)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Quantity must be at least 1")
    }
    
    @Test func testValidateItemQuantityTooHigh() async throws {
        let result = ValidationHelper.validateItemQuantity(10000)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Quantity must be 9999 or less")
    }
    
    @Test func testValidateItemQuantityExactly9999() async throws {
        let result = ValidationHelper.validateItemQuantity(9999)
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    // MARK: - String Extensions Tests
    
    @Test func testStringIsBlank() async throws {
        #expect("".isBlank == true)
        #expect("   ".isBlank == true)
        #expect("\n\t".isBlank == true)
        #expect("text".isBlank == false)
        #expect(" text ".isBlank == false)
    }
    
    @Test func testStringTrimmed() async throws {
        #expect("  hello  ".trimmed == "hello")
        #expect("\n\tworld\n\t".trimmed == "world")
        #expect("".trimmed == "")
        #expect("no spaces".trimmed == "no spaces")
    }
    
    @Test func testStringAsURL() async throws {
        #expect("https://example.com".asURL != nil)
        #expect("http://test.com".asURL != nil)
        #expect("invalid url".asURL == nil)
        #expect("".asURL == nil)
        #expect("not a url".asURL == nil)
        #expect("ftp://example.com".asURL != nil)
    }
    
    @Test func testStringCapitalizedFirst() async throws {
        #expect("hello".capitalizedFirst == "Hello")
        #expect("HELLO".capitalizedFirst == "HELLO")
        #expect("".capitalizedFirst == "")
        #expect("a".capitalizedFirst == "A")
    }
    
    // MARK: - Date Extensions Tests
    
    @Test func testDateFormatted() async throws {
        let date = Date()
        let formatted = date.customFormatted()
        
        #expect(formatted.isEmpty == false)
        #expect(formatted.count > 5) // Basic length check
    }
    
    @Test func testDateListFormatted() async throws {
        let date = Date()
        let formatted = date.listFormatted()
        
        #expect(formatted.isEmpty == false)
        #expect(formatted.count > 3) // Basic length check
    }
    
    @Test func testDateRelativeFormatted() async throws {
        let now = Date()
        let past = now.addingTimeInterval(-3600) // 1 hour ago
        
        let pastFormatted = past.relativeFormatted()
        
        #expect(pastFormatted.isEmpty == false)
        #expect(pastFormatted.count > 2) // Basic length check
    }
    
    // MARK: - ValidationResult Tests
    
    @Test func testValidationResultSuccess() async throws {
        let result = ValidationResult.success
        
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testValidationResultFailure() async throws {
        let errorMessage = "Test error message"
        let result = ValidationResult.failure(errorMessage)
        
        #expect(result.isValid == false)
        #expect(result.errorMessage == errorMessage)
    }
}
