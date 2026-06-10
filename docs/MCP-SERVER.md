# MCP Server — AI tooling for Godot EventSheets

Godot EventSheets ships a [Model Context Protocol](https://modelcontextprotocol.io)
server so AI assistants (Claude Code, Claude Desktop, and any other MCP client) can read,
lint, compile, and extend event sheets directly.

It is **pure GDScript** — no Python/Node dependencies. The Godot binary itself is the
server process.

## Setup

Register the server with your MCP client. For Claude Code (`.mcp.json` in your project,
or `claude mcp add`):

```json
{
  "mcpServers": {
    "godot-eventsheets": {
      "command": "C:/path/to/Godot_v4.5.1-stable_win64_console.exe",
      "args": [
        "--headless", "--quiet",
        "--path", "C:/path/to/your/godot/project",
        "--script", "addons/eventsheet/mcp/run_mcp_server.gd"
      ]
    }
  }
}
```

Notes:
- `--quiet` is **required**: it suppresses the engine banner that would otherwise corrupt
  the JSON-RPC stdout stream.
- The project must have been imported at least once (run the editor, or
  `godot --headless --import` first).
- On Windows prefer the `_console.exe` binary (the windowed one detaches from stdio).

## Tools

| Tool | What it does |
| --- | --- |
| `list_sheets` | Every `.tres` event sheet in the project. |
| `read_sheet {path}` | Structured JSON of a sheet — rows (events/groups/comments/variables/enums/GDScript blocks), variables, functions, identity. Also accepts any `.gd` path (opened read-only as a GDScript-backed sheet). |
| `list_aces {query?}` | The full ACE vocabulary — builtins **plus zero-config addons** — with categories, codegen templates, and param hints. |
| `compile_sheet {path, write_output?}` | Compiles a sheet. **Dry-run by default** (returns the generated GDScript without touching files); `write_output: true` writes the real output. |
| `lint_block {code, in_flow?, sheet_path?}` | Compile-checks GDScript against a sheet's context (its variables, enums, host class). |
| `apply_snippet {path, text, dry_run?}` | Appends rows to a `.tres` sheet from EventSheet snippet text **or plain GDScript** (auto-converted through the same lossless lift pipeline the editor's paste uses). `.tres` only — GDScript-backed sheets are edited as code. |

## Safety model

- Read tools never write anything; `compile_sheet` only writes when explicitly asked.
- `apply_snippet` is the single mutating tool: it appends rows and saves the `.tres`
  (it never deletes or reorders), and refuses GDScript-backed sheets.
- The server only sees the project it was launched with (`--path`).

## Architecture

- `addons/eventsheet/mcp/mcp_server.gd` — transport-free protocol core
  (`handle_message(Dictionary) -> Variant`), fully covered by `tests/mcp_server_test.gd`.
- `addons/eventsheet/mcp/run_mcp_server.gd` — the stdio loop (newline-delimited JSON-RPC,
  per the MCP stdio transport).
- The ACE registry is bootstrapped exactly like the editor (builtin descriptors + the
  zero-config addon scan), so `list_aces` always matches what the picker shows.
