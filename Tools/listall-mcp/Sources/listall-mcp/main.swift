import Foundation
import MCP

// MARK: - Logging

/// Logging utilities
enum Logger {
    /// Log to stderr (stdout is reserved for MCP protocol communication)
    static func log(_ message: String) {
        guard let data = "[\(Date())] \(message)\n".data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}

/// Convenience function for logging
func log(_ message: String) {
    Logger.log(message)
}

// MARK: - Main Entry Point

@main
struct ListAllMCP {
    static func main() async throws {
        log("listall-mcp starting...")

        // Create server with tool capabilities
        let server = Server(
            name: "listall-mcp",
            version: "0.5.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        // Define the echo tool with JSON Schema format
        let echoTool = Tool(
            name: "listall_echo",
            description: "Echo back any input text. Use this tool to verify MCP communication is working.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "message": .object([
                        "type": .string("string"),
                        "description": .string("The message to echo back")
                    ])
                ]),
                "required": .array([.string("message")])
            ])
        )

        // Collect all tools
        let allTools: [Tool] = [echoTool] + SimulatorTools.allTools + MacOSTools.allTools + InteractionTools.allTools + DiagnosticsTool.allTools + CallGraphTool.allTools

        // Register tool listing handler
        await server.withMethodHandler(ListTools.self) { _ in
            log("ListTools called - returning \(allTools.count) tools")
            return ListTools.Result(tools: allTools)
        }

        // Register tool call handler
        await server.withMethodHandler(CallTool.self) { params in
            log("CallTool called: \(params.name)")

            // Handle simulator tools
            if SimulatorTools.isSimulatorTool(params.name) {
                return try await SimulatorTools.handleToolCall(name: params.name, arguments: params.arguments)
            }

            // Handle macOS tools
            if MacOSTools.isMacOSTool(params.name) {
                return try await MacOSTools.handleToolCall(name: params.name, arguments: params.arguments)
            }

            // Handle interaction tools (click, type, swipe, query)
            if InteractionTools.isInteractionTool(params.name) {
                return try await InteractionTools.handleToolCall(name: params.name, arguments: params.arguments)
            }

            // Handle diagnostic tools
            if DiagnosticsTool.isDiagnosticTool(params.name) {
                return try await DiagnosticsTool.handleToolCall(name: params.name, arguments: params.arguments)
            }

            // Handle call graph tools
            if CallGraphTool.isCallGraphTool(params.name) {
                return try await CallGraphTool.handleToolCall(name: params.name, arguments: params.arguments)
            }

            // Handle echo tool
            guard params.name == echoTool.name else {
                log("Unknown tool: \(params.name)")
                throw MCPError.invalidParams("Unknown tool: \(params.name)")
            }

            // Extract message from arguments (required parameter)
            guard let args = params.arguments,
                  case .string(let message) = args["message"] else {
                log("Missing required parameter: message")
                throw MCPError.invalidParams("Missing required parameter: message")
            }

            log("Echo message: \(message)")

            return CallTool.Result(content: [
                .text("Echo from listall-mcp: \(message)")
            ])
        }

        // Start server with stdio transport
        let transport = StdioTransport()
        log("Starting server with stdio transport...")

        try await server.start(transport: transport)
        log("Server started, waiting for requests...")

        await server.waitUntilCompleted()
        log("Server completed")
    }
}
