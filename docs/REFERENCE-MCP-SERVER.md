# MCP Server - AI Tooling for Godot EventSheets

Godot EventSheets ships a [Model Context Protocol](https://modelcontextprotocol.io) server so AI assistants (Claude Code, Claude Desktop, and any other **MCP client**) can read, lint, compile, explain, verify and edit event sheets directly - `.gd` scripts and `.tres` sheets alike. It is **pure GDScript** - no Python/Node dependencies; the Godot binary itself is the server process. When the project is open in the editor, the server talks to the editor itself, so the assistant sees your open tabs as they are and every edit it makes is one Ctrl+Z away. This guide covers setup, every tool the server exposes, the describe → events generation loop, the editor link, the live on/off gate, and the safety model that bounds what an AI can touch.

## Table of Contents

1. [Scenarios Where the MCP Server Helps](#1-scenarios-where-the-mcp-server-helps)
2. [Setup](#2-setup)
3. [Tool Reference](#3-tool-reference)
4. [AI-Assisted Event Generation ("describe → events")](#4-ai-assisted-event-generation-describe--events)
5. [Working With the Open Editor](#5-working-with-the-open-editor)
6. [Turning It On and Off](#6-turning-it-on-and-off)
7. [Safety Model](#7-safety-model)
8. [Architecture](#8-architecture)
9. [Composition Policy](#9-composition-policy)
10. [Tips and Common Mistakes](#10-tips-and-common-mistakes)

---

## 1. Scenarios Where the MCP Server Helps

- **An AI assistant that can actually read your sheets.** `read_sheet` returns structured JSON - rows, variables, functions, identity - instead of the assistant guessing from raw file text.
- **Plain-English requests that land as editable events.** The describe → events loop turns "make the player flash when hit" into ordinary rows you can read, tweak, and diff - never opaque generated code.
- **Grounded generation, not hallucinated vocabulary.** `list_aces` gives the model the real ACE vocabulary - builtins plus zero-config addons - with codegen templates and param hints.
- **Compile-checking before anything is written.** `lint_block` validates GDScript against a sheet's actual context, and `compile_sheet` is dry-run by default.
- **Previewing a change without touching the file.** `apply_snippet {dry_run: true}` reports exactly which row kinds would be added.
- **Editing the sheet you have open, and taking it back.** With the editor open, an assistant's edit appears in your tab as you watch, unsaved, and Ctrl+Z undoes it like any edit of yours.
- **Small, exact edits instead of rewrites.** Insert rows inside an event or group at a position, rewrite one row, delete one row, add or reword a comment, change a variable's export options, or rename a variable everywhere the sheet uses it.
- **Asking what a line of code became.** `explain` turns a file and line number into the row it opens as - useful when an error message or a stack trace names a line.
- **Checking a change before it is committed.** `verify` runs the same standing-contract checks the command-line gate runs, on the files you name.
- **Cutting the AI off instantly.** A dock checkbox gates every tool live, without reconnecting the client.

---

## 2. Setup

Register the server with your MCP client. For Claude Code (`.mcp.json` in your project, or `claude mcp add`):

```json
{
  "mcpServers": {
    "godot-eventsheets": {
      "command": "C:/path/to/Godot_v4.7-stable_win64_console.exe",
      "args": [
        "--headless", "--no-header",
        "--path", "C:/path/to/your/godot/project",
        "--script", "addons/eventsheet/mcp/run_mcp_server.gd"
      ]
    }
  }
}
```

Notes:

- `--no-header` is **required**: it leaves out the engine banner that would otherwise corrupt the JSON-RPC stdout stream. Do **not** use `--quiet` for this: in Godot 4.7 it silences everything written to stdout, the answers included, so the client waits forever (the server says so on stderr).
- The project must have been imported at least once (run the editor, or `godot --headless --import` first).
- On Windows prefer the `_console.exe` binary (the windowed one detaches from stdio).
- The same entry works with or without the editor open: when the editor is answering, the server passes every call to it (see [Working With the Open Editor](#5-working-with-the-open-editor)); otherwise it reads and writes the files itself.
- For CI and scripts that must never touch an open editor, add `"--", "--no-live"` to the end of `args`: the server then always works on the files.

---

## 3. Tool Reference

Every tool that takes a `path` accepts a `.tres` sheet or a `.gd` script.

| Tool | What it does |
| --- | --- |
| `list_sheets` | Every event sheet in the project: stored `.tres` sheets and `.gd` scripts (any script opens as a sheet). The plugin's own code - `addons/` and the behaviour packs it ships under `eventsheet_addons/` - is left out; a pack you made yourself is listed. With the editor open, `open_in_editor` also names each open tab and whether it has unsaved edits. |
| `read_sheet {path}` | Structured JSON of a sheet - rows (events/groups/comments/variables/enums/GDScript blocks and every other row kind), variables, functions, identity. Every row carries its **address** (see below); a `.gd` sheet's rows also carry the `lines` of the file they are written on. Variable JSON carries every value type (incl. Vector2/Color/Texture2D/Curve) and the `attributes.{drawer, group, subgroup, range, tooltip}` Inspector fields verbatim. With the editor open, a sheet open in a tab is read as the tab holds it, unsaved edits included (`read_from: "editor"`). |
| `list_aces {query?}` | The full ACE vocabulary - builtins **plus zero-config addons** - with categories, codegen templates, and param hints. |
| `compile_sheet {path, write_output?}` | Compiles a sheet. **Dry-run by default** (returns the generated GDScript without touching files; with the editor open it compiles the tab as it is); `write_output: true` compiles the file to its real output. |
| `lint_block {code, in_flow?, sheet_path?}` | Compile-checks GDScript against a sheet's context (its variables, enums, host class). |
| `apply_snippet {path, text, parent?, position?, dry_run?}` | Inserts rows from EventSheet snippet text **or plain GDScript** (auto-converted through the same lossless lift pipeline the editor's paste uses). At the end of the top level by default; `parent` (an event or group address) puts them inside it, and `position` is the index among that level's rows. |
| `edit_row {path, row, text}` | Replaces one row with the rows `text` converts to (snippet text or GDScript), in the same place. |
| `delete_row {path, row}` | Deletes one row and every row under it. |
| `comment {path, text, row?, parent?, position?}` | Adds a comment row (placed like `apply_snippet`), or with `row`, rewrites that comment's text. |
| `variable_properties {path, name, set?}` | Reads a variable's export options - `exported`, `export_hint` (an annotation such as `@export_range(0, 10)`), `options` (a combo's values), `attributes` (Inspector group, subgroup, range, tooltip and the rest) and `description`. `set` changes any of those fields. A `.gd` sheet's variables are rows; a `.tres` sheet's variable table is answered too. |
| `rename {path, from, to}` | Renames a variable or function across the sheet - its declaration and every place the sheet names it. A name already taken is refused. |
| `explain {path, line}` | Which row one line of a `.gd` file becomes when the file opens as a sheet: its `row` address, `kind` and the `lines` it is written on. A file that does not save back byte for byte is told so, because its line numbers no longer map. Reads the file on disk. |
| `verify {paths?}` | The standing-contract checks the command-line gate runs: each file parses, opens as a sheet and saves back byte for byte, holds no doubled baked local, and has no migration row waiting on a person. Returns `passed`, each failure, and the verdict line. Name the files you changed - with no paths it reads the whole project, which is slow. Read-only. |
| `run_doctor` | The Project Doctor health audit over every sheet: stale generated outputs, compile failures, debug residue, wiring gaps, vocabulary hygiene - plus any pack-registered checks. Returns findings (`{severity, check, path, message}`) and error/warning/info counts. Read-only. |

**Row addresses.** A row is named by the indices from the top of the sheet down to it, joined with `/`: `"3"` is the fourth top-level row, and `"3/0"` is the first row inside it (an event's first sub-event, or a group's first child). The empty address is the sheet itself. An address is a place, not a handle - inserting or deleting a row above another moves it - so read the sheet again after a structural edit.

**Where an edit goes.** With the editor open, an edit goes into the open tab (the sheet is opened in a tab first if it was not) as one undo step, unsaved; the answer says `where: "editor"` and names the `undo` step. Without the editor, it is written to the file (`saved: true`): a `.tres` through Godot's resource saver, a `.gd` only when it is safe to - see [Safety Model](#7-safety-model).

---

## 4. AI-Assisted Event Generation ("describe → events")

These tools compose into a **generation loop**, so an MCP-connected AI can turn a plain-English request into editable events - grounded in the project, never a black box:

1. **Ground** - `list_aces` for the available vocabulary, `read_sheet` for the current context (host class, variables, existing rows).
2. **Generate** - the model writes plain **GDScript** for the requested behavior (the thing LLMs are strongest at), referencing the sheet's variables/host.
3. **Preview** - `apply_snippet {dry_run: true}` runs that GDScript through the **lossless GDScript→events lifter** and reports the row kinds it would add, without touching the file.
4. **Apply** - `apply_snippet` appends the lifted, fully-editable event rows; `compile_sheet` regenerates the script.

Because generation rides the same lossless lift the editor's paste uses, the AI's output lands as ordinary events you can read, tweak, and diff - not opaque generated code. For a change to rows that already exist, `edit_row`, `delete_row`, `comment`, `variable_properties` and `rename` do it in place instead of appending. The remaining piece for an *in-editor* English prompt (rather than an external MCP client) is a built-in LLM call, which is opt-in API configuration rather than new generation plumbing - the plumbing is this loop, and it's covered by `mcp_server_test`.

---

## 5. Working With the Open Editor

Once the EventSheets workspace has been opened in this editor session and the MCP switch is on, the editor listens for the server on your own machine (`127.0.0.1` only). The server process your client launches finds it and passes every call through, so:

- **The assistant sees what you see.** A sheet open in a tab is read as the tab holds it, unsaved edits included, and `list_sheets` names your open tabs.
- **Edits appear in front of you.** The tab redraws with the change, the title gains its unsaved star, and the status line names the edit. A sheet that was not open is opened in a tab first.
- **Ctrl+Z takes it back.** Each edit is one step in the editor's history, named after the tool (`Add Rows`, `Edit Row`, `Delete Row`, `Add Comment`, `Edit Comment`, `Variable Properties`, `Rename <name>`), exactly like an edit you made yourself.
- **Nothing is saved for you.** The file changes when you save the tab, as with any edit. `compile_sheet`'s dry run compiles the tab as it is; `explain` and `verify` read the files on disk.

The editor writes the port it listens on, with a fresh random key, to `user://eventsheets_mcp_live.json` - your project's own per-machine folder - and only a caller that can read that file is answered. Nothing listens before the workspace is first opened, and the link closes when the switch is turned off or the editor closes. With no editor answering, the server works on the files as before.

---

## 6. Turning It On and Off

The MCP server is a process your AI **client** launches, so the editor can't start or stop it - but it can **gate** it, live. In the EventSheets dock, **View ▸ MCP Server (AI tools)** is a checkbox:

- **On (default):** tools are served normally.
- **Off:** the server returns an **empty tool list** and refuses every `tools/call` with a clear "turned off" message - so a connected AI can't read or change your sheets. Turning it off also closes the editor link.

It works by toggling a **marker file** (`user://eventsheets_mcp_disabled`) that the running server re-checks on each request, so flipping it takes effect **without reconnecting** the client. The marker is per-machine and not committed; delete it (or re-check the box) to re-enable. To keep the server off entirely, just leave it out of your client's `.mcp.json`.

---

## 7. Safety Model

- Read tools never write anything; `compile_sheet` only writes when explicitly asked.
- The editing tools are `apply_snippet`, `edit_row`, `delete_row`, `comment`, `variable_properties` and `rename`. With the editor open they change the open tab only, as undoable unsaved edits.
- Without the editor, a `.gd` is written only when every one of these holds, and otherwise the file is left exactly as it was and the answer says why:
  - the file opens as a sheet and saves back **byte for byte** before the edit, so rows the edit never touched cannot come out different;
  - the edited sheet compiles;
  - the bytes about to be written open as a sheet and save back byte for byte themselves.
- A `.gd` still holding merge conflict markers, or marked to stay code, is never edited.
- Every file write keeps the previous bytes in the backup ring first (Tools → Sheet Backups…).
- The server only sees the project it was launched with (`--path`), and the editor link answers only on `127.0.0.1`, to a caller holding the key in the project's user folder.

---

## 8. Architecture

- `addons/eventsheet/mcp/mcp_server.gd` - transport-free protocol core (`handle_message(Dictionary) -> Variant`), fully covered by `tests/mcp_server_test.gd`.
- `addons/eventsheet/mcp/mcp_row_edits.gd` - row addresses, and the insert / replace / delete edits on a sheet.
- `addons/eventsheet/mcp/mcp_live_link.gd` - the editor's link: the same core served on `127.0.0.1`, reading open tabs and editing through the dock's undo funnel.
- `addons/eventsheet/mcp/run_mcp_server.gd` - the stdio loop (newline-delimited JSON-RPC, per the MCP stdio transport); relays to the editor when it answers, else serves the files.
- The ACE registry is bootstrapped exactly like the editor (builtin descriptors + the zero-config addon scan), so `list_aces` always matches what the picker shows.

---

## 9. Composition Policy

`list_aces` honors the project's **composition policy**: when `eventsheets/addons/include_sources` is `tagged:<tag>`, addon ACEs without that tag are omitted (Core builtins always list). AI assistants are therefore policy-bound to the vocabulary the project has opted into.

---

## 10. Tips and Common Mistakes

- **Launch with `--no-header`, never `--quiet`.** Without `--no-header` the engine banner corrupts the JSON-RPC stdout stream; with `--quiet` every answer is silenced and the client hangs.
- **Import the project first.** The server needs a project that has been imported at least once - run the editor once, or `godot --headless --import`.
- **On Windows, use the `_console.exe` binary.** The windowed binary detaches from stdio, so the stdio transport goes dead.
- **Read the sheet again after a structural edit.** Row addresses are places: an insert or delete above a row moves it.
- **With the editor open, edits are unsaved until you save.** The assistant's change waits in the tab like your own; save it, or Ctrl+Z it.
- **A `.gd` that does not save back byte for byte is refused, not "fixed".** Run `verify` on it to see why, then open it in the editor and save it there first.
- **`compile_sheet` writes nothing unless you say so.** Dry-run is the default; pass `write_output: true` deliberately.
- **Preview before applying.** `apply_snippet {dry_run: true}` reports the row kinds a snippet would add without touching the file - use it as the review step in a generation loop.
- **The off switch works without a reconnect.** The server re-checks the marker file on each request, so the dock checkbox takes effect immediately - but the marker is per-machine and not committed, so teammates gate their own machines.
- **To keep the server off entirely, leave it out of `.mcp.json`.** The dock checkbox gates a running server; not registering it means the client never launches one.
