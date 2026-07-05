# Custom Blocks Guide

ACEs define what a row can *do* inside events. **Custom blocks** define new *kinds of rows* that live between events: preloads, region markers, notes, config tables, pack-defined data blocks, anything a sheet needs that is not an event. This guide covers the whole Custom Block API: how to register a kind in one small script, the contract every kind implements, the add/edit UX your kind gets for free, and how the byte-gated round-trip guarantees a kind can never corrupt a file. Two block kinds ship built in, and the plugin's own enum and signal rows run on the same API, so everything here is the exact path the built-ins take.

## Table of Contents

1. [Scenarios Where Custom Blocks Excel](#1-scenarios-where-custom-blocks-excel)
2. [Core Concepts](#2-core-concepts)
3. [Quick Start](#3-quick-start)
4. [The Three Ways to Register a Kind](#4-the-three-ways-to-register-a-kind)
5. [The Kind Contract Reference](#5-the-kind-contract-reference)
6. [Schema Kinds vs Resource Kinds](#6-schema-kinds-vs-resource-kinds)
7. [The UX Your Kind Gets for Free](#7-the-ux-your-kind-gets-for-free)
8. [Round-Trip Safety: The Byte Gate](#8-round-trip-safety-the-byte-gate)
9. [Built-in Kinds Reference](#9-built-in-kinds-reference)
10. [Use Cases](#10-use-cases)
11. [Testing Custom Blocks](#11-testing-custom-blocks)
12. [Tips and Common Mistakes](#12-tips-and-common-mistakes)

---

## 1. Scenarios Where Custom Blocks Excel

- **A pack that ships data, not just verbs.** Your loot pack's ACEs read a drop table. A `my_pack.drop_table` block puts that table IN the sheet as an editable row instead of a raw GDScript dictionary.
- **Structure markers that survive the round-trip.** `#region Combat` fences from hand-written scripts open as first-class **Region** rows, stay editable, and write back byte-identically. Matched pairs FOLD like the script editor, draw a thin colored bubble around everything they cover (groups and every other block kind nest inside), glow while you drag a row into them, and carry an editable color + description.
- **Resource shortcuts designers actually use.** A **Preload Resource** block (`const Sfx := preload("res://sfx/jump.ogg")`) is one dialog with two fields instead of a code block someone has to type correctly.
- **Team conventions as rows.** A `## NOTE:` line is just a comment until a 30-line kind turns every one of them into a highlighted, searchable **Note** row (this exact kind ships as the living example).
- **Config blocks with a form.** A `const TUNING := {...}` dictionary becomes a block whose fields designers edit in a dialog, with the GDScript emitted canonically underneath.
- **Vocabulary from another plugin.** A separate editor plugin can register kinds in code through the bridge, no files dropped into this plugin's folders.

---

## 2. Core Concepts

### The problem this API solves

Before the API, every structural row kind (enums, signals, variables) was hand-wired through five separate files: a Resource class, a compiler emit branch, an importer lift probe, a viewport render branch, and a dock dialog. Adding a kind meant touching all five, so only the plugin itself could add kinds. The Custom Block API wires those seams **once, generically**: you write one small class, register it, and the compiler, importer, viewport, Add menu, command palette, and edit dialog all pick it up.

### Key design decisions

- **One generic instance class.** Blocks are stored as `CustomBlockRow` (a `kind_id` plus a `fields` Dictionary), never one Resource class per kind. Sheets stay loadable when a kind's pack is missing, the undo system needs no new cases, and the file formats never learn new class names.
- **The byte gate.** A kind's `lift()` claim is kept only when re-emitting the recovered block reproduces the source lines **byte-for-byte**. A permissive or buggy lift cannot corrupt a file; it just fails to claim, and the lines stay a plain GDScript block.
- **Graceful degradation.** Emitted lines are plain GDScript. If the sheet opens somewhere the kind is not registered, the lines simply do not lift: they render as a readable code block, compile fine, and are preserved verbatim on save.
- **`kind_id` is public API.** Once a kind ships and sheets use it, its id and emitted shape are a compatibility promise, the same covenant `ace_id`s carry.

### Key concepts at a glance

| Term | What it means |
|------|----------------|
| **Kind** | One registered row type: an `EventSheetBlockKind` subclass (stateless, one instance per session). |
| **`kind_id`** | The kind's stable public id (`"preload"`, `"my_pack.drop_table"`). Namespace pack kinds with `<pack>.`. |
| **`CustomBlockRow`** | The stored instance: `kind_id` + a `fields` Dictionary per the kind's schema. |
| **Schema kind** | A kind whose instances are `CustomBlockRow`s and whose dialog is auto-built from `fields()`. |
| **Resource kind** | A kind that owns an existing Resource class instead (the built-in enum and signal rows). |
| **The byte gate** | Lift claims survive only if canonical re-emission matches the source exactly. |

---

## 3. Quick Start

Drop this script anywhere under `res://eventsheet_addons/` and it registers automatically; no manifest, no plugin edits. It is the shipped `demo_note_block.gd`, the whole thing:

```gdscript
@tool
extends EventSheetBlockKind

func _init() -> void:
	kind_id = "demo.note"      # stable public id; namespace pack kinds "<pack>.<name>"
	title = "Note"             # the row badge, the Add-menu entry, the dialog title

func fields() -> Array[Dictionary]:
	# The schema drives EVERYTHING: the auto-built add/edit dialog (a text field per
	# String, a checkbox per bool, a spinner per int/float) and default values.
	return [{"id": "text", "label": "Note", "type": TYPE_STRING, "default": ""}]

func emit(block: CustomBlockRow) -> PackedStringArray:
	# Pure: same fields, same bytes. This is the GDScript your block compiles to.
	var text: String = str(block.fields.get("text", "")).strip_edges()
	return PackedStringArray() if text.is_empty() else PackedStringArray(["## NOTE: %s" % text])

func lift(lines: PackedStringArray, i: int) -> Dictionary:
	# Claim source lines when a .gd opens as a sheet. verified_claim() re-emits your
	# recovered fields and drops the claim unless the bytes match the source exactly.
	if not lines[i].begins_with("## NOTE: "):
		return {}
	return verified_claim({"text": lines[i].substr(9)}, lines, i, 1)

func summary(block: CustomBlockRow) -> String:
	return str(block.fields.get("text", ""))  # the row's one-line display
```

That is the entire integration. Immediately:

- **Add ▾ → Note…** and **Ctrl+P → "Add Note…"** create one through a dialog built from the schema.
- Opening any `.gd` with a `## NOTE: tune this` line shows a highlighted **Note** row instead of prelude text.
- Double-clicking the row edits it; saving writes the exact same line back.

---

## 4. The Three Ways to Register a Kind

| Path | Best for | What you do | Effort |
|------|----------|-------------|--------|
| **1. Folder scan** | Packs and projects | Drop a script extending `EventSheetBlockKind` into `res://eventsheet_addons/` | Lowest: zero registration code |
| **2. Bridge (code)** | Other editor plugins/tools | `EventForgeBridgeRuntime.new().register_block_kind(my_kind)` | One call |
| **3. Built-in** | Contributing kinds into the plugin | Register in `EventSheetBlockRegistry._ensure_built_ins()` | Plugin PR |

Rules shared by all three:

- Duplicate `kind_id`s warn and keep the **first** registration; resolution is deterministic (the folder scan sorts paths).
- A pack kind without a `.` in its id gets a warning nudging the `<pack>.<name>` namespace.
- Kinds registered after startup (a freshly dropped pack, a bridge call) appear without a restart; the Add menu and palette re-read the registry on open.

---

## 5. The Kind Contract Reference

Everything a kind can implement. Only `kind_id`, `title`, and the pieces your kind needs are required; every method has a working default.

| Member | Kind type | What it does |
|--------|-----------|--------------|
| `kind_id: String` | both | The stable public id. Compatibility covenant once shipped. |
| `title: String` | both | The row badge text, the Add-menu entry, and the dialog title. |
| `category: String` | both | Add-menu grouping (default "Blocks"). |
| `fields() -> Array[Dictionary]` | schema | The schema: `{id, label, type: Variant.Type, default}` per field. Drives the auto-built dialog and defaults. |
| `emit(block) -> PackedStringArray` | schema | The GDScript this block compiles to. **Must be pure**: same fields, same bytes. Empty array emits nothing. |
| `lift(lines, i) -> Dictionary` | both | Claim source lines starting at `i`. Return `{}` (not yours), `{"fields": ..., "consumed": n}` (schema), or `{"resource": row, "consumed": n}` (resource kind). |
| `verified_claim(fields, lines, i, consumed)` | schema | The one-line byte gate for `lift()`: builds the candidate, re-emits it, returns the claim only on an exact byte match. |
| `summary(block) -> String` | schema | The row's one-line display next to the badge. |
| `hover_text(entry) -> String` | both | Optional hover tooltip: what the block *means*. BBCode renders styled; `""` keeps the default. |
| `handles(entry) -> bool` | resource | Claims a dedicated Resource class (`entry is EnumRow`). |
| `emit_lines(entry) -> PackedStringArray` | resource | Emission for a handled Resource instance. |
| `summary_for(entry) -> String` | resource | Display for a handled Resource instance. |
| `source_map_kind() -> String` | both | The tag line-to-row tooling sees (`"enum"`, default `"custom_block"`). |
| `addable() -> bool` | both | Whether the generic Add surfaces offer this kind. Resource kinds return `false` (their classes have dedicated flows). |
| `edit(dock, block) -> bool` | both | Open your own editor and return `true`, or return `false` for the generic schema dialog. |
| `validate(block) -> PackedStringArray` | schema | Optional problems for the diagnostics lane. |

`CustomBlockRow` itself has three stored properties: `kind_id`, `fields`, and `enabled`.

---

## 6. Schema Kinds vs Resource Kinds

**Schema kinds** are the normal case: instances are `CustomBlockRow`s, the dialog is generated from `fields()`, and you implement `emit`/`lift`/`summary`. Everything in the Quick Start is a schema kind.

**Resource kinds** exist so the plugin's own row classes run on the same registry, and they are available to you for the same reason: when a row type already has a dedicated Resource class and dialog, the kind wraps them instead of replacing them. The built-in **enum** and **signal** kinds work this way: `handles()` claims the class, `emit_lines()`/`summary_for()` produce the canonical line and display, `lift()` returns `{"resource": ...}`, `addable()` is `false` (the dedicated add flows stay), and `edit()` opens the dedicated dialog. The compiler, importer, viewport, and edit dispatch all resolve them through `EventSheetBlockRegistry.kind_for(entry)` exactly like schema kinds.

Reach for a resource kind only when you genuinely need a dedicated Resource class (rich sub-structures, existing saved sheets). A `fields` Dictionary covers almost everything else with far less code.

---

## 7. The UX Your Kind Gets for Free

- **Add ▾ menu**: every `addable()` kind is listed under its category; choosing it opens the schema dialog with defaults filled in.
- **Command palette**: Ctrl+P lists "Add <Title>…" for every addable kind, including ones registered after startup.
- **The schema dialog**: one field control per schema entry: a `LineEdit` per String (Enter applies), a `CheckBox` per bool, a `SpinBox` per int/float. Add mode inserts below the selection; edit mode (double-click the row) prefills and rewrites. Both apply through the undo system, so Ctrl+Z works.
- **The row**: a kind badge (your `title`) plus your `summary()` text, rendered by the same virtualized viewport as everything else. Disabled state and selection behave like built-in rows.
- **A custom editor when you outgrow the schema**: override `edit(dock, block)`, open anything you like, and return `true`. The registry dispatches every block edit, so your dialog is reached exactly the way the built-in enum dialog is.

---

## 8. Round-Trip Safety: The Byte Gate

The plugin's core promise is that opening a `.gd` and saving it untouched reproduces the file **byte-identically**. Custom blocks inherit that promise mechanically:

- `emit()` must be **deterministic**. No timestamps, no randomness, no environment reads. The importer and the compiler both rely on one canonical spelling per block state.
- `lift()` claims are gated: `verified_claim()` re-emits the recovered fields and compares against the consumed source lines. A mismatch drops the claim silently and the lines stay a verbatim GDScript block. **Degradation, never corruption.**
- Blocks emit **in position** on `.gd` sheets (the row's place in the sheet is the line's place in the file), so a lifted block writes back exactly where it came from.
- A hand-written variant your canon cannot reproduce (odd spacing, reordered arguments) is not an error: it round-trips verbatim as code, and your kind simply does not claim it.

The practical consequence: you cannot break a user's file with a bad kind. The worst a bug can do is fail to lift.

---

## 9. Built-in Kinds Reference

| Kind | `kind_id` | Emits | Notes |
|------|-----------|-------|-------|
| Preload Resource | `preload` | `const Name := preload("res://path")` | Schema kind; two fields (constant name, path). |
| Region | `region` | `#region Label` / `#endregion` (+ an optional `## @ace_region(#color, "description")` marker line above a styled opener) | Schema kind; fences are two independent single-line blocks. Matched pairs fold in the editor with a thin colored bubble around the range; the color and description edit in the fence's dialog. |
| Enum row | `enum` | `enum Name { A, B }` | Resource kind over `EnumRow`; dedicated dialog; not in Add surfaces. |
| Signal row | `signal` | `signal name(params)` | Resource kind over `SignalRow`; the trigger-annotation fold stays with the importer. |
| Note (demo) | `demo.note` | `## NOTE: text` | The shipped pack-kind example (`eventsheet_addons/demo_note_block.gd`). |

---

## 10. Use Cases

Brief sketches - each shows a kind's essence (fields in, GDScript out). The Quick Start above has the full class shape; every snippet here drops into it.

### 1. A TODO marker with an owner

**Scenario:** work items tagged `# TODO(sam): fix the jump arc` read as highlighted rows instead of buried comments.

```gdscript
func fields() -> Array[Dictionary]:
	return [{"id": "owner", "type": TYPE_STRING, "default": ""}, {"id": "task", "type": TYPE_STRING, "default": ""}]

func emit(block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray(["# TODO(%s): %s" % [block.fields.get("owner"), block.fields.get("task")]])
```

Note: keep the lift probe strict (exact `# TODO(...)` shape) - looser comments correctly stay plain comments.

### 2. A tuning-constant block

**Scenario:** designers tweak one gameplay constant per block, with a dialog instead of code.

```gdscript
func fields() -> Array[Dictionary]:
	return [
		{"id": "name", "label": "Constant", "type": TYPE_STRING, "default": "TUNING_VALUE"},
		{"id": "value", "label": "Value", "type": TYPE_FLOAT, "default": 1.0},
	]

func emit(block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray(["const %s: float = %s" % [str(block.fields.get("name", "")), str(float(block.fields.get("value", 0.0)))]])
```

Note: floats stringify canonically through `str(float(...))`, so the byte gate holds. If you need exact source spellings (like `0.5` vs `.5`), store the value as a String field instead.

### 3. A multi-line config table

**Scenario:** a pack needs a small dictionary in the sheet, editable as one block.

```gdscript
func emit(block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray([
		"const SPAWN_TABLE := {",
		"\t\"grunt\": %d," % int(block.fields.get("grunts", 3)),
		"\t\"boss\": %d," % int(block.fields.get("bosses", 1)),
		"}",
	])

func lift(lines: PackedStringArray, i: int) -> Dictionary:
	if lines[i] != "const SPAWN_TABLE := {" or i + 3 >= lines.size():
		return {}
	var grunt_probe: RegEx = RegEx.new()
	grunt_probe.compile("^\\t\"grunt\": (\\d+),$")
	var boss_probe: RegEx = RegEx.new()
	boss_probe.compile("^\\t\"boss\": (\\d+),$")
	var grunts: RegExMatch = grunt_probe.search(lines[i + 1])
	var bosses: RegExMatch = boss_probe.search(lines[i + 2])
	if grunts == null or bosses == null or lines[i + 3] != "}":
		return {}
	return verified_claim({"grunts": int(grunts.get_string(1)), "bosses": int(bosses.get_string(1))}, lines, i, 4)
```

Note: `consumed` is 4; `verified_claim` compares all four lines. Multi-line kinds work exactly like single-line ones.

### 4. Regions as chapter markers

**Scenario:** a long sheet reads better with named fences around each system.

```
Add ▾ → Region…  → "Movement"
  ... movement events ...
Add ▾ → Region…  → tick "Closing fence (#endregion)"
```

Note: fences are independent blocks on purpose; an unbalanced pair is a readability wart, never a parse error.

### 5. Preloads that designers manage

**Scenario:** the sound designer swaps audio files without touching code.

```
Add ▾ → Preload Resource… → Constant name: "HitSfx", Resource path: "res://sfx/hit.ogg"
Event: On Damaged
  Action: Play Audio -> HitSfx
```

### 6. A kind from another plugin

**Scenario:** your studio's dialogue plugin wants its cue table visible in event sheets.

```gdscript
# In the dialogue plugin's _enter_tree:
var cue_kind := DialogueCueBlockKind.new()
EventForgeBridgeRuntime.new().register_block_kind(cue_kind)
```

Note: bridge-registered kinds resolve exactly like folder-scanned ones; duplicate ids keep the first.

### 7. Notes as review markers

**Scenario:** a reviewer leaves `## NOTE:` lines while reading a teammate's compiled sheet in the script editor; the author sees them as highlighted rows in the sheet view and deletes them as they are addressed.

### 8. A debug toggle designers flip in a dialog

**Scenario:** `const DEBUG_DRAW := false` lives in the sheet as a checkbox block, not a line someone has to type correctly.

```gdscript
func fields() -> Array[Dictionary]:
	return [{"id": "enabled", "type": TYPE_BOOL, "default": false}]

func emit(block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray(["const DEBUG_DRAW := %s" % ("true" if bool(block.fields.get("enabled")) else "false")])
```

### 9. A scene requirement the Doctor enforces

**Scenario:** a block states `## REQUIRES: Camera2D child` in the sheet, and a pack-registered Doctor check reads the emitted line to flag scenes missing it.

```gdscript
func emit(block: CustomBlockRow) -> PackedStringArray:
	return PackedStringArray(["## REQUIRES: %s" % str(block.fields.get("requirement", ""))])

# Elsewhere, the pack teaches the Doctor to enforce it (see BUILDING-ON-EVENTSHEETS.md):
EventSheets.register_doctor_check("my_pack.requirements", _check_scene_requirements)
```

Note: the block and the health check ship together - the sheet documents the contract, the Doctor enforces it.

### Other uses at a glance

**License headers** as a one-field block that keeps the exact comment banner canonical across every generated file. **Signal-bus wiring notes** that document which autoload signals a sheet listens to. **Version stamps** for packs, one canonical `const PACK_VERSION := "1.2"` line each. **Spawn-point manifests** listing marker names a level script reads. **Asset checklists** that name the sounds and textures an event section expects.

---

## 11. Testing Custom Blocks

The pattern the built-ins use, runnable headlessly:

```gdscript
# 1. Registration.
assert(EventSheetBlockRegistry.get_kind("team.todo") != null)

# 2. Round-trip: emit -> import -> byte-identical recompile.
var source := "extends Node\n\n# TODO(sam): fix the jump arc\n"
var sheet := GDScriptImporter.new().import_external_source(source)
sheet.external_source_path = "user://todo_test.gd"
var lifted_kinds: Array = []
for entry in sheet.events:
	if entry is CustomBlockRow:
		lifted_kinds.append(entry.kind_id)
assert(lifted_kinds == ["team.todo"])
assert(str(SheetCompiler.compile(sheet, "user://todo_test.gd").get("output", "")) == source)

# 3. The near-miss stays raw (the byte gate working).
var hostile := GDScriptImporter.new().import_external_source("extends Node\n\n# todo: lowercase\n")
for entry in hostile.events:
	assert(not (entry is CustomBlockRow))
```

Run tests with `godot --headless --path . --script tests/run_tests.gd`; any script in `tests/` with a `static func run() -> bool` is auto-discovered.

---

## 12. Tips and Common Mistakes

- **Emission must be deterministic.** A timestamp or random value in `emit()` breaks the byte gate and your kind will never lift. Same fields, same bytes, always.
- **`kind_id` is frozen once shipped.** Sheets store it. Rename by shipping a new kind and keeping the old one registered.
- **Namespace pack kinds** (`my_pack.thing`). Un-namespaced ids from the folder scan get a warning and risk collisions.
- **Read fields with defaults**: `block.fields.get("id", default)`. Blocks saved before your kind gained a field must keep working. Removing a field is a compat break; deprecate the kind instead.
- **Kinds are stateless singletons.** One instance serves every sheet for the whole session. Per-block data lives ONLY in `CustomBlockRow.fields`.
- **Lift claims start at column 0, top level.** The importer probes unclaimed top-level lines; lines inside function bodies belong to their function's block and are never offered to kinds.
- **Strict lifts are good lifts.** Claim exactly your canonical shape and nothing else. The byte gate protects files either way, but a tight probe keeps behavior predictable.
- **Do not quote user text blindly.** Field values containing `"` would break emitted string literals; either reject them in `emit()` (return empty) or escape them consistently in both `emit` and `lift`.
- **The dedicated probes run first.** Variables, enums, and signals are claimed by their own probes before generic kinds see a line, so your kind cannot accidentally shadow a built-in row type.
