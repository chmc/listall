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
                - "hierarchy": Type hierarchy — conformances, inheritance, extensions, overrides
                - "members": List all members of a type (properties, methods, nested types, etc.), including extension members
                - "search": Case-insensitive substring discovery — find symbols when you don't know the exact name. \
                In this mode, `symbol` is treated as a search query, not an exact name.
                - "dump": Raw IndexStore data for a symbol — shows all occurrences with roles, \
                relations, kind/subkind, and USRs. Useful for debugging index issues. Capped at 50 occurrences.

                Parameters:
                - symbol (required): The function/method/type name to look up
                - file (optional): File name to disambiguate
                - mode (optional): Query mode (default: "graph")
                - include_source (optional): Include 3-line source snippets around each result (default: false). \
                Increases output ~4x — use sparingly.

                Examples:
                - symbol: "addList(name:)" → full call graph (default mode)
                - symbol: "addList(name:)", mode: "callers" → who calls addList
                - symbol: "DataRepository", mode: "definition" → find where defined
                - symbol: "addList", mode: "references" → all usages across codebase
                - symbol: "save()", file: "ItemViewModel.swift" → scoped to specific file
                - symbol: "reorderLists(from:to:)", mode: "dump" → raw index data with all USRs
                - symbol: "addList(name:)", mode: "callers", include_source: true → callers with source context
                - symbol: "DataRepository", mode: "hierarchy" → type hierarchy
                - symbol: "Item", mode: "members" → list all properties, methods, nested types
                - symbol: "cross", mode: "search" → find symbols containing "cross" (case-insensitive)

                The symbol name should match Swift's indexed name format (e.g., "methodName(param1:param2:)").
                For simple names without parameters, just use the name (e.g., "listCreated").

                Known limitations:
                - SwiftUI view modifiers may not appear as calls in IndexStore
                - Index staleness warning is heuristic (may have false negatives with incremental indexing)
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
                        "description": .string("Query mode: 'graph' (default, callers+callees), 'callers', 'callees', 'definition', 'references', 'hierarchy', 'members', 'search', 'dump'")
                    ]),
                    "include_source": .object([
                        "type": .string("boolean"),
                        "description": .string("Include 3-line source snippets around each result (default: false). Increases output significantly.")
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

        let includeSource: Bool
        if case .bool(let b) = args["include_source"] {
            includeSource = b
        } else {
            includeSource = false
        }

        log("listall_call_graph: symbol='\(symbol)' file=\(fileFilter ?? "all") mode=\(mode) include_source=\(includeSource)")

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

        // Dump mode doesn't need definitions — it does its own raw scan
        if mode == "dump" {
            return handleDumpMode(symbol: symbol, fileFilter: fileFilter, store: store)
        }

        // Search mode bypasses findDefinitions — does its own case-insensitive scan
        if mode == "search" {
            return handleSearchMode(query: symbol, store: store)
        }

        // Find the symbol's definition (returns all USRs across targets)
        let (definitions, allUSRs) = findDefinitions(symbol: symbol, fileFilter: fileFilter, store: store)

        // For references, callers, and hierarchy, we can proceed without a definition (name-based search)
        // For definition, callees, and graph, we need a definition anchor
        if definitions.isEmpty && !["references", "callers", "hierarchy"].contains(mode) {
            let suggestions = findSuggestions(query: symbol, store: store)
            var message = """
                No definition found for '\(symbol)'\(fileFilter.map { " in \($0)" } ?? "").

                Tips:
                - Use Swift's indexed name format: "methodName(param1:param2:)"
                - For methods without parameters: "methodName()"
                - For properties: "propertyName"
                - Check spelling and ensure the project has been built in Xcode
                - For framework symbols (SwiftUI, Foundation, etc.), use mode: "references" or "callers"
                - Use mode: "search" for case-insensitive substring discovery
                """
            if !suggestions.isEmpty {
                message += "\n\nDid you mean:\n"
                for s in suggestions {
                    message += "- `\(s.name)` (\(s.kind), \(s.fileName):\(s.line))\n"
                }
            }
            return CallTool.Result(content: [.text(message)], isError: true)
        }

        // Query-local snippet cache (not static — MCP server is long-running)
        var snippetCache: [String: [String]] = [:]

        // Collect source file paths from results for staleness check
        var sourceFilePaths: Set<String> = []
        for def in definitions {
            sourceFilePaths.insert(def.fullPath)
        }

        let result: CallTool.Result
        switch mode {
        case "definition":
            result = handleDefinitionMode(definitions: definitions, includeSource: includeSource, snippetCache: &snippetCache)
        case "references":
            let r = handleReferencesMode(symbol: symbol, definitions: definitions, usrs: allUSRs, store: store, includeSource: includeSource, snippetCache: &snippetCache)
            result = r
        case "callers":
            let r = handleCallersMode(symbol: symbol, definitions: definitions, usrs: allUSRs, store: store, includeSource: includeSource, snippetCache: &snippetCache)
            result = r
        case "callees":
            let r = handleCalleesMode(symbol: symbol, definitions: definitions, usrs: allUSRs, fileFilter: fileFilter, store: store, includeSource: includeSource, snippetCache: &snippetCache)
            result = r
        case "graph":
            let r = handleGraphMode(symbol: symbol, definitions: definitions, usrs: allUSRs, fileFilter: fileFilter, store: store, includeSource: includeSource, snippetCache: &snippetCache)
            result = r
        case "hierarchy":
            result = handleHierarchyMode(symbol: symbol, definitions: definitions, usrs: allUSRs, store: store)
        case "members":
            result = handleMembersMode(symbol: symbol, definitions: definitions, usrs: allUSRs, store: store, includeSource: includeSource, snippetCache: &snippetCache)
        default:
            throw MCPError.invalidParams("Unknown mode: '\(mode)'. Valid modes: graph, callers, callees, definition, references, hierarchy, members, search, dump")
        }

        // Append stale index warning if needed
        let warning = checkIndexStaleness(store: store, sourceFilePaths: sourceFilePaths)
        if let warning = warning, case .text(let text) = result.content.first {
            return CallTool.Result(content: [.text(text + "\n" + warning)], isError: result.isError)
        }

        return result
    }

    // MARK: - Mode Handlers

    private static func handleDefinitionMode(definitions: [SymbolDefinition], includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        var output = "## Symbol: \(definitions[0].symbolName)\n\n"
        for def in definitions {
            output += "- \(def.kind ?? "symbol") in \(def.fileName):\(def.line)"
            output += " (\(def.fullPath))\n"
            if includeSource {
                output += formatSnippet(fullPath: def.fullPath, line: def.line, cache: &snippetCache)
            }
        }
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleCallersMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, store: IndexStore, includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        var output: String
        if let def = definitions.first {
            output = "## \(def.symbolName)\n"
            output += "Defined in: \(def.fileName):\(def.line)\n"
            if usrs.count > 1 {
                output += "USRs: \(usrs.count) (multi-target symbol)\n"
            }
            output += "\n"
        } else {
            output = "## Callers of: \(symbol) (name-based search)\n\n"
        }

        let callers = findIncomingCallers(symbol: symbol, usrs: usrs, store: store)
        output += "### Incoming Callers (\(callers.count))\n\n"
        if callers.isEmpty {
            output += "_No callers found_\n"
        } else {
            let grouped = Dictionary(grouping: callers, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for call in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(call.callerName)` (line \(call.line))\n"
                    if includeSource {
                        output += formatSnippet(fullPath: call.fullPath, line: call.line, cache: &snippetCache)
                    }
                }
                output += "\n"
            }

            if usrs.isEmpty && callers.count >= 100 {
                output += "\n_Results capped at 100. Use a more specific symbol name or add file filter to narrow results._\n"
            }
        }
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleCalleesMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, fileFilter: String?, store: IndexStore, includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        let def = definitions[0]
        var output = "## \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n\n"

        let callees = findOutgoingCallees(symbol: symbol, usrs: usrs, fileFilter: fileFilter, store: store)
        output += "### Outgoing Callees (\(callees.count))\n\n"
        if callees.isEmpty {
            output += "_No callees found_\n"
        } else {
            let grouped = Dictionary(grouping: callees, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for callee in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(callee.calleeName)` (line \(callee.line))\n"
                    if includeSource {
                        output += formatSnippet(fullPath: callee.fullPath, line: callee.line, cache: &snippetCache)
                    }
                }
                output += "\n"
            }
        }
        return CallTool.Result(content: [.text(output)])
    }

    private static func handleGraphMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, fileFilter: String?, store: IndexStore, includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        let def = definitions[0]
        var output = "## \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n"
        if usrs.count > 1 {
            output += "USRs: \(usrs.count) (multi-target symbol)\n"
        } else if let usr = def.usr {
            output += "USR: \(usr)\n"
        }
        output += "\n"

        // Find incoming callers
        let callers = findIncomingCallers(symbol: symbol, usrs: usrs, store: store)
        output += "### Incoming Callers (\(callers.count))\n\n"
        if callers.isEmpty {
            output += "_No callers found_\n"
        } else {
            let grouped = Dictionary(grouping: callers, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for call in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(call.callerName)` (line \(call.line))\n"
                    if includeSource {
                        output += formatSnippet(fullPath: call.fullPath, line: call.line, cache: &snippetCache)
                    }
                }
                output += "\n"
            }
        }

        // Find outgoing callees
        let callees = findOutgoingCallees(symbol: symbol, usrs: usrs, fileFilter: fileFilter, store: store)
        output += "### Outgoing Callees (\(callees.count))\n\n"
        if callees.isEmpty {
            output += "_No callees found_\n"
        } else {
            let grouped = Dictionary(grouping: callees, by: { $0.fileName })
            for (file, calls) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "**\(file)**\n"
                for callee in calls.sorted(by: { $0.line < $1.line }) {
                    output += "- `\(callee.calleeName)` (line \(callee.line))\n"
                    if includeSource {
                        output += formatSnippet(fullPath: callee.fullPath, line: callee.line, cache: &snippetCache)
                    }
                }
                output += "\n"
            }
        }

        return CallTool.Result(content: [.text(output)])
    }

    private static func handleReferencesMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, store: IndexStore, includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        var output: String
        if let def = definitions.first {
            output = "## References to: \(def.symbolName)\n"
            output += "Defined in: \(def.fileName):\(def.line)\n"
            if usrs.count > 1 {
                output += "USRs: \(usrs.count) (multi-target symbol)\n"
            }
            output += "\n"
        } else {
            output = "## References to: \(symbol) (name-based search)\n\n"
        }

        let references = findAllReferences(symbol: symbol, usrs: usrs, store: store)

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
                    if includeSource {
                        output += formatSnippet(fullPath: ref.fullPath, line: ref.line, cache: &snippetCache)
                    }
                }
                output += "\n"
            }

            if usrs.isEmpty && references.count >= 100 {
                output += "\n_Results capped at 100. Use a more specific symbol name or add file filter to narrow results._\n"
            }
        }

        return CallTool.Result(content: [.text(output)])
    }

    private static func handleDumpMode(symbol: String, fileFilter: String?, store: IndexStore) -> CallTool.Result {
        var output = "## Raw Index Data for: \(symbol)\n\n"
        var occurrenceCount = 0
        let cap = 50

        for unit in store.units {
            if let filter = fileFilter {
                guard unit.mainFile.hasSuffix(filter) else { continue }
            }
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
            let fullFile = unit.mainFile

            reader.forEach(occurrence: { occurrence in
                guard occurrenceCount < cap else { return }
                let sym = occurrence.symbol
                guard sym.name.contains(symbol) else { return }

                occurrenceCount += 1
                let loc = occurrence.location
                output += "### Occurrence \(occurrenceCount)\n"
                output += "- **Symbol:** `\(sym.name)`\n"
                output += "- **USR:** `\(sym.usr)`\n"
                output += "- **Kind:** \(sym.kind.description)"
                if sym.subkind.description != "none" {
                    output += " / \(sym.subkind.description)"
                }
                output += "\n"
                output += "- **File:** \(shortFile):\(loc.line):\(loc.column)"
                output += " (\(fullFile))\n"
                output += "- **Roles:** \(occurrence.roles.description)\n"

                var relations: [(String, String, String)] = []
                occurrence.forEach(relation: { relSym, relRoles in
                    relations.append((relSym.name, relSym.usr, relRoles.description))
                })
                if !relations.isEmpty {
                    output += "- **Relations:**\n"
                    for (name, usr, roles) in relations {
                        output += "  - `\(name)` (USR: `\(usr)`) — \(roles)\n"
                    }
                }
                output += "\n"
            })

            if occurrenceCount >= cap { break }
        }

        if occurrenceCount == 0 {
            output += "_No occurrences found for '\(symbol)'_\n"
        } else {
            output += "---\nTotal: \(occurrenceCount) occurrence(s)"
            if occurrenceCount >= cap {
                output += " (capped at \(cap))"
            }
            output += "\n"
        }

        return CallTool.Result(content: [.text(output)])
    }

    private static func handleHierarchyMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, store: IndexStore) -> CallTool.Result {
        var output: String
        if let def = definitions.first {
            output = "## Type Hierarchy: \(def.symbolName)\n"
            output += "Defined in: \(def.fileName):\(def.line)\n\n"
        } else {
            output = "## Type Hierarchy: \(symbol) (name-based search)\n\n"
        }

        // Collect hierarchy relations by scanning all occurrences
        var conformsTo: [(name: String, fileName: String, line: Int)] = []
        var inheritedBy: [(name: String, fileName: String, line: Int)] = []
        var extendedBy: [(name: String, fileName: String, line: Int)] = []
        var overrides: [(name: String, fileName: String, line: Int)] = []
        var overriddenBy: [(name: String, fileName: String, line: Int)] = []
        var seenKeys: Set<String> = []

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol

                // Check if this occurrence IS the target symbol
                let isTarget = !usrs.isEmpty ? usrs.contains(sym.usr) : sym.name.contains(symbol)

                if isTarget {
                    // Look at relations FROM this symbol
                    occurrence.forEach(relation: { relSym, relRoles in
                        if relRoles.contains(.baseOf) {
                            let key = "conformsTo:\(relSym.name):\(shortFile):\(occurrence.location.line)"
                            if !seenKeys.contains(key) {
                                seenKeys.insert(key)
                                conformsTo.append((relSym.name, shortFile, occurrence.location.line))
                            }
                        }
                        if relRoles.contains(.overrideOf) {
                            let key = "overrides:\(relSym.name):\(shortFile):\(occurrence.location.line)"
                            if !seenKeys.contains(key) {
                                seenKeys.insert(key)
                                overrides.append((relSym.name, shortFile, occurrence.location.line))
                            }
                        }
                    })
                }

                // Also check relations that POINT TO the target symbol
                occurrence.forEach(relation: { relSym, relRoles in
                    let relIsTarget = !usrs.isEmpty ? usrs.contains(relSym.usr) : relSym.name.contains(symbol)
                    guard relIsTarget else { return }

                    if relRoles.contains(.baseOf) {
                        // sym conforms to / inherits from relSym (the target)
                        let key = "inheritedBy:\(sym.name):\(shortFile):\(occurrence.location.line)"
                        if !seenKeys.contains(key) {
                            seenKeys.insert(key)
                            inheritedBy.append((sym.name, shortFile, occurrence.location.line))
                        }
                    }
                    if relRoles.contains(.extendedBy) {
                        let key = "extendedBy:\(sym.name):\(shortFile):\(occurrence.location.line)"
                        if !seenKeys.contains(key) {
                            seenKeys.insert(key)
                            extendedBy.append((sym.name, shortFile, occurrence.location.line))
                        }
                    }
                    if relRoles.contains(.overrideOf) {
                        // sym overrides relSym (the target)
                        let key = "overriddenBy:\(sym.name):\(shortFile):\(occurrence.location.line)"
                        if !seenKeys.contains(key) {
                            seenKeys.insert(key)
                            overriddenBy.append((sym.name, shortFile, occurrence.location.line))
                        }
                    }
                })
            })
        }

        let hasData = !conformsTo.isEmpty || !inheritedBy.isEmpty || !extendedBy.isEmpty || !overrides.isEmpty || !overriddenBy.isEmpty

        if !hasData {
            output += "_No type hierarchy data found._\n\n"
            output += "This may mean:\n"
            output += "- The symbol has no conformances, inheritance, or extensions in the index\n"
            output += "- Use mode: \"dump\" to inspect raw index data for this symbol\n"
        } else {
            if !conformsTo.isEmpty {
                output += "### Conforms To / Inherits From (\(conformsTo.count))\n\n"
                for item in conformsTo.sorted(by: { $0.name < $1.name }) {
                    output += "- `\(item.name)` (\(item.fileName):\(item.line))\n"
                }
                output += "\n"
            }

            if !inheritedBy.isEmpty {
                output += "### Inherited By / Conformed By (\(inheritedBy.count))\n\n"
                for item in inheritedBy.sorted(by: { $0.name < $1.name }) {
                    output += "- `\(item.name)` (\(item.fileName):\(item.line))\n"
                }
                output += "\n"
            }

            if !extendedBy.isEmpty {
                output += "### Extended By (\(extendedBy.count))\n\n"
                for item in extendedBy.sorted(by: { $0.name < $1.name }) {
                    output += "- `\(item.name)` (\(item.fileName):\(item.line))\n"
                }
                output += "\n"
            }

            if !overrides.isEmpty {
                output += "### Overrides (\(overrides.count))\n\n"
                for item in overrides.sorted(by: { $0.name < $1.name }) {
                    output += "- `\(item.name)` (\(item.fileName):\(item.line))\n"
                }
                output += "\n"
            }

            if !overriddenBy.isEmpty {
                output += "### Overridden By (\(overriddenBy.count))\n\n"
                for item in overriddenBy.sorted(by: { $0.name < $1.name }) {
                    output += "- `\(item.name)` (\(item.fileName):\(item.line))\n"
                }
                output += "\n"
            }
        }

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Search Mode

    private static func handleSearchMode(query: String, store: IndexStore) -> CallTool.Result {
        struct SearchResult: Hashable {
            let name: String
            let kind: String
            let fileName: String
            let line: Int

            func hash(into hasher: inout Hasher) {
                hasher.combine(name)
                hasher.combine(fileName)
            }
            static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
                lhs.name == rhs.name && lhs.fileName == rhs.fileName
            }
        }

        let queryLower = query.lowercased()
        var results: Set<SearchResult> = []
        let accessorSubkinds: Set<String> = [
            "accessorGetter", "accessorSetter",
            "swiftAccessorWillSet", "swiftAccessorDidSet",
            "swiftAccessorAddressor", "swiftAccessorMutableAddressor",
            "swiftAccessorRead", "swiftAccessorModify",
            "swiftAccessorInit", "swiftAccessorBorrow", "swiftAccessorMutate"
        ]
        let filteredKinds: Set<String> = ["parameter", "commentTag"]

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            // Filter out test files
            if shortFile.hasSuffix("Tests.swift") || shortFile.hasSuffix("Test.swift") || shortFile.contains("TestHelper") {
                continue
            }

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard occurrence.roles.contains(.definition) else { return }
                guard sym.name.lowercased().contains(queryLower) else { return }

                let kindName = sym.kind.description
                let subkindName = sym.subkind.description

                // Filter out accessors and parameters
                guard !accessorSubkinds.contains(subkindName) else { return }
                guard !filteredKinds.contains(kindName) else { return }

                // Filter out accessor relations
                var isAccessor = false
                occurrence.forEach(relation: { _, relRoles in
                    if relRoles.contains(.accessorOf) { isAccessor = true }
                })
                guard !isAccessor else { return }

                results.insert(SearchResult(
                    name: sym.name,
                    kind: kindName,
                    fileName: shortFile,
                    line: occurrence.location.line
                ))
            })
        }

        if results.isEmpty {
            return CallTool.Result(content: [.text(
                "No symbols found matching '\(query)'.\n\nTry a shorter or different substring."
            )])
        }

        // Sort: types first, then methods, then properties; within each group by relevance
        let typeKinds: Set<String> = ["struct", "class", "enum", "protocol", "typealias", "extension"]
        let methodKinds: Set<String> = ["instanceMethod", "classMethod", "staticMethod", "function", "constructor"]

        func relevanceScore(_ name: String) -> Int {
            let nameLower = name.lowercased()
            if nameLower == queryLower { return 0 }
            if nameLower.hasPrefix(queryLower) { return 1 }
            return 2
        }

        func groupOrder(_ kind: String) -> Int {
            if typeKinds.contains(kind) { return 0 }
            if methodKinds.contains(kind) { return 1 }
            return 2
        }

        let sorted = results.sorted { a, b in
            let ga = groupOrder(a.kind)
            let gb = groupOrder(b.kind)
            if ga != gb { return ga < gb }
            let ra = relevanceScore(a.name)
            let rb = relevanceScore(b.name)
            if ra != rb { return ra < rb }
            return a.name < b.name
        }

        let capped = Array(sorted.prefix(50))

        var output = "## Search results for: '\(query)' (\(results.count) found"
        if results.count > 50 { output += ", showing first 50" }
        output += ")\n\n"

        // Group by kind category for display
        var currentGroup = -1
        let groupNames = ["Types", "Methods", "Properties & Other"]
        for item in capped {
            let group = groupOrder(item.kind)
            if group != currentGroup {
                currentGroup = group
                output += "### \(groupNames[group])\n\n"
            }
            output += "- `\(item.name)` (\(item.kind), \(item.fileName):\(item.line))\n"
        }

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Members Mode

    private static func handleMembersMode(symbol: String, definitions: [SymbolDefinition], usrs: Set<String>, store: IndexStore, includeSource: Bool, snippetCache: inout [String: [String]]) -> CallTool.Result {
        guard let def = definitions.first else {
            return CallTool.Result(content: [.text(
                "No definition found for '\(symbol)'. The members mode requires a type definition."
            )], isError: true)
        }

        var output = "## Members of: \(def.symbolName)\n"
        output += "Defined in: \(def.fileName):\(def.line)\n\n"

        // Step 1: Collect type USRs (already have them from findDefinitions)
        let typeUSRs = usrs

        // Step 2: Find extension USRs — extensions have extendedBy relation pointing to the type
        var extensionUSRs: Set<String> = []
        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.kind == .extension else { return }
                guard occurrence.roles.contains(.definition) else { return }

                occurrence.forEach(relation: { relSym, relRoles in
                    if relRoles.contains(.extendedBy) && typeUSRs.contains(relSym.usr) {
                        extensionUSRs.insert(sym.usr)
                    }
                })
            })
        }

        let allParentUSRs = typeUSRs.union(extensionUSRs)

        // Step 3: Scan for member definitions with childOf relation
        struct MemberInfo: Hashable {
            let name: String
            let kind: String
            let fileName: String
            let fullPath: String
            let line: Int

            func hash(into hasher: inout Hasher) {
                hasher.combine(name)
                hasher.combine(fileName)
                hasher.combine(line)
            }
            static func == (lhs: MemberInfo, rhs: MemberInfo) -> Bool {
                lhs.name == rhs.name && lhs.fileName == rhs.fileName && lhs.line == rhs.line
            }
        }

        var members: Set<MemberInfo> = []

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
            let fullFile = unit.mainFile

            reader.forEach(occurrence: { occurrence in
                guard occurrence.roles.contains(.definition) else { return }

                var isChildOfTarget = false
                var isAccessor = false
                occurrence.forEach(relation: { relSym, relRoles in
                    if relRoles.contains(.childOf) && allParentUSRs.contains(relSym.usr) {
                        isChildOfTarget = true
                    }
                    if relRoles.contains(.accessorOf) {
                        isAccessor = true
                    }
                })

                guard isChildOfTarget && !isAccessor else { return }

                let sym = occurrence.symbol
                members.insert(MemberInfo(
                    name: sym.name,
                    kind: sym.kind.description,
                    fileName: shortFile,
                    fullPath: fullFile,
                    line: occurrence.location.line
                ))
            })
        }

        if members.isEmpty {
            output += "_No members found_\n"
            return CallTool.Result(content: [.text(output)])
        }

        // Group by kind
        let kindOrder: [String: (Int, String)] = [
            "constructor": (0, "Constructors"),
            "instanceProperty": (1, "Properties"),
            "classProperty": (1, "Properties"),
            "staticProperty": (1, "Properties"),
            "instanceMethod": (2, "Methods"),
            "classMethod": (2, "Methods"),
            "staticMethod": (2, "Methods"),
            "function": (2, "Methods"),
            "enum": (3, "Nested Types"),
            "struct": (3, "Nested Types"),
            "class": (3, "Nested Types"),
            "protocol": (3, "Nested Types"),
            "typealias": (3, "Nested Types"),
            "enumConstant": (4, "Enum Cases"),
        ]

        let sorted = members.sorted { a, b in
            let oa = kindOrder[a.kind]?.0 ?? 5
            let ob = kindOrder[b.kind]?.0 ?? 5
            if oa != ob { return oa < ob }
            return a.name < b.name
        }

        var currentGroup = ""
        for member in sorted {
            let groupName = kindOrder[member.kind]?.1 ?? "Other"
            if groupName != currentGroup {
                currentGroup = groupName
                output += "### \(groupName)\n\n"
            }
            output += "- `\(member.name)` (\(member.kind), \(member.fileName):\(member.line))\n"
            if includeSource {
                output += formatSnippet(fullPath: member.fullPath, line: member.line, cache: &snippetCache)
            }
        }

        if !extensionUSRs.isEmpty {
            output += "\n_Includes members from \(extensionUSRs.count) extension(s)_\n"
        }

        return CallTool.Result(content: [.text(output)])
    }

    // MARK: - Suggestion Helper

    private struct SymbolSuggestion {
        let name: String
        let kind: String
        let fileName: String
        let line: Int
    }

    /// Find up to 10 symbol suggestions for a failed lookup, sorted by relevance.
    private static func findSuggestions(query: String, store: IndexStore) -> [SymbolSuggestion] {
        let queryLower = query.lowercased()
        var seen: Set<String> = []
        var suggestions: [SymbolSuggestion] = []
        let accessorSubkinds: Set<String> = [
            "accessorGetter", "accessorSetter",
            "swiftAccessorWillSet", "swiftAccessorDidSet",
            "swiftAccessorAddressor", "swiftAccessorMutableAddressor",
            "swiftAccessorRead", "swiftAccessorModify",
            "swiftAccessorInit", "swiftAccessorBorrow", "swiftAccessorMutate"
        ]

        for unit in store.units {
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile

            // Skip test files
            if shortFile.hasSuffix("Tests.swift") || shortFile.hasSuffix("Test.swift") || shortFile.contains("TestHelper") {
                continue
            }

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard occurrence.roles.contains(.definition) else { return }
                guard sym.name.lowercased().contains(queryLower) else { return }

                // Filter out accessors and parameters
                let subkindName = sym.subkind.description
                guard !accessorSubkinds.contains(subkindName) else { return }
                guard sym.kind != .parameter && sym.kind != .commentTag else { return }

                let key = "\(sym.name):\(shortFile)"
                guard !seen.contains(key) else { return }
                seen.insert(key)

                suggestions.append(SymbolSuggestion(
                    name: sym.name,
                    kind: sym.kind.description,
                    fileName: shortFile,
                    line: occurrence.location.line
                ))
            })
        }

        // Sort by relevance: exact > prefix > contains; types before methods before properties
        let typeKinds: Set<String> = ["struct", "class", "enum", "protocol", "typealias"]
        return suggestions.sorted { a, b in
            let aLower = a.name.lowercased()
            let bLower = b.name.lowercased()
            let aScore = aLower == queryLower ? 0 : aLower.hasPrefix(queryLower) ? 1 : 2
            let bScore = bLower == queryLower ? 0 : bLower.hasPrefix(queryLower) ? 1 : 2
            if aScore != bScore { return aScore < bScore }
            let aType = typeKinds.contains(a.kind) ? 0 : 1
            let bType = typeKinds.contains(b.kind) ? 0 : 1
            if aType != bType { return aType < bType }
            return a.name < b.name
        }.prefix(10).map { $0 }
    }

    // MARK: - Source Snippets

    /// Extract a 3-line snippet around the target line. Returns formatted markdown or empty string.
    private static func formatSnippet(fullPath: String, line: Int, cache: inout [String: [String]]) -> String {
        guard let lines = readFileLines(fullPath: fullPath, cache: &cache) else { return "" }
        let targetIdx = line - 1  // Convert 1-based to 0-based
        guard targetIdx >= 0, targetIdx < lines.count else { return "" }

        let startIdx = max(0, targetIdx - 1)
        let endIdx = min(lines.count - 1, targetIdx + 1)

        var snippet = "  ```swift\n"
        for i in startIdx...endIdx {
            let marker = (i == targetIdx) ? ">" : " "
            let lineNum = String(i + 1).padding(toLength: 5, withPad: " ", startingAt: 0)
            snippet += "  \(marker) \(lineNum)| \(lines[i])\n"
        }
        snippet += "  ```\n"
        return snippet
    }

    /// Read file lines with caching. Skips files > 1MB.
    private static func readFileLines(fullPath: String, cache: inout [String: [String]]) -> [String]? {
        if let cached = cache[fullPath] {
            return cached
        }

        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
              let fileSize = attrs[.size] as? UInt64,
              fileSize <= 1_048_576 else {
            return nil
        }

        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: "\n")
        cache[fullPath] = lines
        return lines
    }

    // MARK: - Stale Index Warning

    /// Check if source files are newer than the index store. Returns warning string or nil.
    private static func checkIndexStaleness(store: IndexStore, sourceFilePaths: Set<String>) -> String? {
        guard !sourceFilePaths.isEmpty else { return nil }

        let fm = FileManager.default
        let v5Path = store.path + "/v5"

        guard let indexAttrs = try? fm.attributesOfItem(atPath: v5Path),
              let indexMtime = indexAttrs[.modificationDate] as? Date else {
            return nil
        }

        var latestSourceMtime: Date?
        for path in sourceFilePaths {
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date else { continue }
            if latestSourceMtime == nil || mtime > latestSourceMtime! {
                latestSourceMtime = mtime
            }
        }

        guard let sourceMtime = latestSourceMtime else { return nil }

        if sourceMtime > indexMtime {
            return "---\n**Warning:** Index may be stale — source files modified after last build. Rebuild in Xcode for accurate results.\n"
        }

        return nil
    }

    // MARK: - Index Store Queries

    private struct SymbolDefinition {
        let symbolName: String
        let fileName: String
        let fullPath: String
        let line: Int
        let usr: String?
        let kind: String?
    }

    private struct IncomingCaller {
        let callerName: String
        let fileName: String
        let fullPath: String
        let line: Int
    }

    private struct OutgoingCallee {
        let calleeName: String
        let fileName: String
        let fullPath: String
        let line: Int
    }

    private struct SymbolReference {
        let fileName: String
        let fullPath: String
        let line: Int
        let roleDescription: String
        let containerName: String?
    }

    /// Returns definitions and the full set of USRs found across all targets.
    private static func findDefinitions(symbol: String, fileFilter: String?, store: IndexStore) -> ([SymbolDefinition], Set<String>) {
        var definitions: [SymbolDefinition] = []
        var allUSRs: Set<String> = []
        var seenLocations: Set<String> = []

        for unit in store.units {
            if let filter = fileFilter {
                guard unit.mainFile.hasSuffix(filter) else { continue }
            }
            guard let recordName = unit.recordName else { continue }

            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
            let fullFile = unit.mainFile

            reader.forEach(occurrence: { occurrence in
                let sym = occurrence.symbol
                guard sym.name.contains(symbol),
                      occurrence.roles.contains(.definition) else { return }

                // Collect ALL USRs (even if same source location compiled by multiple targets)
                let usr = sym.usr
                allUSRs.insert(usr)

                // Deduplicate definitions by file+line (not USR — same location may have multiple USRs)
                let locationKey = "\(shortFile):\(occurrence.location.line)"
                guard !seenLocations.contains(locationKey) else { return }
                seenLocations.insert(locationKey)

                // Skip test helpers - prefer production definitions
                if shortFile.contains("TestHelper") && fileFilter == nil {
                    return
                }

                let kindName = symbolKindName(sym.kind)

                definitions.append(SymbolDefinition(
                    symbolName: sym.name,
                    fileName: shortFile,
                    fullPath: fullFile,
                    line: occurrence.location.line,
                    usr: usr,
                    kind: kindName
                ))
            })
        }

        return (definitions, allUSRs)
    }

    private static func symbolKindName(_ kind: IndexStoreWrapper.SymbolKind) -> String {
        return kind.description
    }

    private static func findIncomingCallers(symbol: String, usrs: Set<String>, store: IndexStore) -> [IncomingCaller] {
        // When doing name-based search (no USRs), try exact match first, then fall back to contains
        let nameMatchers: [(String, String) -> Bool] = [
            { name, sym in name == sym },
            { name, sym in name.contains(sym) }
        ]

        var callers: [IncomingCaller] = []
        var seen: Set<String> = []
        let resultCap = 100

        for passMatcher in (!usrs.isEmpty ? [nameMatchers[0]] : nameMatchers) {
            callers.removeAll()
            seen.removeAll()

            for unit in store.units {
                guard let recordName = unit.recordName else { continue }
                guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
                let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
                let fullFile = unit.mainFile

                reader.forEach(occurrence: { occurrence in
                    let sym = occurrence.symbol

                    // Match by USR set if available, otherwise by name
                    let matches: Bool
                    if !usrs.isEmpty {
                        matches = usrs.contains(sym.usr)
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
                        fullPath: fullFile,
                        line: occurrence.location.line
                    ))
                })
            }

            // For USR-based search, run once; for name-based, stop if exact match found results
            if !usrs.isEmpty || !callers.isEmpty {
                break
            }
        }

        // Cap results for name-based searches to prevent massive output
        if usrs.isEmpty && callers.count > resultCap {
            return Array(callers.prefix(resultCap))
        }

        return callers
    }

    private static func findOutgoingCallees(symbol: String, usrs: Set<String>, fileFilter: String?, store: IndexStore) -> [OutgoingCallee] {
        var callees: [OutgoingCallee] = []
        var seen: Set<String> = []

        for unit in store.units {
            // For outgoing calls, we need to look in the file where the function is defined
            if let filter = fileFilter {
                guard unit.mainFile.hasSuffix(filter) else { continue }
            }
            guard let recordName = unit.recordName else { continue }
            guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
            let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
            let fullFile = unit.mainFile

            reader.forEach(occurrence: { occurrence in
                guard occurrence.roles.contains(.call) else { return }

                occurrence.forEach(relation: { relSym, relRoles in
                    // Match by USR set if available, otherwise by name
                    let matches: Bool
                    if !usrs.isEmpty {
                        matches = usrs.contains(relSym.usr)
                    } else {
                        matches = relSym.name.contains(symbol)
                    }

                    guard matches, relRoles.contains(.calledBy) else { return }

                    let calleeName = occurrence.symbol.name
                    let key = "\(shortFile):\(calleeName):\(occurrence.location.line)"
                    guard !seen.contains(key) else { return }
                    seen.insert(key)

                    // Skip getters/setters for cleaner output unless they're meaningful
                    if calleeName.hasPrefix("getter:") || calleeName.hasPrefix("setter:") {
                        return
                    }

                    callees.append(OutgoingCallee(
                        calleeName: calleeName,
                        fileName: shortFile,
                        fullPath: fullFile,
                        line: occurrence.location.line
                    ))
                })
            })
        }

        return callees.sorted(by: { $0.line < $1.line })
    }

    private static func findAllReferences(symbol: String, usrs: Set<String>, store: IndexStore) -> [SymbolReference] {
        // When doing name-based search (no USRs), try exact match first, then fall back to contains
        let nameMatchers: [(String, String) -> Bool] = [
            { name, sym in name == sym },
            { name, sym in name.contains(sym) }
        ]

        var references: [SymbolReference] = []
        var seen: Set<String> = []
        let resultCap = 100

        for passMatcher in (!usrs.isEmpty ? [nameMatchers[0]] : nameMatchers) {
            references.removeAll()
            seen.removeAll()

            for unit in store.units {
                guard let recordName = unit.recordName else { continue }
                guard let reader = try? RecordReader(indexStore: store, recordName: recordName) else { continue }
                let shortFile = unit.mainFile.components(separatedBy: "/").last ?? unit.mainFile
                let fullFile = unit.mainFile

                reader.forEach(occurrence: { occurrence in
                    let sym = occurrence.symbol

                    // Match by USR set if available, otherwise by name
                    let matches: Bool
                    if !usrs.isEmpty {
                        matches = usrs.contains(sym.usr)
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
                        fullPath: fullFile,
                        line: occurrence.location.line,
                        roleDescription: roleDescription(roles),
                        containerName: containerName
                    ))
                })
            }

            // For USR-based search, run once; for name-based, stop if exact match found results
            if !usrs.isEmpty || !references.isEmpty {
                break
            }
        }

        // Cap results for name-based searches to prevent massive output
        if usrs.isEmpty && references.count > resultCap {
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
