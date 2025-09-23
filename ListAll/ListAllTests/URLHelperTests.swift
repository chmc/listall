import XCTest
@testable import ListAll
import Foundation

final class URLHelperTests: XCTestCase {
    
    func testBasicHTTPURLDetection() {
        let text = "Visit https://www.apple.com for more info"
        let urls = URLHelper.detectURLs(in: text)
        
        XCTAssertGreaterThanOrEqual(urls.count, 1, "Should detect at least one URL")
        XCTAssertTrue(urls.contains(where: { $0.absoluteString.contains("apple.com") }), "Should contain apple.com URL")
    }
    
    func testMultipleURLDetection() {
        let text = "Check out https://www.apple.com and also http://google.com for more info"
        let urls = URLHelper.detectURLs(in: text)
        
        XCTAssertGreaterThanOrEqual(urls.count, 2, "Should detect at least 2 URLs")
        XCTAssertTrue(urls.contains(where: { $0.absoluteString.contains("apple.com") }))
        XCTAssertTrue(urls.contains(where: { $0.absoluteString.contains("google.com") }))
    }
    
    func testContainsURLTrue() {
        let texts = [
            "Visit https://www.apple.com",
            "Check http://google.com",
            "Go to smanni.fi/test-page"
        ]
        
        for text in texts {
            XCTAssertTrue(URLHelper.containsURL(text), "Should detect URL in: \(text)")
        }
    }
    
    func testContainsURLFalse() {
        let texts = [
            "Plain text without URLs",
            "No links here at all",
            "Just some regular words"
        ]
        
        for text in texts {
            XCTAssertFalse(URLHelper.containsURL(text), "Should not detect URL in: \(text)")
        }
    }
    
    func testParseTextComponents() {
        let text = "Visit https://www.apple.com for more info"
        let components = URLHelper.parseTextComponents(from: text)
        
        XCTAssertGreaterThanOrEqual(components.count, 2, "Should have at least 2 components (text + URL)")
        
        let urlComponents = components.filter { $0.isURL }
        XCTAssertGreaterThanOrEqual(urlComponents.count, 1, "Should have at least 1 URL component")
        
        let textComponents = components.filter { !$0.isURL }
        XCTAssertGreaterThanOrEqual(textComponents.count, 1, "Should have at least 1 text component")
    }
    
    func testParseTextComponentsWithMixedContent() {
        let text = "Maku puuro https://www.tokmanni.fi/annosikapuuro-elovena-420-g-hetki-vadelma-vahemm-641120010915O"
        let components = URLHelper.parseTextComponents(from: text)
        
        XCTAssertEqual(components.count, 2, "Should have exactly 2 components")
        
        // First component should be normal text
        let firstComponent = components[0]
        XCTAssertFalse(firstComponent.isURL, "First component should not be a URL")
        XCTAssertEqual(firstComponent.text, "Maku puuro ", "First component should be normal text")
        
        // Second component should be the URL
        let secondComponent = components[1]
        XCTAssertTrue(secondComponent.isURL, "Second component should be a URL")
        XCTAssertNotNil(secondComponent.url, "Second component should have a URL")
        XCTAssertTrue(secondComponent.text.contains("tokmanni.fi"), "Second component should contain the URL")
    }
    
    func testParseTextComponentsPlainText() {
        let text = "Just plain text without any URLs"
        let components = URLHelper.parseTextComponents(from: text)
        
        XCTAssertEqual(components.count, 1, "Should have exactly 1 component for plain text")
        XCTAssertFalse(components[0].isURL, "Component should not be a URL")
        XCTAssertEqual(components[0].text, text, "Component text should match input")
    }
    
    func testOpenURL() {
        let testURL = URL(string: "https://www.apple.com")!
        
        // This test just verifies the method doesn't crash
        // In a real app, this would open the URL in Safari
        URLHelper.openURL(testURL)
        
        // Test passes if no exception is thrown
        XCTAssertTrue(true)
    }
    
    func testEdgeCases() {
        // Empty string
        XCTAssertTrue(URLHelper.detectURLs(in: "").isEmpty, "Empty string should not contain URLs")
        XCTAssertFalse(URLHelper.containsURL(""), "Empty string should not contain URLs")
        
        // Single character
        XCTAssertTrue(URLHelper.detectURLs(in: "a").isEmpty, "Single char should not contain URLs")
        XCTAssertFalse(URLHelper.containsURL("a"), "Single char should not contain URLs")
    }
    
    func testStringURLExtension() {
        let validURLs = [
            "https://www.apple.com",
            "http://google.com",
            "www.example.com"
        ]
        
        for urlString in validURLs {
            XCTAssertNotNil(urlString.asURL, "Should create URL from: \(urlString)")
        }
        
        let invalidURLs = [
            "",
            "not a url",
            "just plain text"
        ]
        
        for urlString in invalidURLs {
            XCTAssertNil(urlString.asURL, "Should not create URL from: \(urlString)")
        }
    }
    
    func testRealWorldURL() {
        // Test with the actual URL from the user's screenshot
        let text = "smanni.fi/annosopikapuuro-elovena-420-g-hetki-vadelma-vahem"
        let urls = URLHelper.detectURLs(in: text)
        
        XCTAssertGreaterThanOrEqual(urls.count, 1, "Should detect URL in real-world example")
        XCTAssertTrue(URLHelper.containsURL(text), "Should recognize real-world URL")
    }
}