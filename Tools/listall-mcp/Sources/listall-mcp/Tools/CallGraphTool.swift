import Foundation
import MCP
import IndexStoreWrapper

// MARK: - Call Graph Tool

/// MCP tool for querying Swift call graphs via Xcode's index store.
/// Provides incoming callers and outgoing callees for any function.
enum CallGraphTool {
    // MARK: - Tool Definitions

    static var callGraphTool: Tool {
        Tool(
            name: "listall_call_graph",
            description: """
                Query the Swift call graph for a function. Returns who calls this function \
                (incoming callers) and what this function calls (outgoing callees).

                Requires the project to have been built in Xcode (to populate the index store).

                Input: A symbol name (function/method name) and optionally a file path to disambiguate.
                Output: List of incoming callers and outgoing callees with file paths and line numbers.

                Examples:
                - symbol: "addList(name:)" → finds all callers and callees of addList
                - symbol: "updateItem(_:)", file: "DataRepository.swift" → scoped to specific file
                - symbol: "viewDidLoad()" → finds callers/callees of viewDidLoad

                The symbol name should match Swift's indexed name format (e.g., "methodName(param1:param2:)").
                For simple names without parameters, just use the name (e.g., "listCreated").
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "symbol": .object([
                        "type": .string("string"),
                        "description": .string("The function/method name to look up (e.g., 'addList(name:)', 'updateItem(_:)')")
                    ]),
                    "file": .object([
                        "type": .string("string"),
                        "description": .string("Optional: file name to disambiguate (e.g., 'MainViewModel.swift'). If omitted, searches all files.")
                    ]),
                    "direction": .object([
                        "type": .string("string"),
                        "description": .string("Optional: 'incoming' for callers only, 'outgoing' for callees only, 'both' for both (default: 'both')")
                    ])
                ]),
                "required": .array([.string("symbol")])
            ])
        )
    }

    // MARK: - Tool Collection

    static var allTools: [Tool] {
        [callGraphTool]
    }

    static func isCallGraphTool(_ name: String) -> Bool {
        allTools.contains { $0.name == name }
    }

    // MARK: - Tool Handler

    static func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        switch name {
        case "listall_call_graph":
            return try await handleCallGraph(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown call graph tool: \(name)")
        }
    }

    // MARK: - Call Graph Handler

    private static func handleCallGraph(arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let args = arguments,
              case .string(let symbol) = args["symbol"] else {
            throw MCPError.invalidParams("Missing required parameter: symbol")
        }

        let fileFilter: String?
        if case .string(let f) = args["file"] {
            fileFilter = f
        } else {
            fileFilter = nil
        }

        let direction: String
        if case .string(let d) = args["direction"] {
            direction = d
        } else {
            direction = "both"
        }

        log("listall_call_graph: symbol='\(symbol)' file=\(fileFilter ?? "all") direction=\(direction)")

        // Find the index store
        guard let storePath = findIndexStorePath() else {
            return CallTool.Result(content: [.text(
                """
                Error: Could not find Xcode index store.

                The call graph tool requires the project to have been built in Xcode.
                Please build the ListAll project in Xcode first, then try again.

                Expected location: ~/Library/Developer/Xcode/DerivedData/ListAll-*/Index.noindex/DataStore/
                """
            )], isError: true)
        }

        let store: IndexStore
        do {
            store = try IndexStore(path: storePath)
        } catch {
            return CallTool.Result(content: [.text(
                "Error: Could not open index store at \(storePath): \(error)"
            )], isError: true)
        }

        var output = ""

        // Find the symbol's definition
        let definitions = findDefinitions(symbol: symbol, fileFilter: fileFilter, store: store)

        if definitions.isEmpty {
            return CallTool.Result(content: [.text(
                """
                No definition found for '\(symbol)'\(fileFilter.map { " in \($0)" } ?? "").

                Tips:
                - Use Swift's indexed name format: "methodName(param1:param2:)"
                - For methods without parameters: "methodName()"
                - For properties: "propertyName"
                - Check spelling and ensure the project has been built in Xcode
                """
            )], isError: true)
        }

        // Use the first definition (deduplicated)
        let def = definitions[0]
        output += "## \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n"
        if let usr = def.usr {
            output += "USR: \(usr)\n"
        }
        output += "\n"

        // Find incoming callers
        if direction == "both" || direction == "incoming" {
            let callers = findIncomingCallers(symbol: symbol, usr: def.usr, store: store)
            output += "### Incoming Callers (\(callers.count))\n\n"
            if callers.isEmpty {
                output += "_No callers found_\n"
            } else {
                // Group by file
                let grouped = Dictionary(grouping: callers, by: { $0.fileName })
                for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                    output += "**\(file)**\n"
                    for call in calls.sorted(by: { $0.line < $1.line }) {
                        output += "- `\(call.callerName)` (line \(call.line))\n"
                    }
                    output += "\n"
                }
            }
        }

        // Find outgoing callees
        if direction == "both" || direction == "outgoing" {
            let callees = findOutgoingCallees(symbol: symbol, usr: def.usr, fileFilter: fileFilter, store: store)
            output += "### Outgoing Callees (\(callees.count))\n\n"
            if callees.isEmpty {
                output += "_No callees found_\n"
            } else {
                for callee in callees {
                    output += "- `\(callee.calleeName)` (line \(callee.line))\n"
                }
                output += "\n"
            }
        }

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Index Store Queries

    private struct SymbolDefinition {
        let symbolName: String
        let fileName: String
        let line: Int
        let usr: String?
    }

    private struct IncomingCaller {
        let callerName: String
        let fileName: String
        let line: Int
    }

    private struct OutgoingCallee {
        let calleeName: String
        let line: Int
    }

    private static func findDefinitions(symbol: String, fileFilter: String?, store: IndexStore) -> [SymbolDefinition] {
        var definitions: [SymbolDefinition] = []
        var seenUSRs: Set<String> = []

        for unit in store.units {
            if let filter = fileFilter {
                guard unit.mainFile.hasSuffix(filter) else { continue }
            }
            guard let recordName = unit.recordName else { continue }

            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.name.contains(symbol),
                      occurrence.roles.contains(.definition) else { return }

                // Deduplicate by USR
                let usr = sym.usr
                guard !seenUSRs.contains(usr) else { return }
                seenUSRs.insert(usr)

                // Skip test helpers - prefer production definitions
                if shortFile.contains("TestHelper") && fileFilter == nil {
                    return
                }

                definitions.append(SymbolDefinition(
                    symbolName: sym.name,
                    fileName: shortFile,
                    line: occurrence.location.line,
                    usr: usr
                ))
            })
        }

        return definitions
    }

    private static func findIncomingCallers(symbol: String, usr: String?, store: IndexStore) -> [IncomingCaller] {
        var callers: [IncomingCaller] = []
        var seen: Set<String> = []

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol

                // Match by USR if available, otherwise by name
                let matches: Bool
                if let usr = usr {
                    matches = sym.usr == usr
                } else {
                    matches = sym.name.contains(symbol)
                }

                guard matches,
                      occurrence.roles.contains(.call) || occurrence.roles.contains(.reference) else { return }

                var callerName: String?
                occurrence.forEach(relation: { relSym, relRoles in
                    if relRoles.contains(.calledBy) || relRoles.contains(.containedBy) {
                        callerName = relSym.name
                    }
                })

                guard let caller = callerName else { return }

                let key = "\(shortFile):\(occurrence.location.line):\(caller)"
                guard !seen.contains(key) else { return }
                seen.insert(key)

                callers.append(IncomingCaller(
                    callerName: caller,
                    fileName: shortFile,
                    line: occurrence.location.line
                ))
            })
        }

        return callers
    }

    private static func findOutgoingCallees(symbol: String, usr: String?, fileFilter: String?, store: IndexStore) -> [OutgoingCallee] {
        var callees: [OutgoingCallee] = []
        var seen: Set<String> = []

        for unit in store.units {
            // For outgoing calls, we need to look in the file where the function is defined
            if let filter = fileFilter {
                guard unit.mainFile.hasSuffix(filter) else { continue }
            }
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }

            reader.forEach(occurrence: { occurrence in
                guard occurrence.roles.contains(.call) else { return }

                occurrence.forEach(relation: { relSym, relRoles in
                    // Match by USR if available, otherwise by name
                    let matches: Bool
                    if let usr = usr {
                        matches = relSym.usr == usr
                    } else {
                        matches = relSym.name.contains(symbol)
                    }

                    guard matches, relRoles.contains(.calledBy) else { return }

                    let calleeName = occurrence.symbol.name
                    let key = "\(calleeName):\(occurrence.location.line)"
                    guard !seen.contains(key) else { return }
                    seen.insert(key)

                    // Skip getters/setters for cleaner output unless they're meaningful
                    if calleeName.hasPrefix("getter:") || calleeName.hasPrefix("setter:") {
                        return
                    }

                    callees.append(OutgoingCallee(
                        calleeName: calleeName,
                        line: occurrence.location.line
                    ))
                })
            })
        }

        return callees.sorted(by: { $0.line < $1.line })
    }

    // MARK: - Index Store Discovery

    private static func findIndexStorePath() -> String? {
        let derivedDataBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(atPath: derivedDataBase.path) else {
            return nil
        }

        for dir in contents where dir.hasPrefix("ListAll-") {
            let candidate = derivedDataBase
                .appendingPathComponent(dir)
                .appendingPathComponent("Index.noindex/DataStore")
            if fm.fileExists(atPath: candidate.appendingPathComponent("v5").path) {
                return candidate.path
            }
        }

        return nil
    }
}
