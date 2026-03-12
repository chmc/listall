You are implementing phase {{PHASE_NUM}}: {{PHASE_TITLE}}.

Read the full plan at {{PLAN_FILE}} for context.

## Your task

{{PHASE_DESCRIPTION}}

## Rules
- Write tests first (TDD)
- Keep changes minimal
- Do not modify unrelated files
- When start work mark suitable item or items in original plan /Users/aleksi/source/listall/docs/superpowers/specs/2026-03-12-ui-polish-design.md to in-progress 
- When implementation work is done, do comprehensive visual verification on modified or applied apps (iphone, ipad, watch, macos) see Visual Verification After Implementation
- Verify implementation work against ui design mocks found in /Users/aleksi/source/listall/.superpowers/brainstorm/57429-1773298544 and images /Users/aleksi/source/listall/.superpowers/brainstorm/57429-1773298544/screens
- When work is finished mark suitable item or items in original plan /Users/aleksi/source/listall/docs/superpowers/specs/2026-03-12-ui-polish-design.md to completed

### Visual Verification After Implementation

**BLOCKING RULE:** After all tasks are complete, apply the `visual-verification` skill:

1. Run `listall_diagnostics` to confirm MCP tools are connected
2. Build and launch on ALL applicable platforms:
   - **macOS**: `listall_launch_macos` with `UITEST_MODE`, then `listall_screenshot_macos`
   - **iPhone**: Boot simulator, launch with `UITEST_MODE`, screenshot
   - **iPad** (if UI changes): Boot iPad simulator, launch, screenshot
   - **watchOS** (if watch changes): Boot Watch simulator, launch, screenshot
3. Carefully analyze ALL screenshots for correctness (layout, alignment, content, navigation)
4. Compare screenshots across platforms for consistency
5. **Cleanup**: Quit macOS app (`listall_quit_macos`) and shutdown simulators (`listall_shutdown_simulator`)
