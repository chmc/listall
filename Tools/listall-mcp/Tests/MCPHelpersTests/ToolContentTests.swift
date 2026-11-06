import Testing
import Foundation
import MCP
@testable import MCPHelpers

@Suite("Tool Content Helpers")
struct ToolContentTests {
    @Test func plainTextHasNoAnnotationsOrMeta() {
        #expect(Tool.Content.plainText("hello") == .text(text: "hello", annotations: nil, _meta: nil))
    }

    @Test func plainTextEncodesOnlyTypeAndText() throws {
        let data = try JSONEncoder().encode(Tool.Content.plainText("hello"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["type", "text"])
        #expect(object["text"] as? String == "hello")
    }
}
