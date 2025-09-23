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
    
    func testAttributedStringCreation() {
        let text = "Visit https://www.apple.com for more info"
        let attributedString = URLHelper.createAttributedString(
            from: text,
            font: UIFont.systemFont(ofSize: 16),
            textColor: .label,
            linkColor: .systemBlue
        )
        
        XCTAssertEqual(attributedString.length, text.count)
        XCTAssertTrue(attributedString.string == text)
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