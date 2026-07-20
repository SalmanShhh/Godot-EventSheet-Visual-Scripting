# Building on EventSheets

Everything an extension needs lives in **one class: `EventSheets`** (`addons/eventsheet/api/eventsheets.gd`). It is all static, so any `@tool` script, editor plugin, or test can call it with zero setup: register new vocabulary, drive the live editor, use the compiler and importer as plain services, or plug into the Project Doctor. Every method on it is a compatibility promise, the same covenant `ace_id`s and codegen templates carry: shapes are stable once shipped, new capabilities get added, existing ones are never renamed. The plugin dogfoods this API itself (the region fold commands in the Command Palette and the MCP server's compile and import tools go through it), so the extension path is the exact path the built-ins take.

![Vocabulary registered through the EventSheets API appears in the picker exactly like the built-ins - same live search, favorites and recents rails, and Ships-as GDScript preview](previews/editor-ace-picker.png)

## Table of Contents

1. [What You Can Build](#1-what-you-can-build)
2. [The One-Minute Tour](#2-the-one-minute-tour)
3. [Vocabulary Services](#3-vocabulary-services)
4. [Editor Services](#4-editor-services)
5. [Codegen Services](#5-codegen-services)
6. [Project Health Services](#6-project-health-services)
6b. [Localisation Services](#6b-localisation-services)
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
| `register_provider_script(path)` | A `@tool class_name` script becomes an ACE provider: public methods, signals, and `@export` vars become actions, conditions, expressions, and triggers. Annotate with `@ace_*` doc tokens or a static `_eventforge_register(reg)` hook (both dialects are covered in [GUIDE-CUSTOM-ACES.md](GUIDE-CUSTOM-ACES.md)). |
| `register_block_kind(kind)` | A new NON-ACE row type (markers, notes, data tables). The kind gets the Add menu, palette, edit dialog, compile and lift wiring for free; the contract is in [GUIDE-CUSTOM-BLOCKS.md](GUIDE-CUSTOM-BLOCKS.md). |
| `simple_block_kind(config)` | Build a whole block kind from a Dictionary (an `emit` template with `{field}` placeholders, a `summary` template, a `fields` schema) with NO subclassing. Forward emission works immediately; reverse recovery is opt-in via a `lift` Callable, else the block re-imports as a verbatim GDScript block. Pass the result to `register_block_kind()`. |
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

**Asset drops.** Files dragged from the FileSystem dock onto the sheet canvas become pre-filled rows, and the mapping is a registry you can extend. `register_asset_drop_handler(extensions, build)` takes a builder `build(asset_path: String, target_event: Resource) -> Resource`; registering it also lights up the drop cursor for those extensions with no other wiring. Return an `ACEAction` and it joins the event row the file landed on (or a fresh On Ready event on an empty-space drop) - an effect is always an action. Return any other row resource (a preload `CustomBlockRow`, a `RawCodeRow`) and it lands at the sheet's top level as a declaration. Return `null` to decline. The built-ins run through this same seam: scenes spawn, sounds play, images and `.tres`/`.res`/`.gd` become preload blocks (a `const` that compiles on any host), and JSON loads into a variable (auto-declared so the sheet always compiles). Registering a handler registers the built-ins first, so retargeting a built-in extension wins (last registration wins). The dock never lets a dropped preload redefine an existing name (deduped by path, suffixed on clash).

```gdscript
# A .dialogue file starts a conversation when dropped on an event.
EventSheets.register_asset_drop_handler(PackedStringArray(["dialogue"]),
	func(asset_path: String, _target: Resource) -> Resource:
		return EventSheets.builtin_action("SetVar", {"var_name": "conversation", "value": "load(%s)" % ("\"%s\"" % asset_path)}))
```

Two helpers do the heavy lifting inside a builder: `builtin_action(ace_id, params)` builds a picker-identical action from any built-in Core descriptor (`{uid}` baked fresh), and `preload_block_for(asset_path)` builds a `const Name := preload("res://...")` Custom Block row with a safe constant name.

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

## 6b. Localisation Services

The editor UI translates through one shared layer (see the "Translating the editor into your
language" guide for the drop-in CSV format). Anything you show through a Control translates
automatically - the dock's translation domain covers your dialogs and buttons too. For strings
you draw or format yourself, route them through the API and they localise the day someone
provides a translation (a pass-through in the default English):

```gdscript
# Translate any display string (English default; falls back to the source text).
canvas.draw_string(font, position, EventSheets.translate("Nothing selected"), ...)

# Ship translations WITH your pack - your ACE display names and Custom Block titles are
# looked up through the same layer in the picker and menus.
EventSheets.register_translation_file("res://addons/my_pack/translations/my_pack.csv")
```

Never translate ids (`ace_id`, `kind_id`, provider ids): they are compatibility contracts.
Display strings only.

## 6c. Save Support Services

A node joins the project's save system by exposing two plain methods - `save_state() -> Dictionary` and `load_state(state)` - which the Save System duck-types (no base class, no registration). These services let your extension GENERATE that seam, detect it, and preview how a snapshot lands on disk. They are dock-free, so a build tool or a test can use them. The built-in **Save Studio** is written entirely on this surface, so anything it does, your tooling can do too.

```gdscript
# Generate the seam pair for a set of fields (keys drop a leading underscore, collections
# deep-copy, loads coerce by type and tolerate a missing key). Paste the result into a script.
var seam: String = EventSheets.save_state_code([
	{"name": "_wallet", "type": "Dictionary"}, {"name": "level", "type": "int"}])

# Or let it choose: scan a script's plain-data fields (skipping node/resource references)
# and generate for the recommended ones in one call.
var ready_to_paste: String = EventSheets.add_save_support("res://addons/my_pack/hoard.gd")

# Inspect what a scan found, to build your own picker (each is {name, type, recommended}).
for field: Dictionary in EventSheets.persistable_fields("res://addons/my_pack/hoard.gd"):
	print(field["name"], " ", field["type"], " keep=", field["recommended"])

# Does something already persist? Works on a path, a Script, or a live Node.
if EventSheets.has_save_support($Enemy):
	pass

# Show what a save will look like on disk BEFORE committing to a format.
var preview: String = EventSheets.preview_save({"level": 5, "pos": Vector2(3, 4)}, "json")

# Enumerate the bundled packs that already ship the seam.
for pack_gd: String in EventSheets.save_capable_scripts():
	print(pack_gd)
```

`save_state_code` follows the repo convention exactly (int/float/bool/String/Dictionary/Array coercion, anything else passes through), and the generated pair is valid GDScript that round-trips a live node. `preview_save` runs the REAL Save System backend for the given format (`"config"`, `"json"`, `"binary"`, `"csv"`), so the text you show is byte-for-byte what ships - all four formats preserve exact types. When `eventsheet_addons/save_system/` is not installed, `preview_save` returns an explanatory line and `save_capable_scripts` returns empty rather than erroring.

## 7. Full Reference

| Group | Method | Returns | Needs dock? |
|-------|--------|---------|-------------|
| Vocabulary | `register_provider_script(script_path: String)` | `bool` | no (bridges when closed) |
| Vocabulary | `register_block_kind(kind: EventSheetBlockKind)` | `void` | no |
| Vocabulary | `simple_block_kind(config: Dictionary)` | `EventSheetBlockKind` | no |
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
| Codegen | `new_sheet(config: Dictionary = {})` | `EventSheetResource` | no |
| Codegen | `compile(sheet: EventSheetResource, output_path := "")` | `Dictionary` | no |
| Codegen | `variable_code(variable: LocalVariable)` | `String` | no |
| Codegen | `open_gd_as_sheet(source: String)` | `EventSheetResource` | no |
| Codegen | `round_trips(source: String)` | `bool` | no |
| Codegen | `publish_pack(sheet, base_path, icon_path := "")` - the whole pack pipeline (icon detect, de-coding lifts, stable uids, banner-less compile); shared by the bundled builders and Export Addon | `Dictionary` | no |
| Codegen | `stabilize_row_uids(sheet)` - deterministic row uids so regeneration is byte-stable | `void` | no |
| Codegen | `resource_grid(columns, options := {})` - the Inspector-grid descriptor from plain column phrases ("kind: a|b|c" = a dropdown) | `Dictionary` | no |
| Codegen | `attach_validator(sheet, variable_name)` - creates validate_<variable>() and wires the live-warning attribute | `String` | no |
| Save | `save_state_code(fields: Array)` | `String` | no |
| Save | `persistable_fields(script_path: String)` | `Array[Dictionary]` | no |
| Save | `has_save_support(target)` (path / Script / Node) | `bool` | no |
| Save | `add_save_support(script_path: String)` | `String` | no |
| Save | `save_capable_scripts()` | `PackedStringArray` | no |
| Save | `preview_save(data: Dictionary, format: String, key := "state")` | `String` | no |
| Health | `doctor()` | `Dictionary` | no |
| Health | `register_doctor_check(check_id: String, check: Callable)` | `void` | no |
| Health | `unregister_doctor_check(check_id: String)` | `void` | no |
| Seams | `register_row_menu_item(label, filter, action)` / `unregister_row_menu_item(label)` | `void` | no (shows when open) |
| Seams | `register_simple_ace(config: Dictionary)` / `simple_ace(config)` | `ACEDefinition` | no (joins next refresh) |
| Seams | `register_param_editor(tag: String, factory: Callable)` | `void` | no |
| Seams | `on_sheet_opened/saved/compiled(callback: Callable)` | `void` | no |
| Seams | `register_starter({label, build})` | `void` | no |
| Seams | `register_quick_add_synonyms(map: Dictionary)` | `void` | no |
| Seams | `register_section_description(name, blurb)` | `void` | no |
| Seams | `register_preference(builder: Callable)` | `void` | no |
| Seams | `register_tour(name, steps)` / `start_tour(steps)` | `void` / `bool` | start needs dock |
| Seams | `register_editor_preview(script_path, sampler)` / `editor_preview_sampler_for(script_path)` | `void` / `Callable` | no |
| Seams | `register_editor_gizmo(script_path, drawer)` / `editor_gizmo_drawer_for(script_path)` | `void` / `Callable` | no |
| Editor | `add_trigger_for_signal(signal_name, args_signature)` | `bool` | yes |
| Vocabulary | `build_signal_trigger_event(signal_name, args_signature)` / `signals_of(node)` | `EventRow` / `Array[Dictionary]` | no |
| Seams | `register_asset_drop_handler(extensions, build, description := "")` - files dropped on the canvas become rows (actions join the hit event; other rows land top-level) | `void` | no (fires when open) |
| Seams | `asset_drop_builder_for(extension)` / `handled_asset_extensions()` | `Callable` / `PackedStringArray` | no |
| Seams | `builtin_action(ace_id, params)` - a picker-identical ACEAction from a built-in descriptor, {uid} baked | `ACEAction` | no |
| Seams | `preload_block_for(asset_path)` - a preload Custom Block row with a safe constant name | `CustomBlockRow` | no |
| Seams | `preview_behaviors()` | `bool` | yes |
| Seams | `verify_pack(pack_gd_path: String)` | `Dictionary` | no |
| Localisation | `translate(text: String)` | `String` | no |
| Localisation | `register_translation_file(path: String)` | `bool` | no |
| Localisation | `available_languages()` | `PackedStringArray` | no |
| Localisation | `set_editor_language(locale: String)` | `void` | no |

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

### 9. A jam-day "strip the debug residue" cleanup command

**Scenario:** it is the last hour of a game jam and print statements are scattered across the sheet; one palette command deletes every debug Print row so the build ships clean.

```gdscript
EventSheets.register_palette_command("Strip Debug Prints", func() -> void:
	var removed: bool = EventSheets.edit("Strip Debug Prints", func(sheet: EventSheetResource) -> bool:
		var before: int = sheet.events.size()
		sheet.events = sheet.events.filter(func(row: Resource) -> bool: return not _is_debug_print(row))
		return sheet.events.size() != before)
	EventSheets.set_status("Debug prints removed." if removed else "No debug prints found."))
```

### 10. A team style pin in CI so emission never drifts

**Scenario:** your team standardises on one weapon pack; a CI test compiles a canonical sheet and pins the exact output string, so an accidental template edit fails the merge before it reaches anyone.

```gdscript
var result: Dictionary = EventSheets.compile(_canonical_weapon_sheet())
ok = _check("weapon emission is frozen", result["output"], _golden_weapon_source) and ok
```

### 11. An Inspector preview inside your pack's setup dialog

**Scenario:** your loot pack's config dialog lets a designer set a drop-rate variable, and you show the live Inspector mock with its range drawer so they see exactly how the field will look and what it ships as before they commit.

```gdscript
var attrs: Dictionary = {"range": {"min": "0", "max": "1"}, "drawer": "progress_bar", "header": "Loot"}
dialog.add_child(EventSheets.build_inspector_preview("drop_rate", "float", "0.25", attrs))
dialog.hint_label.text = EventSheets.describe_inspector("float", attrs)
```

### 12. A migration codemod that renames a retired verb

**Scenario:** you deprecated an old inventory action and shipped a replacement; a one-shot palette command rewrites every affected row across the open sheet in a single undo step, so upgrading a project is one click, not a manual find-and-replace.

```gdscript
EventSheets.edit("Migrate Inventory Verbs", func(sheet: EventSheetResource) -> bool:
	var changed: bool = false
	for row: Resource in sheet.events:
		changed = _rewrite_legacy_inventory_ace(row) or changed
	return changed)
```

### 13. A pre-merge round-trip sweep over every hand-edited script

**Scenario:** a teammate hand-edited some generated `.gd` files; a headless CI script re-imports each one and asserts it still round-trips, catching any edit that would corrupt on the next open before it lands on main.

```gdscript
# headless: godot --headless --path . --script roundtrip_sweep.gd
for path: String in _all_sheet_scripts():
	var source: String = FileAccess.get_file_as_string(path)
	if not EventSheets.round_trips(source):
		push_error("Round-trip broke: %s" % path)
		quit(1)
```

### 14. Make your behavior animate in the editor (Preview Behaviors)

**Scenario:** your pack ships an oscillating or orbiting motion behavior and you want users to see it move in the editor viewport - select the node, run Tools > Preview Behaviors on Selected Node, watch it go, and get the node back exactly where it was when the preview stops.

A behavior opts in by shipping one pure static on its script (in a pack builder, add it as a raw
GDScript block - the bundled Sine behavior does exactly this):

```gdscript
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	# params = the behavior node's exported values as the Inspector shows them right now.
	# base   = the host's rest state ({"position", "rotation", "scale", "modulate"}).
	# Return the host properties for this frame; {} means "leave the host alone".
	var angle := time * float(params.get("speed_degrees", 90.0)) * (PI / 180.0)
	return {"position": (base.get("position") as Vector2) + Vector2.from_angle(angle) * float(params.get("radius", 40.0))}
```

The editor drives the preview at 30 samples a second, re-reads `params` every tick (so tweaking
a knob in the Inspector re-shapes the motion live), and restores every property it touched when
the preview stops - the scene's saved bytes are never affected. The static runs WITHOUT the
behavior executing, so it works on plain (non-@tool) pack scripts.

For a script you cannot edit (third-party, or generated code you do not control), register the
sampler externally instead - it takes priority over the static:

```gdscript
EventSheets.register_editor_preview("res://addons/thirdparty/bob.gd",
	func(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
		return {"position": (base.get("position") as Vector2) + Vector2(0.0, sin(time * TAU) * 8.0)})
```

**Editor gizmos** are the preview seam's sibling for STATIC setup: instead of animating the
host over time, the behavior draws its configuration in the 2D viewport while its node is
selected - a bounds rectangle, a sight cone, a patrol route. Ship a second pure static:

```gdscript
static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void:
	# params: the behavior node's script variables (exported knobs AND internal state), live.
	# canvas: a transient child of the host - plain draw_* calls paint in HOST-LOCAL space.
	# For world-space shapes, draw through the host's inverse transform first:
	canvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())
	canvas.draw_rect(params.get("patrol_area", Rect2()), Color.CYAN, false, 2.0)
```

Selecting the host draws every opted-in child behavior; selecting the behavior node draws just
that one. The canvas is an owner-less transient child (never saved into the scene) that
repaints every frame, so Inspector tweaks and host movement track live. The Bound To pack
ships one - select any bound node and the bound rectangle appears, with a dashed inner line
showing where the origin can reach under edge binding. For scripts you cannot edit, register
the drawer externally with `EventSheets.register_editor_gizmo(script_path, drawer)` - same
signature, takes priority over the static.

### 15. Add save support to your pack's node with one call

**Scenario:** your pack ships a behavior that holds runtime state (a stat pool, a cooldown, an owned-items dictionary) and you want it to survive a save. A setup command scans the script and drops the generated `save_state`/`load_state` pair on the clipboard, so wiring persistence in is paste-and-done - the same generator the built-in Save Studio uses.

```gdscript
EventSheets.register_palette_command("My Pack: Add Save Support", func() -> void:
	var seam: String = EventSheets.add_save_support("res://addons/my_pack/hoard.gd")
	DisplayServer.clipboard_set(seam)
	EventSheets.set_status("Save-support seam copied - paste it into hoard.gd."))
```

And a Doctor check that flags a pack node holding obvious state but shipping no seam, so a persistence gap surfaces in CI instead of at a player's "why didn't my progress save":

```gdscript
EventSheets.register_doctor_check("my_pack.needs_save_support", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var hoard := "res://addons/my_pack/hoard.gd"
	if not EventSheets.persistable_fields(hoard).is_empty() and not EventSheets.has_save_support(hoard):
		findings.append({"severity": "info", "check": "my_pack.needs_save_support",
			"path": hoard, "message": "Holds state but has no save_state/load_state seam."}))
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
