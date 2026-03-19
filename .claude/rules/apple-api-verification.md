# Apple API Verification

## Rule
**Always verify Apple API usage** with AppleDocs MCP and web search before using or modifying calls to Apple frameworks.

Apple APIs change rapidly across iOS versions. Don't rely on memory — confirm:
- The API exists and isn't deprecated for the target iOS version
- Parameter names, types, and return values are current
- Any new alternatives introduced in recent releases

## When to Verify
- Using any Apple framework API you haven't verified this session
- Migrating code to a new iOS version
- Debugging unexpected behavior from a system framework
- Adding new framework integrations (MLX, Metal, etc.)

## How to Verify
1. **AppleDocs MCP** — `search_symbols` and `get_documentation` for the specific API
2. **Web search** — cross-reference with current-year documentation and WWDC notes
3. If both sources conflict, trust the official Apple documentation
