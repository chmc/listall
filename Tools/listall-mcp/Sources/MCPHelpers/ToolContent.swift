import MCP

extension Tool.Content {
    /// Plain text content without annotations or metadata
    public static func plainText(_ text: String) -> Self {
        .text(text: text, annotations: nil, _meta: nil)
    }
}
