# Building on EventSheets

Everything an extension needs lives in **one class: `EventSheets`** (`addons/eventsheet/api/eventsheets.gd`). It is all static, so any `@tool` script, editor plugin, or test can call it with zero setup: register new vocabulary, drive the live editor, use the compiler and importer as plain services, or plug into the Project Doctor. Every method on it is a compatibility promise, the same covenant `ace_id`s and codegen templates carry: shapes are stable once shipped, new capabilities get added, existing ones are never renamed. The plugin dogfoods this API itself (the region fold commands in the Command Palette and the MCP server's compile and import tools go through it), so the extension path is the exact path the built-ins take.

## Table of Contents

1. [What You Can Build](#1-what-you-can-build)
2. [The One-Minute Tour](#2-the-one-minute-tour)
3. [Vocabulary Services](#3-vocabulary-services)
4. [Editor Services](#4-editor-services)
5. [Codegen Services](#5-codegen-services)
6. [Project Health Services](#6-project-health-services)
7. [Full Reference](#7-full-reference)
8. [Use Cases](#8-use-cases)
9. [Testing Your Extension](#9-testing-your-extension)
10. [Tips and Common Mistakes](#10-tips-and-common-mistakes)

---

## 1. What You Can Build

- **A vocabulary pack from another plugin.** Your editor plugin registers a provider script and a custom block kind in its `_enter_tree()`; EventSheets users get your verbs and rows with no files copied anywhere.
- **A Command Palette power tool.** "Sort events by trigger", "Insert my team's standard header", "Renumber TODO comments": register a command, mutate the sheet through `edit()`, and it lands as one undo step.
- **A sheet linter or codemod.** Walk `current_sheet().events`, rewrite what you find inside `edit()`, report through `set_status()`.
- **Headless tooling.** A CI script that compiles every sheet in a project, or byte-verifies that hand-edited GDScript still round-trips, using `compile()` / `round_trips()` with no editor open at all.
- **A custom emission you can trust.** Building a block kind or tweaking what your pack emits? `round_trips(source)` is the same gate every built-in lift must pass; put it in your own tests.
- **A health check that ships with your pack.** Your dialogue pack knows what a broken dialogue setup looks like ("this .dialogue file is referenced but missing"). Register a Doctor check and the warning appears in the Doctor panel, the CLI, CI and MCP, right next to the built-in checks.

## 2. The One-Minute Tour

```gdscript
@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Add vocabulary: this script's methods/signals/@exports become ACEs.
	EventSheets.register_provider_script("res://addons/my_pack/my_provider.gd")

	# Add an editor command: one undo step, refresh and dirty-mark handled.
	EventSheets.register_palette_command("Add Session Header", func() -> void:
		EventSheets.edit("Add Session Header", func(sheet: EventSheetResource) -> void:
			var comment: CommentRow = CommentRow.new()
			comment.text = "Session: %s" % Time.get_date_string_from_system()
			sheet.events.insert(0, comment))
		EventSheets.set_status("Header added."))


func _exit_tree() -> void:
	EventSheets.unregister_palette_command("Add Session Header")
```

That is the whole integration surface: no dock lookups, no signal wiring, no internal paths.

## 3. Vocabulary Services

These add words to the event sheet language. They work with or without the editor open.

| Method | What it does |
|--------|----------------|
| `register_provider_script(path)` | A `@tool class_name` script becomes an ACE provider: public methods, signals, and `@export` vars become actions, conditions, expressions, and triggers. Annotate with `@ace_*` doc tokens or a static `_eventforge_register(reg)` hook (both dialects are covered in [CUSTOM-ACES-GUIDE.md](CUSTOM-ACES-GUIDE.md)). |
| `register_block_kind(kind)` | A new NON-ACE row type (markers, notes, data tables). The kind gets the Add menu, palette, edit dialog, compile and lift wiring for free; the contract is in [CUSTOM-BLOCKS-GUIDE.md](CUSTOM-BLOCKS-GUIDE.md). |
| `find_ace(provider_id, ace_id)` | Look a definition up in the live registry (editor only). Definitions are session-cached and shared: treat them as IMMUTABLE, bake changes into row copies. |
| `class_vocabulary(target_class)` | Reflect ANY class (engine or `class_name` script) into browsable ACE definitions on demand: methods classify by return type, signals become triggers, properties become Set/Get pairs. |

## 4. Editor Services

These drive the live editor. They require the EventSheet dock to be open and no-op safely otherwise (`null` / `false` returns), so the same script works headless.

**The one rule of mutation:** all sheet changes go through `edit(label, mutation)`. Your callable receives the live `EventSheetResource`; the whole change becomes ONE undo step named `label`, and the API refreshes the rows and marks the sheet dirty for you. The undo funnel's commit REPLACES resources with snapshot duplicates, so never cache a row or resource across calls: re-fetch from `current_sheet()` every time. Return `false` from the mutation to say "nothing changed" (no undo step gets created).

```gdscript
# A codemod: upper-case every comment row. One undo step, re-fetch built in.
EventSheets.edit("Shout Comments", func(sheet: EventSheetResource) -> bool:
	var changed: bool = false
	for row: Resource in sheet.events:
		if row is CommentRow:
			(row as CommentRow).text = (row as CommentRow).text.to_upper()
			changed = true
	return changed)
```

Palette commands are the discoverability seam: `register_palette_command(title, action)` puts your tool in Ctrl+P next to the built-ins (re-register the same title to replace it, `unregister_palette_command` to remove it). Registration works even before a dock exists; entries appear once a palette opens.

## 5. Codegen Services

The compiler and importer as plain services, dock-free, usable from tests and CI:

```gdscript
# GDScript in, sheet out, GDScript back: the lossless external path.
var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source_text)
var result: Dictionary = EventSheets.compile(sheet)
print(result["output"])       # the emitted GDScript
print(result["success"])      # plus "errors", "warnings", "source_map"

# The byte gate as a one-liner: does import -> re-emit reproduce the source exactly?
assert(EventSheets.round_trips(source_text))
```

`open_gd_as_sheet()` is the same lift the editor uses when you open a `.gd` file: everything liftable lifts, everything else stays a verbatim block, and nothing can be corrupted. `round_trips()` is the covenant check itself; if your custom block kind or provider changes emission, pin it with this in a test.

### The Inspector toolkit

The rich-inspector system (drawers, decor, grouping, ranges) is a service too, so your dialogs and tools show the SAME previews the editor does:

```gdscript
# The live Inspector mock (decor, group heading, widget miniature, plain sentence) as a Control.
var attrs: Dictionary = {"range": {"min": "0", "max": "100"}, "drawer": "progress_bar", "header": "Combat"}
my_panel.add_child(EventSheets.build_inspector_preview("armour", "int", "10", attrs))

# The same choices as one sentence (tooltips, logs, docs):
print(EventSheets.describe_inspector("int", attrs))

# The exact GDScript a variable compiles to - its "Ships as:" truth:
print(EventSheets.variable_code(my_local_variable))
```

## 6. Project Health Services

The Project Doctor audits every sheet in the project (stale generated outputs, compile failures, debug residue, wiring gaps, vocabulary hygiene) and reports through the dock's Tools menu, the headless CLI, CI and the MCP `run_doctor` tool. The API gives you both directions:

```gdscript
# Run the whole audit (dock-free; usable from CI scripts and tests).
var report: Dictionary = EventSheets.doctor()
print("%d error(s), %d warning(s)" % [report["errors"], report["warnings"]])

# Ship your own check: it runs after the built-ins, everywhere the Doctor runs.
EventSheets.register_doctor_check("my_pack.missing_tables", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if _uses_my_pack_without_a_table(sheet_path):
			findings.append({"severity": "warning", "check": "my_pack.missing_tables",
				"path": sheet_path, "message": "Uses my_pack but defines no drop table."}))
```

A check receives every non-template sheet path plus the shared findings array, and appends findings shaped `{"severity": "error"|"warning"|"info", "check": <your id>, "path": ..., "message": ...}`. Severity decides consequence: errors fail CI, warnings fail `--strict` CI, infos are advisory. The Doctor covenant applies to your check too: **never write inside res://** (verification work goes to `user://` scratch files). Re-registering an id replaces the previous check, so plugin reloads never duplicate; `unregister_doctor_check(id)` removes it.

## 7. Full Reference

| Group | Method | Returns | Needs dock? |
|-------|--------|---------|-------------|
| Vocabulary | `register_provider_script(script_path: String)` | `bool` | no (bridges when closed) |
| Vocabulary | `register_block_kind(kind: EventSheetBlockKind)` | `void` | no |
| Vocabulary | `find_ace(provider_id: String, ace_id: String)` | `ACEDefinition` | yes |
| Vocabulary | `class_vocabulary(target_class: String)` | `Array[ACEDefinition]` | no |
| Editor | `current_sheet()` | `EventSheetResource` | yes |
| Editor | `open_sheet(path: String)` | `bool` | yes |
| Editor | `edit(label: String, mutation: Callable)` | `bool` (changed) | yes |
| Editor | `set_status(text: String, is_error := false)` | `void` | yes |
| Editor | `refresh()` | `void` | yes |
| Editor | `register_palette_command(title: String, action: Callable)` | `void` | no (shows when open) |
| Editor | `unregister_palette_command(title: String)` | `void` | no |
| Editor | `palette_commands()` | `Array[Dictionary]` | no |
| Editor | `build_inspector_preview(name, type_name, default_text, attributes, exported := true, constant := false)` | `Control` | no |
| Editor | `describe_inspector(type_name, attributes, exported := true, constant := false)` | `String` | no |
| Codegen | `compile(sheet: EventSheetResource, output_path := "")` | `Dictionary` | no |
| Codegen | `variable_code(variable: LocalVariable)` | `String` | no |
| Codegen | `open_gd_as_sheet(source: String)` | `EventSheetResource` | no |
| Codegen | `round_trips(source: String)` | `bool` | no |
| Health | `doctor()` | `Dictionary` | no |
| Health | `register_doctor_check(check_id: String, check: Callable)` | `void` | no |
| Health | `unregister_doctor_check(check_id: String)` | `void` | no |

`compile()`'s Dictionary keys: `"output"` (the source text: this key, not "source"), `"success"`, `"errors"`, `"warnings"`, `"source_map"`. `doctor()`'s: `"findings"` (each `{severity, check, path, message}`), `"errors"`, `"warnings"`, `"infos"`.

## 8. Use Cases

Brief sketches - each is one real pattern, ready to adapt.

### 1. A palette command that stamps a session header

**Scenario:** every work session starts with a dated comment at the top of the sheet.

```gdscript
EventSheets.register_palette_command("Add Session Header", func() -> void:
	EventSheets.edit("Add Session Header", func(sheet: EventSheetResource) -> void:
		var comment: CommentRow = CommentRow.new()
		comment.text = "Session: %s" % Time.get_date_string_from_system()
		sheet.events.insert(0, comment)))
```

### 2. A CI script that health-checks the whole project

**Scenario:** the build server fails a merge when any sheet drifted from its generated script.

```gdscript
# headless: godot --headless --path . --script ci_check.gd
var report: Dictionary = EventSheets.doctor()
quit(1 if int(report.get("errors", 0)) > 0 else 0)
```

### 3. Byte-gating your pack's emission in its own tests

**Scenario:** your custom block kind changes its emit(); the pack's test proves no user file can ever corrupt.

```gdscript
ok = _check("my block round-trips", EventSheets.round_trips(fixture_source), true) and ok
```

### 4. A Doctor check that ships with your pack

**Scenario:** your dialogue pack knows a broken setup when it sees one - and says so in every Doctor runner.

```gdscript
EventSheets.register_doctor_check("dialogue.missing_files", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if _references_missing_dialogue(sheet_path):
			findings.append({"severity": "warning", "check": "dialogue.missing_files", "path": sheet_path, "message": "References a .dialogue file that does not exist."}))
```

### 5. Registering your plugin's vocabulary on load

**Scenario:** your editor plugin adds verbs to every project it is installed in - no files copied.

```gdscript
func _enter_tree() -> void:
	EventSheets.register_provider_script("res://addons/my_plugin/my_verbs.gd")
```

### 6. A one-shot codemod over the open sheet

**Scenario:** an audio rebalance halves every Play Sound volume in the sheet - one undo step.

```gdscript
EventSheets.edit("Halve Sound Volumes", func(sheet: EventSheetResource) -> bool:
	var changed: bool = false
	for row: Resource in sheet.events:
		changed = _halve_volumes_in(row) or changed
	return changed)
```

### 7. A tool UI built from reflected vocabulary

**Scenario:** your custom dock lists everything a selected node class can do, using the same definitions the picker shows.

```gdscript
for definition: ACEDefinition in EventSheets.class_vocabulary("CharacterBody2D"):
	list.add_item("%s  (%s)" % [definition.display_name, definition.category])
```

### 8. Jump-open a sheet from your own panel

**Scenario:** your quest tool deep-links from a quest entry to the sheet that implements it.

```gdscript
if EventSheets.open_sheet("res://quests/rescue_quest.gd"):
	EventSheets.set_status("Opened the Rescue quest sheet.")
```

## 9. Testing Your Extension

The plugin's own API test (`tests/eventsheets_api_test.gd`) is a working template: codegen and vocabulary pins run dock-free; editor pins build a real dock (`EventSheetEditor.new()` then `setup(sheet)`) with a fake undo manager. For your extension, the highest-value pins are:

- **Emission stability:** compile a small hand-built sheet using your vocabulary and pin the exact output string.
- **The byte gate:** `EventSheets.round_trips(fixture_source)` for every shape your block kind claims to lift.
- **Palette presence:** after registration, your title appears in `EventSheets.palette_commands()`.
- **Doctor findings:** register your check, run `EventSheets.doctor()` over a fixture project state, and pin that your finding appears with the right severity.

## 10. Tips and Common Mistakes

- **Never reach past the facade.** Dock internals (`_` members) move between releases; the extraction refactors rename and relocate them freely. `EventSheets` is the only surface with a stability promise.
- **Never cache rows across `edit()` calls.** Undo commits replace resources with snapshot duplicates. The row you held is now detached from the sheet; re-fetch from `current_sheet()`.
- **Return `false` for no-ops.** An `edit()` mutation that changed nothing should say so, or the user gets an undo step that does nothing.
- **Definitions are immutable.** `find_ace()` and `class_vocabulary()` hand you session-cached shared instances. Mutating one changes it for every tab; bake per-row changes into the row's own fields instead.
- **`compile()` result key is `"output"`.** Reading `"source"` gets you an empty string that compares equal to other empty strings, which makes broken tests pass.
- **Palette titles are the identity.** Re-registering a title replaces the old command, so a plugin reload never duplicates entries; pick titles that read like actions ("Fold All Regions").
