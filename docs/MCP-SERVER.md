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
| `read_sheet {path}` | Structured JSON of a sheet — rows (events/groups/comments/variables/enums/GDScript blocks), variables, functions, identity. Variable JSON carries every value type (incl. Vector2/Color/Texture2D/Curve) and the `attributes.{drawer, group, subgroup, range, tooltip}` Inspector fields verbatim — the read/compile path is type-agnostic, so new constructs flow through with no allowlist to update. Also accepts any `.gd` path (opened read-only as a GDScript-backed sheet). |
| `list_aces {query?}` | The full ACE vocabulary — builtins **plus zero-config addons** — with categories, codegen templates, and param hints. |
| `compile_sheet {path, write_output?}` | Compiles a sheet. **Dry-run by default** (returns the generated GDScript without touching files); `write_output: true` writes the real output. |
| `lint_block {code, in_flow?, sheet_path?}` | Compile-checks GDScript against a sheet's context (its variables, enums, host class). |
| `apply_snippet {path, text, dry_run?}` | Appends rows to a `.tres` sheet from EventSheet snippet text **or plain GDScript** (auto-converted through the same lossless lift pipeline the editor's paste uses). `.tres` only — GDScript-backed sheets are edited as code. |

## AI-assisted event generation ("describe → events")

These tools compose into a generation loop, so an MCP-connected AI can turn a plain-English
request into editable events — grounded in the project, never a black box:

1. **Ground** — `list_aces` for the available vocabulary, `read_sheet` for the current context
   (host class, variables, existing rows).
2. **Generate** — the model writes plain **GDScript** for the requested behavior (the thing
   LLMs are strongest at), referencing the sheet's variables/host.
3. **Preview** — `apply_snippet {dry_run: true}` runs that GDScript through the **lossless
   GDScript→events lifter** and reports the row kinds it would add, without touching the file.
4. **Apply** — `apply_snippet` appends the lifted, fully-editable event rows; `compile_sheet`
   regenerates the script.

Because generation rides the same lossless lift the editor's paste uses, the AI's output lands
as ordinary events you can read, tweak, and diff — not opaque generated code. The remaining
piece for an *in-editor* English prompt (rather than an external MCP client) is a built-in LLM
call, which is opt-in API configuration rather than new generation plumbing — the plumbing is
this loop, and it's covered by `mcp_server_test`.

## Turning it on/off (activate / deactivate at will)

The MCP server is a process your AI **client** launches, so the editor can't start or stop it
— but it can **gate** it, live. In the EventSheets dock, **View ▸ MCP Server (AI tools)** is a
checkbox:

- **On (default):** tools are served normally.
- **Off:** the server returns an **empty tool list** and refuses every `tools/call` with a
  clear "turned off" message — so a connected AI can't read or change your sheets.

It works by toggling a marker file (`user://eventsheets_mcp_disabled`) that the running server
re-checks on each request, so flipping it takes effect **without reconnecting** the client. The
marker is per-machine and not committed; delete it (or re-check the box) to re-enable. To keep
the server off entirely, just leave it out of your client's `.mcp.json`.

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

## Composition policy

`list_aces` honors the project's composition policy: when
`eventsheets/addons/include_sources` is `tagged:<tag>`, addon ACEs without that tag are
omitted (Core builtins always list). AI assistants are therefore policy-bound — see
`docs/ADDON-COMPOSITION-SPEC.md`.
