# Making Custom Editor Tools with Event Sheets

Most of the time an event sheet compiles to a game script that runs when you press Play. A **Tool sheet** is different: it compiles to `@tool` + `extends EditorScript` + a `func _run()`, and it runs **inside the Godot editor** while you are building your game. Instead of hand-writing an `EditorScript`, you drop in events - "add ten crates to this scene", "turn the selected node into a reusable scene", "generate a data file and refresh the FileSystem" - and press Run. This guide takes you from zero to a working editor tool, then shows how to reach the plugin's own public API when you want to extend the editor itself.

You do not need to have written an `EditorScript` before. If you can build an ordinary event sheet, you can build a tool.

## Table of Contents

1. [What You Can Build](#1-what-you-can-build)
2. [Your First Tool Sheet](#2-your-first-tool-sheet)
3. [The Editor Tools ACEs](#3-the-editor-tools-aces)
4. [Interfacing with the EventSheets API](#4-interfacing-with-the-eventsheets-api)
5. [Use Cases](#5-use-cases)
6. [Tips and Common Mistakes](#6-tips-and-common-mistakes)

---

## 1. What You Can Build

A Tool sheet is for **automating edits you would otherwise do by hand**:

- **Scene builders.** Spawn a grid of placeholder crates, drop a fixed set of markers into the level you are editing, or lay out a UI skeleton - all as nodes that save with the scene.
- **"Turn this into a scene" tools.** Pack the node you have selected (with its children) into a reusable `.tscn`.
- **Data generators.** Build a `.tres` resource from a template and write it to disk, then refresh the FileSystem so it shows up immediately.
- **Project scaffolding.** Create the folder layout a new feature needs (`res://art`, `res://audio`, `res://scenes/levels`) in one click.
- **Batch fixers.** Open each scene in a list, tweak it, and save it, so a project-wide change is one Run instead of fifty manual edits.
- **Test runners.** A one-click "Play the current scene" tool, and its partner "Stop".
- **Inspector buttons.** A clickable button on a node's Inspector that runs a fixup function on that node.

And with the plugin's public **EventSheets** API (covered in section 4) you can go one level up and automate the *editor* itself: add a Command Palette entry, ship a Project Doctor check, register a new row type, or generate whole sheets from code.

## 2. Your First Tool Sheet

### Step 1 - make a new sheet and set its type

Create a new event sheet, then open the **Sheet Type** dialog. In the type dropdown choose **Editor Tool (EditorScript)**. That preset does two things for you: it sets the host class to `EditorScript` and turns on Tool mode (the `@tool` line). (You can also leave the type as something else and just tick the **@tool** checkbox, but the Editor Tool preset is the clean starting point.)

Under the hood this sets `tool_mode = true` and `host_class = "EditorScript"` on the sheet - the two facts that make it compile as an editor tool instead of a game script.

### Step 2 - add the entry point

A Tool sheet has one special trigger: **On Editor Run**. It is the sheet's front door - everything under it runs when you Run the tool. Add an event and pick **On Editor Run** as its trigger. It lives in the **Editor Tools** category of the picker.

### Step 3 - add an action

Under that event, add an action from the **Editor Tools** category. Start simple with a plain `print`, or jump straight to something useful like **Make Sure Folder Exists**. Your sheet now reads:

```
On Editor Run
    → Print   "Hello from my tool"
```

### Step 4 - run it

Save the sheet. It compiles to a tiny, plain GDScript file:

```gdscript
@tool
extends EditorScript


func _run() -> void:
	print("Hello from my tool")
```

That is the whole thing. No plugin dependency, no magic - just the code you would have written by hand. To run it, open that generated `.gd` in the Script editor and choose **File > Run** (shortcut **Ctrl+Shift+X**). Godot calls `_run()`, your `print` fires, and you see it in the Output panel. **On Editor Run** is exactly `_run()`; the two are the same thing.

That is the loop: build events under **On Editor Run**, save, and Run from the Script editor.

## 3. The Editor Tools ACEs

The **Editor Tools** module is the vocabulary you build tool sheets from. Every entry compiles to the plain editor API Godot already exposes (`EditorInterface`, `ResourceSaver`, `DirAccess`, `Engine`) with zero plugin references, so the generated tool is ordinary code you could have typed yourself. There are 17 of them, in five groups.

Types: **Action** does something, **Condition** answers true/false (use it in an event's condition slot), **Expression** returns a value (use it inside a parameter).

### Scene lifecycle - open, save, and play the scene you are editing

| Editor Tools verb | Type | What it does |
|-------------------|------|--------------|
| **Open Scene In Editor** | Action | Opens a `.tscn` (parameter: **Scene Path**) as the current edited scene. |
| **Save Current Scene** | Action | Saves the scene currently open in the editor. |
| **Save Scene As** | Action | Saves the current scene to a new path (parameter: **Scene Path**). |
| **Play Current Scene** | Action | Runs the open scene, as if you pressed Play Scene. |
| **Stop Playing** | Action | Stops the game you started from the editor. |
| **Rescan Project Files** | Action | Re-imports the FileSystem dock, so files a tool just wrote show up right away. |

### Selection and inspector - drive what the editor is focused on

| Editor Tools verb | Type | What it does |
|-------------------|------|--------------|
| **Select Node In Editor** | Action | Clears the selection and selects a node (parameter: **Node**) in the Scene dock. |
| **Inspect In Editor** | Action | Shows a node or resource (parameter: **Object**) in the Inspector dock. |

### Files and resources - write what a tool generates back to disk

| Editor Tools verb | Type | What it does |
|-------------------|------|--------------|
| **Save Resource To File** | Action | Writes a resource to disk (parameters: **Resource**, **Path**). |
| **Make Sure Folder Exists** | Action | Creates a folder and any missing parents (parameter: **Folder**), so a tool can write into it. |
| **Resource Exists** | Condition | True when a resource file already exists at the given **Path**. |

### Combined builders - three lines of scene-building in one row

| Editor Tools verb | Type | What it does |
|-------------------|------|--------------|
| **Add Node To Edited Scene** | Action | Adds a node (parameter: **Node**) under a **Parent** AND sets its `owner`, so it saves with the scene. |
| **Save Node As Scene** | Action | Packs a node (parameter: **Node**) and its children into a `PackedScene` and saves it as a `.tscn` (parameter: **Path**). |

### Editor state - guards and queries a tool reads

| Editor Tools verb | Type | What it does |
|-------------------|------|--------------|
| **Is In Editor** | Condition | True when the script is running inside the editor (a `@tool` script), not the running game. |
| **Edited Scene Root** | Expression | The root node of the scene currently open in the editor. |
| **Selected Nodes** | Expression | The array of nodes currently selected in the Scene dock. |
| **Editor Scale** | Expression | The editor's display scale (`1.0` at 100%), handy for sizing tool UI. |

**Why Is In Editor matters.** The Editor Tools verbs call editor-only APIs. In a Tool sheet that is fine - it only ever runs in the editor. But if you sprinkle one of these into a `@tool` **node** script (a sheet that also runs in your game), guard it with **Is In Editor** so it does not try to touch `EditorInterface` in an exported build where that does not exist.

## 4. Interfacing with the EventSheets API

A Tool sheet automates **edits to your project**. To automate **the editor itself** - add a menu command, ship a health check, teach the picker a new row - you go through the plugin's one public class, **`EventSheets`** (`addons/eventsheet/api/eventsheets.gd`). It is all `static`, and every method on it is a compatibility promise: shapes are stable once shipped, new capabilities get added, existing ones are never renamed. Reach for this class and nothing else - never the dock's internal members, which move between releases.

The right place to wire this up is a small **`EditorPlugin`**: register in `_enter_tree()`, unregister in `_exit_tree()`.

```gdscript
@tool
extends EditorPlugin


func _enter_tree() -> void:
	# 1. A one-click command in the Command Palette (Ctrl+P).
	EventSheets.register_palette_command("Insert Debug Marker", func() -> void:
		EventSheets.edit("Insert Debug Marker", func(sheet: EventSheetResource) -> void:
			var note: CommentRow = CommentRow.new()
			note.text = "DEBUG: checked %s" % Time.get_time_string_from_system()
			sheet.events.insert(0, note))
		EventSheets.set_status("Marker inserted."))

	# 2. A project-health check that runs everywhere the Doctor runs.
	EventSheets.register_doctor_check("my_tools.todo_left", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
		for sheet_path: String in sheet_paths:
			if FileAccess.get_file_as_string(sheet_path).contains("TODO"):
				findings.append({"severity": "info", "check": "my_tools.todo_left",
					"path": sheet_path, "message": "Sheet still has a TODO."}))

	# 3. A new row type - a "Spawn Table" block - built without subclassing.
	EventSheets.register_block_kind(EventSheets.simple_block_kind({
		"kind_id": "my_tools.spawn_table",
		"title": "Spawn Table",
		"category": "Blocks",
		"fields": [
			{"id": "enemy", "label": "Enemy", "type": TYPE_STRING, "default": "Slime"},
			{"id": "count", "label": "Count", "type": TYPE_INT, "default": 3}],
		"emit": "## SPAWN {count} x {enemy}",
		"summary": "spawn {count} x {enemy}"}))


func _exit_tree() -> void:
	EventSheets.unregister_palette_command("Insert Debug Marker")
	EventSheets.unregister_doctor_check("my_tools.todo_left")
```

A few things to notice:

- **`register_palette_command(title, action)`** puts your tool in the Command Palette (Ctrl+P) next to the built-ins. Re-registering the same title replaces it, so a plugin reload never duplicates entries.
- **`edit(label, mutation)`** is THE way to change the open sheet. Your callable receives the live `EventSheetResource`; the whole change lands as one undo step named `label`, and the API refreshes the rows and marks the sheet dirty for you. One rule: never cache a row across `edit()` calls (the commit replaces resources with snapshot duplicates), so always re-fetch from `current_sheet()`.
- **`register_doctor_check(check_id, check)`** ships a health check that runs in the Doctor panel, the headless CLI, CI, and MCP. Your check receives every sheet path plus a shared `findings` array and appends findings shaped `{"severity", "check", "path", "message"}`. The Doctor covenant applies: never write inside `res://` from a check.
- **`simple_block_kind(config)` + `register_block_kind(kind)`** add a new NON-ACE row type with no subclassing. `emit` is the template it compiles to (one output line per line of the string, `{field}` placeholders); `summary` is the one-line viewport display.

There is no `unregister_block_kind`, so a block kind is registered for the session; that is why `_exit_tree()` only tears down the palette command and the Doctor check.

### Building and compiling sheets from code

`new_sheet(config)` is the one public "create a sheet" entry, and `compile(sheet, output_path)` writes it out. Together they let a tool **generate** editor tools (or behaviors, autoloads, custom nodes) from code:

```gdscript
# Author a Tool script from code, then write it to disk.
var sheet: EventSheetResource = EventSheets.new_sheet({
	"tool_mode": true, "host_class": "EditorScript"})
# ... append an On Editor Run event and its actions to sheet.events ...
var result: Dictionary = EventSheets.compile(sheet, "res://tools/my_generated_tool.gd")
print(result["success"])   # plus "output" (the source text), "errors", "warnings"
```

Note the result key is `"output"`, not `"source"` - reading the wrong key hands you an empty string. Other codegen services on the same class: `open_gd_as_sheet(source)` opens GDScript back as an editable sheet, and `round_trips(source)` is the byte-gate (true when import then re-emit reproduces the source exactly) - the same covenant every built-in lift must pass, ideal to pin in your own tests.

## 5. Use Cases

Twelve concrete tools, ready to adapt. The ones marked **Tool sheet** are events under **On Editor Run**; the ones marked **EditorPlugin** are code that calls the `EventSheets` API.

### 1. Spawn ten placeholder crates in the edited scene (Tool sheet)

**Scenario:** you are blocking out a level and want ten crate placeholders you can nudge around, saved with the scene.

```
On Editor Run
    → Repeat 10 times
        → Add Node To Edited Scene
            Node:   preload("res://crate.tscn").instantiate()
            Parent: Edited Scene Root
    → Save Current Scene
```

**Add Node To Edited Scene** sets each crate's `owner` to the edited scene root, which is what makes them persist when the scene is saved.

### 2. Turn each selected node into a reusable scene (Tool sheet)

**Scenario:** you hand-built a prop in the scene and want it packed into its own `.tscn` you can reuse.

```
On Editor Run
    → For Each   in   Selected Nodes
        → Save Node As Scene
            Node: Current Loop Item
            Path: "res://props/" + Current Loop Item.name + ".tscn"
    → Rescan Project Files
```

### 3. Generate a data resource and write it to disk (Tool sheet)

**Scenario:** you keep enemy stats in a `.tres` and want a fresh one stamped out from a template script.

```
On Editor Run
    → Make Sure Folder Exists   "res://generated"
    → Save Resource To File
        Resource: preload("res://enemy_stats.gd").new()
        Path:     "res://generated/enemy_stats.tres"
    → Rescan Project Files
```

### 4. Scaffold a project's folder layout (Tool sheet)

**Scenario:** every new feature starts with the same empty folders, and you are tired of making them by hand.

```
On Editor Run
    → Make Sure Folder Exists   "res://art"
    → Make Sure Folder Exists   "res://audio"
    → Make Sure Folder Exists   "res://scenes/levels"
    → Rescan Project Files
```

**Make Sure Folder Exists** creates parents too, so `res://scenes/levels` makes `res://scenes` on the way.

### 5. Refresh the FileSystem after a tool writes files (Tool sheet)

**Scenario:** your generator wrote a file but the FileSystem dock still does not show it.

```
On Editor Run
    → Save Resource To File   ...   "res://generated/loot.tres"
    → Rescan Project Files
```

**Rescan Project Files** re-imports the FileSystem so anything a tool just wrote appears immediately - end most file-writing tools with it.

### 6. A palette power-tool that inserts a debug marker (EditorPlugin)

**Scenario:** you want a one-key way to drop a dated debug comment at the top of the open sheet, as one undo step.

```gdscript
EventSheets.register_palette_command("Insert Debug Marker", func() -> void:
	EventSheets.edit("Insert Debug Marker", func(sheet: EventSheetResource) -> void:
		var note: CommentRow = CommentRow.new()
		note.text = "DEBUG: %s" % Time.get_time_string_from_system()
		sheet.events.insert(0, note)))
```

### 7. Ship a project audit as a Doctor check (EditorPlugin)

**Scenario:** your team forbids leftover `TODO` markers in shipped sheets, and you want the Doctor to flag them everywhere it runs.

```gdscript
EventSheets.register_doctor_check("team.no_todos", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if FileAccess.get_file_as_string(sheet_path).contains("TODO"):
			findings.append({"severity": "warning", "check": "team.no_todos",
				"path": sheet_path, "message": "Sheet still has a TODO marker."}))
```

Severity decides consequence: errors fail CI, warnings fail `--strict` CI, infos are advisory. Never write inside `res://` from a check.

### 8. Add a custom "Spawn Table" row type (EditorPlugin)

**Scenario:** your enemy-spawning pack wants a friendly row designers fill in, no code.

```gdscript
EventSheets.register_block_kind(EventSheets.simple_block_kind({
	"kind_id": "spawner.table",
	"title": "Spawn Table",
	"category": "Blocks",
	"fields": [
		{"id": "enemy", "label": "Enemy", "type": TYPE_STRING, "default": "Slime"},
		{"id": "count", "label": "Count", "type": TYPE_INT, "default": 3}],
	"emit": "## SPAWN {count} x {enemy}",
	"summary": "spawn {count} x {enemy}"}))
```

The kind gets the Add menu, palette, edit dialog, compile, and lift wiring for free.

### 9. Generate a behavior sheet from a template (EditorPlugin)

**Scenario:** you spin up a lot of similar behaviors and want a "new patrol behavior" generator instead of copy-paste.

```gdscript
var sheet: EventSheetResource = EventSheets.new_sheet({
	"class_name": "PatrolBehavior", "host_class": "CharacterBody2D",
	"behavior_mode": true, "category": "AI", "tags": ["ai"]})
# ... append events to sheet.events ...
var result: Dictionary = EventSheets.compile(sheet, "res://behaviors/patrol.gd")
if result["success"]:
	EventSheets.open_sheet("res://behaviors/patrol.gd")
```

### 10. Batch-fix a list of scenes (Tool sheet)

**Scenario:** every level needs the same node added, and there are too many to open one by one.

```
On Editor Run
    → For Each   in   ["res://levels/a.tscn", "res://levels/b.tscn"]
        → Open Scene In Editor   Current Loop Item
        → Add Node To Edited Scene
            Node:   preload("res://spawn_point.tscn").instantiate()
            Parent: Edited Scene Root
        → Save Current Scene
```

Each pass **opens** a scene, **edits** the now-current edited scene, and **saves** it.

### 11. A Play / Stop test-runner (Tool sheet)

**Scenario:** you want one-click "run the scene I am editing" and a partner to stop it, without hunting for the toolbar buttons.

Run tool:

```
On Editor Run
    → Play Current Scene
```

Stop tool:

```
On Editor Run
    → Stop Playing
```

### 12. An Inspector button that runs a fixup (Tool function)

**Scenario:** designers should be able to click a button on a node's Inspector to re-run its setup, right where they are working.

Any sheet function can carry a **Tool Button** label. Give a function (say `recalculate`) the label "Recalculate", and the compiler emits:

```gdscript
@export_tool_button("Recalculate") var _btn_recalculate: Callable = recalculate
```

That is a real, clickable button in the Inspector (Godot 4.4+). Because the button runs in the editor, the sheet must be a Tool sheet (or otherwise `@tool`) - if you add a Tool Button label without turning on Tool mode, the compiler warns: "Tool buttons need a @tool sheet to run in the editor - enable Tool in the Sheet Type dialog." Turn on Tool in the Sheet Type dialog and the warning clears.

## 6. Tips and Common Mistakes

- **Editor Tools verbs only work in the editor.** They call `EditorInterface`, `ResourceSaver`, `DirAccess`, and `Engine`, which exist while you are building, not in an exported game. Keep them in a Tool sheet, or - if they live in a `@tool` node script that also runs at play time - guard them behind an **Is In Editor** condition so an exported build never touches editor-only APIs.
- **A Tool sheet runs with File > Run, not by attaching it to a node.** It is an `EditorScript`. You run it from the Script editor (Ctrl+Shift+X); there is nothing to add to a scene.
- **Do not forget `owner` if you hand-roll node creation.** A node added to the edited scene only saves with that scene if its `owner` is the edited scene root. **Add Node To Edited Scene** sets `owner` for you - that is the whole point of the combined builder. If you build nodes some other way and skip `owner`, they vanish on save.
- **End file-writing tools with Rescan Project Files.** A file you wrote to `res://` will not appear in the FileSystem dock until the editor re-imports; **Rescan Project Files** does that.
- **Pin your editor version.** The editor API is Godot's most volatile surface between versions. A tool that leans on `EditorInterface` is coupled to the editor you built it in; note the version somewhere, and re-test tools after upgrading Godot.
- **Never write inside `res://` from a Doctor check.** A health check reads and reports; it must not mutate the project. Send any scratch work to `user://`. (Tools that *generate* files are a different job - those legitimately write to `res://`.)
- **Reach the plugin only through the `EventSheets` facade.** Dock internals (the `_`-prefixed members) get renamed and relocated freely between releases. `EventSheets` is the one surface with a stability promise - use it and nothing else.
- **Read `compile()`'s result from `"output"`, not `"source"`.** The wrong key returns an empty string that quietly compares equal to other empty strings, which makes broken tooling look like it works.
- **Return `false` from an `edit()` mutation that changed nothing.** Otherwise the user gets an undo step that does nothing. And never cache a row across `edit()` calls - re-fetch from `current_sheet()`, because the commit swaps resources for snapshot duplicates.
