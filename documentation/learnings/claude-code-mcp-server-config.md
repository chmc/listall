<!--
Severity: HIGH - MCP tools won't load without correct config
Naming: claude-code-mcp-server-config.md
Search: grep -l "mcp" documentation/learnings/*.md
-->
---
title: Claude Code MCP Server Configuration Location
date: 2026-01-21
severity: HIGH
category: ci-cd
tags:
  - mcp
  - claude-code
  - configuration
  - mcp-server
  - settings
symptoms:
  - MCP tools not appearing in Claude Code session
  - listall_* tools not available after restart
  - MCP server works when tested manually but not in Claude Code
root_cause: MCP server configuration was in wrong file (settings.local.json instead of .mcp.json)
solution: Move MCP server config to .mcp.json in project root with correct format
files_affected:
  - .mcp.json
  - .claude/settings.local.json
related: []
---

## Problem

MCP server tools were not loading in Claude Code despite the server binary working correctly when tested manually. The server responded properly to MCP protocol initialize messages, but Claude Code couldn't see any `listall_*` tools.

## Root Cause

MCP servers are **NOT** configured in `.claude/settings.local.json`. That file is for settings like permissions, environment variables, and hooks.

MCP server configuration belongs in:
- **Project scope**: `.mcp.json` in project root
- **User scope**: `~/.claude.json`

Additionally, the config was missing the required `type: "stdio"` field.

```json
// BAD - wrong file (.claude/settings.local.json) and missing type
{
  "mcpServers": {
    "listall": {
      "command": "/path/to/mcp-server"
    }
  }
}

// GOOD - correct file (.mcp.json) with required fields
{
  "mcpServers": {
    "listall": {
      "type": "stdio",
      "command": "/path/to/mcp-server",
      "args": [],
      "env": {}
    }
  }
}
```

## Solution

1. Create `.mcp.json` in project root with correct format:
```json
{
  "mcpServers": {
    "listall": {
      "type": "stdio",
      "command": "/Users/aleksi/source/listall/Tools/listall-mcp/.build/debug/listall-mcp",
      "args": [],
      "env": {}
    }
  }
}
```

2. Optionally add to `.claude/settings.local.json` for auto-approval:
```json
{
  "enableAllProjectMcpServers": true
}
```

3. Restart Claude Code to load the MCP server

4. Verify with `/mcp` command

## Prevention

- [ ] Always use `.mcp.json` for MCP server configuration
- [ ] Include `type: "stdio"` for local executable servers
- [ ] Test MCP server manually first: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | ./mcp-server`
- [ ] Check `/mcp` command output after restart to verify server loaded

## Key Insight

> MCP servers go in `.mcp.json` at project root, not in `.claude/settings.local.json` - and always include `type: "stdio"` for local executables.
