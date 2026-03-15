---
name: semantic-search
description: Reference for listall_call_graph MCP tool — modes, parameters, bootstrapping workflow, and decision matrix for Swift code exploration
---

# Semantic Search with `listall_call_graph`

Queries Xcode's IndexStore for structured code analysis. **MANDATORY**: Use as primary tool for understanding Swift code — callers, definitions, references, hierarchy. Use Grep only for string literals, comments, non-code content.

## Modes

| Mode | Use for | Example |
|------|---------|---------|
| `"graph"` (default) | Callers + callees | `listall_call_graph(symbol: "addList(name:)")` |
| `"callers"` | Who calls this | `listall_call_graph(symbol: "save()", mode: "callers")` |
| `"callees"` | What this calls | `listall_call_graph(symbol: "save()", mode: "callees")` |
| `"definition"` | Find where defined | `listall_call_graph(symbol: "DataRepository", mode: "definition")` |
| `"references"` | All usages | `listall_call_graph(symbol: "addList", mode: "references")` |
| `"hierarchy"` | Type hierarchy | `listall_call_graph(symbol: "DataRepository", mode: "hierarchy")` |
| `"members"` | List type members | `listall_call_graph(symbol: "Item", mode: "members")` |
| `"search"` | Symbol discovery (substring) | `listall_call_graph(symbol: "cross", mode: "search")` |
| `"dump"` | Raw index data (debug) | `listall_call_graph(symbol: "reorderLists(from:to:)", mode: "dump")` |

## Parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `symbol` | string | required | Function/method/type name |
| `file` | string | nil | File name to disambiguate |
| `mode` | string | `"graph"` | Query mode (see above) |
| `include_source` | bool | `false` | Include 3-line source snippets (~4x output) |

## Requirements

- Project must be built in Xcode
- After rebuilding MCP server, restart Claude Code

## Known Limitations

- SwiftUI view modifiers may not appear as calls in IndexStore
- Index staleness warning is heuristic (may have false negatives with incremental indexing)
- Multi-target symbols (e.g., shared iOS/macOS code) correctly find all callers across targets

## Bootstrapping Workflow

When you don't know the symbol name yet:

1. `listall_call_graph(symbol: "suggest", mode: "search")` — discover relevant symbols
2. `listall_call_graph(symbol: "SuggestionService", mode: "members")` — see what a type offers
3. `listall_call_graph(symbol: "getSuggestions", mode: "graph")` — trace the full call flow
4. Read source files only for implementation details that call_graph doesn't show

## Decision Matrix

| Question | Tool | Why |
|----------|------|-----|
| "How does X work?" | `search` → `graph` → Read | Discover, trace, then read details |
| "Where is X defined?" | `definition` | Direct lookup |
| "Who uses X?" | `references` | All usages with context |
| "What can type X do?" | `members` | Properties, methods, nested types |
| "What inherits X?" | `hierarchy` | Conformances, extensions, overrides |
| "What symbols relate to X?" | `search` | Case-insensitive substring discovery |
| "Debug index issue" | `dump` | Raw USRs, roles, relations |
| String literals, config values | Grep | Text content, not code structure |
| Comments, TODOs, docs | Grep | Non-code content |

## Fallback

If call_graph fails (index unavailable), run `touch .claude/.grep-fallback-authorized` then retry with Grep.
