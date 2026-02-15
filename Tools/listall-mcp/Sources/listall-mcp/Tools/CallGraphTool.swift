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

                Modes:
                - "graph" (default): Full call graph — incoming callers + outgoing callees
                - "callers": Who calls this function (incoming only)
                - "callees": What this function calls (outgoing only)
                - "definition": Find where the symbol is defined (file and line)
                - "references": All usages — calls, references, reads, writes, type refs

                Examples:
                - symbol: "addList(name:)" → full call graph (default mode)
                - symbol: "addList(name:)", mode: "callers" → who calls addList
                - symbol: "DataRepository", mode: "definition" → find where defined
                - symbol: "addList", mode: "references" → all usages across codebase
                - symbol: "save()", file: "ItemViewModel.swift" → scoped to specific file

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
                    "mode": .object([
                        "type": .string("string"),
                        "description": .string("Query mode: 'graph' (default, callers+callees), 'callers', 'callees', 'definition', 'references'")
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

        // Support both "mode" (new) and "direction" (legacy) parameters
        let mode: String
        if case .string(let m) = args["mode"] {
            mode = m
        } else if case .string(let d) = args["direction"] {
            // Legacy mapping
            switch d {
            case "incoming": mode = "callers"
            case "outgoing": mode = "callees"
            default: mode = "graph"
            }
        } else {
            mode = "graph"
        }

        log("listall_call_graph: symbol='\(symbol)' file=\(fileFilter ?? "all") mode=\(mode)")

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

        // Find the symbol's definition
        let definitions = findDefinitions(symbol: symbol, fileFilter: fileFilter, store: store)

        // For references and callers, we can proceed without a definition (name-based search)
        // For definition, callees, and graph, we need a definition anchor
        if definitions.isEmpty && !["references", "callers"].contains(mode) {
            return CallTool.Result(content: [.text(
                """
                No definition found for '\(symbol)'\(fileFilter.map { " in \($0)" } ?? "").

                Tips:
                - Use Swift's indexed name format: "methodName(param1:param2:)"
                - For methods without parameters: "methodName()"
                - For properties: "propertyName"
                - Check spelling and ensure the project has been built in Xcode
                - For framework symbols (SwiftUI, Foundation, etc.), use mode: "references" or "callers"
                """
            )], isError: true)
        }

        switch mode {
        case "definition":
            return handleDefinitionMode(definitions: definitions)
        case "references":
            return handleReferencesMode(symbol: symbol, definitions: definitions, store: store)
        case "callers":
            return handleCallersMode(symbol: symbol, definitions: definitions, store: store)
        case "callees":
            return handleCalleesMode(symbol: symbol, definitions: definitions, fileFilter: fileFilter, store: store)
        case "graph":
            return handleGraphMode(symbol: symbol, definitions: definitions, fileFilter: fileFilter, store: store)
        default:
            throw MCPError.invalidParams("Unknown mode: '\(mode)'. Valid modes: graph, callers, callees, definition, references")
        }
    }

    // MARK: - Mode Handlers

    private static func handleDefinitionMode(definitions: [SymbolDefinition]) -> CallTool.Result {
        var output = "## Symbol: \(definitions[0].symbolName)\n\n"
        for def in definitions {
            output += "- \(def.kind ?? "symbol") in \(def.fileName):\(def.line)\n"
        }
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleCallersMode(symbol: String, definitions: [SymbolDefinition], store: IndexStore) -> CallTool.Result {
        let usr: String?
        var output: String
        if let def = definitions.first {
            usr = def.usr
            output = "## \(def.symbolName)\n"
            output += "Defined in: \(def.fileName):\(def.line)\n\n"
        } else {
            usr = nil
            output = "## Callers of: \(symbol) (name-based search)\n\n"
        }

        let callers = findIncomingCallers(symbol: symbol, usr: usr, store: store)
        output += "### Incoming Callers (\(callers.count))\n\n"
        if callers.isEmpty {
            output += "_No callers found_\n"
        } else {
            let grouped = Dictionary(grouping: callers, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for call in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(call.callerName)` (line \(call.line))\n"
                }
                output += "\n"
            }

            if usr == nil && callers.count >= 100 {
                output += "\n_Results capped at 100. Use a more specific symbol name or add file filter to narrow results._\n"
            }
        }
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleCalleesMode(symbol: String, definitions: [SymbolDefinition], fileFilter: String?, store: IndexStore) -> CallTool.Result {
        let def = definitions[0]
        var output = "## \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n\n"

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
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleGraphMode(symbol: String, definitions: [SymbolDefinition], fileFilter: String?, store: IndexStore) -> CallTool.Result {
        let def = definitions[0]
        var output = "## \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n"
        if let usr = def.usr {
            output += "USR: \(usr)\n"
        }
        output += "\n"

        // Find incoming callers
        let callers = findIncomingCallers(symbol: symbol, usr: def.usr, store: store)
        output += "### Incoming Callers (\(callers.count))\n\n"
        if callers.isEmpty {
            output += "_No callers found_\n"
        } else {
            let grouped = Dictionary(grouping: callers, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for call in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(call.callerName)` (line \(call.line))\n"
                }
                output += "\n"
            }
        }

        // Find outgoing callees
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

        return CallTool.Result(content: [.text(output)])
    }

    private static func handleReferencesMode(symbol: String, definitions: [SymbolDefinition], store: IndexStore) -> CallTool.Result {
        let usr: String?
        var output: String
        if let def = definitions.first {
            usr = def.usr
            output = "## References to: \(def.symbolName)\n"
            output += "Defined in: \(def.fileName):\(def.line)\n\n"
        } else {
            usr = nil
            output = "## References to: \(symbol) (name-based search)\n\n"
        }

        let references = findAllReferences(symbol: symbol, usr: usr, store: store)

        if references.isEmpty {
            output += "_No references found_\n"
        } else {
            output += "Found \(references.count) references across "
            let fileCount = Set(references.map { $0.fileName }).count
            output += "\(fileCount) file\(fileCount == 1 ? "" : "s"):\n\n"

            let grouped = Dictionary(grouping: references, by: { $0.fileName })
            for (file, refs) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for ref in refs.sorted(by: { $0.line < $1.line }) {
                    output += "- Line \(ref.line): \(ref.roleDescription)"
                    if let container = ref.containerName {
                        output += " in \(container)"
                    }
                    output += "\n"
                }
                output += "\n"
            }

            if usr == nil && references.count >= 100 {
                output += "\n_Results capped at 100. Use a more specific symbol name or add file filter to narrow results._\n"
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
        let kind: String?
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

    private struct SymbolReference {
        let fileName: String
        let line: Int
        let roleDescription: String
        let containerName: String?
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

                let kindName = symbolKindName(sym.kind)

                definitions.append(SymbolDefinition(
                    symbolName: sym.name,
                    fileName: shortFile,
                    line: occurrence.location.line,
                    usr: usr,
                    kind: kindName
                ))
            })
        }

        return definitions
    }

    private static func symbolKindName(_ kind: IndexStoreWrapper.SymbolKind) -> String {
        // SymbolKind is a C struct (indexstore_symbol_kind_t), use its description
        return kind.description
    }

    private static func findIncomingCallers(symbol: String, usr: String?, store: IndexStore) -> [IncomingCaller] {
        // When doing name-based search (no USR), try exact match first, then fall back to contains
        let nameMatchers: [(String, String) -> Bool] = [
            { name, sym in name == sym },
            { name, sym in name.contains(sym) }
        ]

        var callers: [IncomingCaller] = []
        var seen: Set<String> = []
        let resultCap = 100

        for passMatcher in (usr != nil ? [nameMatchers[0]] : nameMatchers) {
            callers.removeAll()
            seen.removeAll()

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
                        matches = passMatcher(sym.name, symbol)
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

            // For USR-based search, run once; for name-based, stop if exact match found results
            if usr != nil || !callers.isEmpty {
                break
            }
        }

        // Cap results for name-based searches to prevent massive output
        if usr == nil && callers.count > resultCap {
            return Array(callers.prefix(resultCap))
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

    private static func findAllReferences(symbol: String, usr: String?, store: IndexStore) -> [SymbolReference] {
        // When doing name-based search (no USR), try exact match first, then fall back to contains
        let nameMatchers: [(String, String) -> Bool] = [
            { name, sym in name == sym },
            { name, sym in name.contains(sym) }
        ]

        var references: [SymbolReference] = []
        var seen: Set<String> = []
        let resultCap = 100

        for passMatcher in (usr != nil ? [nameMatchers[0]] : nameMatchers) {
            references.removeAll()
            seen.removeAll()

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
                        matches = passMatcher(sym.name, symbol)
                    }

                    guard matches else { return }

                    // Skip pure definitions — we already show the definition location
                    if occurrence.roles == .definition {
                        return
                    }

                    // Skip if no meaningful role
                    let roles = occurrence.roles
                    guard !roles.isEmpty else { return }

                    let key = "\(shortFile):\(occurrence.location.line):\(roleDescription(roles))"
                    guard !seen.contains(key) else { return }
                    seen.insert(key)

                    // Find containing function/type
                    var containerName: String?
                    occurrence.forEach(relation: { relSym, relRoles in
                        if relRoles.contains(.calledBy) || relRoles.contains(.containedBy) {
                            containerName = relSym.name
                        }
                    })

                    references.append(SymbolReference(
                        fileName: shortFile,
                        line: occurrence.location.line,
                        roleDescription: roleDescription(roles),
                        containerName: containerName
                    ))
                })
            }

            // For USR-based search, run once; for name-based, stop if exact match found results
            if usr != nil || !references.isEmpty {
                break
            }
        }

        // Cap results for name-based searches to prevent massive output
        if usr == nil && references.count > resultCap {
            return Array(references.prefix(resultCap))
        }

        return references
    }

    private static func roleDescription(_ roles: SymbolRoles) -> String {
        var parts: [String] = []
        if roles.contains(.call) { parts.append("call") }
        if roles.contains(.reference) && !roles.contains(.call) { parts.append("reference") }
        if roles.contains(.read) { parts.append("read") }
        if roles.contains(.write) { parts.append("write") }
        if roles.contains(.definition) { parts.append("definition") }
        if roles.contains(.declaration) { parts.append("declaration") }
        if parts.isEmpty { return "usage" }
        return parts.joined(separator: "+")
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
