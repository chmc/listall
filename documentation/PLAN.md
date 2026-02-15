# Plan: Add Call Graph MCP Tool via SourceKit-LSP

## Context

Claude Code's Explore agents consume tokens scanning the codebase. The project already has:
- `swift-lsp@claude-plugins-official` plugin (symbol search, find references, jump-to-definition)
- `listall-mcp` server (UI testing/verification)

The **gap**: no call graph or impact analysis. "Who calls this function?" and "What does this function call?" require manual grep exploration.

**What changed from the previous plan**: Critic and technical reviews found that 3 of 4 proposed tools duplicate existing plugin functionality, the effort was underestimated 2x, and sourcekit-lsp doesn't work with .xcodeproj without a bridge. The plan is now scoped to the one tool that adds genuine value.

## Approach: Two-Phase

### Phase 1: Prototype & Validate (1-2 days)

Build a standalone CLI tool that sends `callHierarchy` requests to SourceKit-LSP and prints results. This validates that:
- SourceKit-LSP returns useful call hierarchy data for this Xcode project
- The xcode-build-server bridge works correctly
- The data quality justifies further investment

If the prototype shows poor results (empty call graphs, missing relationships), **stop here**.

### Phase 2: MCP Integration (3-5 days)

If the prototype validates, add 1-2 tools to the **existing** `listall-mcp` server (no second server):

**`swift_call_graph`** — Who calls this function? What does this function call?
- Input: file path + line + column
- Output: incoming callers and outgoing callees
- LSP methods: `prepareCallHierarchy` → `incomingCalls` / `outgoingCalls`

**`swift_impact`** (stretch goal) — Multi-level call graph traversal
- Input: file path + line + column + depth
- Output: transitive callers up to N levels deep

## Prerequisites

### xcode-build-server (required for .xcodeproj projects)

SourceKit-LSP does NOT understand `.xcodeproj` directly. It needs a Build Server Protocol bridge:

```bash
brew install xcode-build-server
cd /Users/aleksi/source/listall
xcode-build-server config -project ListAll/ListAll.xcodeproj -scheme ListAll
```

This creates `buildServer.json` in the project root, which tells sourcekit-lsp where to find compilation flags and the index store.

### Xcode build (one-time)

The index store at `~/Library/Developer/Xcode/DerivedData/ListAll-*/Index.noindex/` must exist. Building in Xcode populates it. Background indexing (Swift 6.1+) keeps it fresh.

## Implementation Details

### Phase 1: CLI Prototype

Create `Tools/swift-call-graph/` as a simple Swift script or package:

```swift
// Spawn sourcekit-lsp, send initialize, open a document,
// send prepareCallHierarchy, then incomingCalls/outgoingCalls
// Print results and exit
```

Test with a known function in the ListAll codebase to verify data quality.

### Phase 2: Integration into listall-mcp

Add to the existing MCP server (`Tools/listall-mcp/`):

**New files:**
- `Sources/listall-mcp/Services/LSPClient.swift` — Minimal JSON-RPC client (~200-300 lines)
  - Content-Length framing
  - Request/response ID correlation
  - Process spawn via `xcrun sourcekit-lsp`
  - Lazy initialization on first tool call
  - Health check + auto-restart on crash
- `Sources/listall-mcp/Tools/CallGraphTool.swift` — MCP tool definition and handler

**Modified files:**
- `Sources/listall-mcp/main.swift` — Register new tool
- `CLAUDE.md` — Add usage instructions
- `.gitignore` — Add `buildServer.json` (machine-specific)

**No SQLite cache** — LSP responses are fast enough. Add caching later if profiling shows need.

**No separate MCP server** — Adding to listall-mcp avoids a second process, second build, and user confusion.

### LSP Client Architecture

```swift
actor LSPClient {
    private var process: Process?
    private var stdin: FileHandle
    private var stdout: FileHandle
    private var requestId: Int = 0
    private var pending: [Int: CheckedContinuation<Data, Error>]

    func send<T: Decodable>(_ method: String, params: Encodable) async throws -> T
    // JSON-RPC: "Content-Length: N\r\n\r\n{json}"
}
```

Reuse process management patterns from `XCUITestBridge.swift` (spawn, timeout, health check).

## Files Modified/Created

| File | Action |
|------|--------|
| `Tools/listall-mcp/Sources/listall-mcp/Services/LSPClient.swift` | New (~300 lines) |
| `Tools/listall-mcp/Sources/listall-mcp/Tools/CallGraphTool.swift` | New (~200 lines) |
| `Tools/listall-mcp/Sources/listall-mcp/main.swift` | Edit — register new tool |
| `CLAUDE.md` | Edit — add call graph usage instructions |
| `.gitignore` | Edit — add `buildServer.json` |

## Auto-Setup for Repo Cloners

Honest assessment: **This cannot be fully automatic.** Setup requires:

1. `brew install xcode-build-server` (one-time)
2. `xcode-build-server config -project ListAll/ListAll.xcodeproj -scheme ListAll` (one-time, generates `buildServer.json`)
3. Build the project in Xcode (populates index store)
4. `swift build` in `Tools/listall-mcp/` (rebuild MCP server with new tool)
5. Restart Claude Code

Steps 1-2 could be automated in a setup script. Steps 3-5 are standard dev workflow.

## TDD & Verification Protocol

**STRICT RULE**: Every step must be verified working before moving to the next. If verification fails, fix and re-verify. Do not proceed with broken state.

