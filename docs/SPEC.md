# EventForge Specification (Consolidated)

> Updated 2026-06. The authoritative per-feature specs are
> `docs/EDITOR-UI-SPEC.md` (editor UX), `docs/GDSCRIPT-PAIRING-SPEC.md` (compiler,
> GDScript pairing, addons, behaviors), and `docs/EVENTSHEET_THEME_TOKEN_SPEC.md`
> (theming). This file is the architectural overview that ties them together.

## 1. Scope

EventForge provides Construct-style event sheet authoring for Godot and compiles sheet
resources to deterministic, plain GDScript with **performance parity to hand-written
code** (GDSCRIPT-PAIRING-SPEC, Principles #5 — guarded by `tests/codegen_parity_test.gd`).

## 2. Architecture

### 2.1 Resource/data model (source of truth)

The canonical model is resource-driven (`EventSheetResource` and row/ACE resources under
`addons/eventforge/resources/`). UI edits this model directly; save/load and compile
operate on the same resource graph. Sheets may also be **GDScript-backed**
(`external_source_path`): the `.gd` file is the source of truth and saving compiles back
to it byte-faithfully.

### 2.2 Editor layer

The editor lives under **`addons/eventsheet/`** (the earlier per-row widget prototype in
`addons/eventforge/editor/` was removed — it could not scale):

- `editor/` — `EventSheetDock` (orchestration: toolbar, dialogs, undo/redo, clipboard,
  multi-tab), `EventSheetViewport` (**custom-rendered, virtualized canvas** — only visible
  rows draw; this is the architecture that holds at tens of thousands of rows),
  `EventRowRenderer` (token-aware row painting), pickers and dialogs.
- `ace/` — the custom-ACE engine: registry, reflection generator, semantic analyzer
  (`@ace_*` annotations), addon scanner (`res://eventsheet_addons/`), GDScript lint.
- `theme/` — token resources, bundled presets, the Godot-adaptive default style.

### 2.3 Compiler/runtime boundary

- **Editor/UI responsibility:** author and mutate sheet resources.
- **Compiler responsibility:** emit plain GDScript from those resources.
- **Runtime responsibility:** none — generated scripts reference no EventForge classes;
  exported games run without the plugin. Addon ACEs compile to direct calls (baked
  templates or instance-backed provider members); behaviors compile to plain Node
  component scripts. `EventForgeBridge` is an *editor vocabulary* API
  (`register_script_as_provider`), never a per-frame runtime dependency.

## 3. Compiler contract

```gdscript
SheetCompiler.compile(sheet: EventSheetResource, output_path: String) -> Dictionary
```

Return dictionary keys:
- `success: bool`
- `errors: Array[String]`
- `warnings: Array[String]`
- `output: String`
- `source_map: Array` — `{uid, start, end, kind}` per emitted row (1-based inclusive
  lines), powering two-way provenance in the editor.

Generated files include a stable header (suppressed for GDScript-backed sheets) and use
`\n` line endings.

### 3.1 Translation matrix (implemented)

- Triggers → lifecycle hooks (`_ready`/`_process`/`_physics_process`) or **signal
  handlers with emitted `_ready` connections** (self signals compile-time validated;
  other nodes via `trigger_source_path`; custom `signal:<name>` triggers with baked
  argument signatures).
- Condition chains → boolean `if` expressions (AND/OR joins, `not (...)` negation).
- Actions → ordered direct statements (descriptor templates, baked addon templates, or
  instance-backed provider-member calls); `await` only when flagged.
- Sub-events → nested blocks under the parent's conditions; Else/Else-If → `elif`/`else`
  chains; empty blocks → `pass` (output always parses).
- Comments → `#` lines; in-flow variables → function locals; GDScript blocks → verbatim
  (class-level and in-flow).
- Sheet variables → typed `@export`/`var` declarations; functions → typed methods,
  optionally published as ACEs (`expose_as_ace` → emitted `@ace_*` annotations).
- Still deferred: pick filters.

The reverse direction also exists: the importer's **ACE-level lifter** reverses these
templates back into events (verified byte-identical or reverted).

## 4. ACE metadata normalization

ACE descriptors can be provided as `ACEDescriptor` resources or dictionary metadata.
Dictionary metadata accepts snake_case and Construct-style camelCase aliases (for example
`list_name/listName`, `display_text/displayText`, `description/desc`, and param
default/name aliases).

The `node_type`/`nodeType` field associates an ACE with a Godot class; the picker groups
the entry under that class (with its class icon) instead of `category`. Built-in Core
ACEs with a `node_type` pre-register named picker groups. The picker filters live (name,
description, node type, C3 synonym aliases), colours items by ACE type, prefixes tooltips
with `[Type]`, and shows per-ACE icons (`@ace_icon` → class icon → member glyph).

Normalized metadata is used consistently by picker display, param initialization, codegen
tooltips, and row rendering (object icon + label).

## 5. Directory layout (current)

- `addons/eventforge/` — `compiler/`, `resources/`, `registration/`, `runtime/`
  (bridge autoload), `importer/` (structural import, external sheets, ACE lifter),
  `binding/`.
- `addons/eventsheet/` — `editor/`, `ace/`, `theme/`, `elements/`, `icons/`.
- `eventsheet_addons/` — zero-config ACE addons + sample behavior packs
  (PlatformerMovement, EightDirectionMovement).
- `tests/` — `run_tests.gd` (full) and `run_perf.gd` (headless-safe gate, used by CI).