### Phase 0: Prerequisites Verification

| Step | Action | Verify | If Fails |
|------|--------|--------|----------|
| 0.1 | `brew install xcode-build-server` | `which xcode-build-server` returns path | Fix Homebrew, retry |
| 0.2 | `xcode-build-server config -project ListAll/ListAll.xcodeproj -scheme ListAll` | `buildServer.json` exists in project root | Check scheme name, retry with correct scheme |
| 0.3 | Check Xcode index exists | `ls ~/Library/Developer/Xcode/DerivedData/ListAll-*/Index.noindex/` shows `DataStore/` | Build project in Xcode first, retry |
| 0.4 | Test sourcekit-lsp launches | `xcrun sourcekit-lsp --help` prints usage | Check Xcode installation |

### Phase 1: CLI Prototype — TDD

**Step 1.1: JSON-RPC framing**
- Write test: send a raw JSON-RPC `initialize` request to sourcekit-lsp, verify response contains `capabilities`
- Implementation: minimal Content-Length framing over Process stdin/stdout
- **Verify**: Run test, print response JSON. Must contain `"capabilities"`. Stop if it doesn't.

**Step 1.2: Document open + call hierarchy prepare**
- Write test: open a known Swift file, send `textDocument/prepareCallHierarchy` for a known function
- Pick a concrete function: find a ViewModel method in the codebase that is called from multiple places
- **Verify**: Response contains at least 1 `CallHierarchyItem` with correct name and file path. If empty, debug:
  - Is the document URI correct? (must be `file:///absolute/path`)
  - Is the position (line/column) correct? (0-indexed in LSP)
  - Is the index populated? Re-build in Xcode if needed
  - Fix and retry until non-empty response

**Step 1.3: Incoming callers**
- Write test: take the `CallHierarchyItem` from 1.2, send `callHierarchy/incomingCalls`
- **Verify**: Response contains caller functions with file paths and ranges. If empty:
  - The function may have no callers (pick a different test function)
  - The index may be stale
  - Fix and retry

**Step 1.4: Outgoing callees**
- Write test: send `callHierarchy/outgoingCalls` for the same function
- **Verify**: Response contains called functions. If empty, pick a function that clearly calls other functions.

**Step 1.5: End-to-end quality check**
- Run all 4 tests against 3 different functions in the codebase:
  1. A ViewModel method (should have callers from Views)
  2. A Core Data method (should have callers from ViewModels)
  3. A utility function (should have multiple callers)
- **Go/No-Go Decision**: If 2+ of 3 return useful call graphs → proceed to Phase 2. Otherwise → stop and report findings.

### Phase 2: MCP Integration — TDD

**Step 2.1: LSPClient compiles**
- Add `LSPClient.swift` to `Tools/listall-mcp/`
- **Verify**: `swift build` in `Tools/listall-mcp/` succeeds with zero errors

**Step 2.2: LSPClient connects**
- Add a diagnostic tool `swift_lsp_status` that just tests the LSP connection
- **Verify**: Rebuild MCP server, restart Claude Code, call `swift_lsp_status` → returns "connected" with sourcekit-lsp version

**Step 2.3: CallGraphTool compiles and registers**
- Add `CallGraphTool.swift`, register in `main.swift`
- **Verify**: `swift build` succeeds, restart Claude Code, tool `swift_call_graph` appears in tool list

**Step 2.4: CallGraphTool returns data**
- Call `swift_call_graph` with the same test function from Phase 1
- **Verify**: Returns formatted callers and callees matching Phase 1 prototype output
- If empty/error: compare with prototype, debug LSP client, fix and retry

**Step 2.5: Edge cases**
- Test with invalid file path → verify graceful error message (not crash)
- Test with position that's not a function → verify meaningful error
- Kill sourcekit-lsp process mid-request → verify auto-restart and retry
- Test without `buildServer.json` → verify clear error message

**Step 2.6: Integration test**
- Use `swift_call_graph` in a real Claude Code exploration task
- Ask Claude to "find all callers of [function]" and verify it uses the tool
- Compare token usage with grep-based exploration for the same task

### Verification Checklist (must ALL pass before commit)

- [ ] `swift build` succeeds in `Tools/listall-mcp/`
- [ ] `swift_lsp_status` tool returns connected
- [ ] `swift_call_graph` returns non-empty callers for a known function
- [ ] `swift_call_graph` returns non-empty callees for a known function
- [ ] Invalid input produces helpful error (not crash)
- [ ] sourcekit-lsp crash triggers auto-restart
- [ ] Missing `buildServer.json` produces clear setup instructions
- [ ] CLAUDE.md updated with usage instructions
- [ ] `.gitignore` updated for `buildServer.json`

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| sourcekit-lsp returns empty call hierarchy | Medium | Phase 1 prototype validates this before investing |
| xcode-build-server not installed | Low | Clear error message with install instructions |
| sourcekit-lsp crashes | Medium | Auto-restart + timeout (reuse XCUITestBridge pattern) |
| Stale index | Medium | Background indexing (Swift 6.1+) + diagnostic message |
| Adding LSP client bloats listall-mcp | Low | ~500 lines total, clean separation in Services/ |

## Effort Estimate

- Phase 1 (prototype): 1-2 days
- Phase 2 (integration): 3-5 days
- **Total: 1-2 weeks** (with go/no-go gate after Phase 1)
