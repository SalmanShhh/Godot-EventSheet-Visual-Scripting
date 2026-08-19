# Automating The Editor

**Editor Tools** is the vocabulary for sheets that are *tools* rather than game logic. A Tool sheet
compiles to `@tool extends EditorScript` with an `_run()` function, so **File > Run** in the script
editor executes it against the project you are editing: open a scene, add nodes to it, save it, write
a resource, rescan the FileSystem dock, render a thumbnail. On top of that sits **On Project Export**,
which turns the same sheet into a bake step the exporter runs before it writes any files.

Every verb here compiles to the plain editor API - `EditorInterface`, `ResourceSaver`, `DirAccess`,
`ConfigFile`, `SubViewport` - with no plugin reference at all, so a tool you build keeps working after
the plugin is uninstalled.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [Verb reference](#verb-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Bulk scene edits** - open forty level scenes in turn, fix one node in each, save.
- **Generators** - build a scene out of a data table and save it as a `.tscn`.
- **Asset pipelines** - write `.tres` files from a spreadsheet, then rescan so they appear.
- **Thumbnails and store shots** - render a scene to a PNG without opening it by hand.
- **Balance checks** - roll a loot table a thousand times and read the real odds before shipping.
- **Build stamps** - write the version and the time into a file the game reads back.
- **Release gates** - refuse to ship a debug-only scene, or bake different data per platform.
- **Selection helpers** - a one-key tool that selects and inspects the node you always need.
- **Project chores** - make a folder, check whether a resource exists, save the scene you are on.
- **Play-testing shortcuts** - run the current scene and stop it again from a row.

## Core concepts

- **These verbs are editor-only.** They call `EditorInterface`, which does not exist in a running
  game. Put them in an editor-tool sheet (**Sheet Type > Editor Tool**), which emits `@tool`, `extends EditorScript`
  and the `On Editor Run` trigger for you.
- **On Editor Run is the entry point.** It compiles to `_run`, the function the editor calls when you
  press **File > Run** with the generated script open. Everything a tool does hangs under it.
- **On Project Export is the other entry point.** It runs while an export is starting, before the
  files are written. Two conditions come with it: **Export Is Debug** and **Export Has Feature**,
  which read the flags the exporter hands the bake step.
- **Nothing is baked into the code.** A build stamp asks the clock at run time rather than at compile
  time, because the compiler must emit identical GDScript on every save.
- **Headless runs cannot render.** **Render Scene To Image** checks the display server first and
  warns instead of writing a blank image, so a `--headless` invocation degrades honestly.
- **Writing a file is not the same as the editor seeing it.** The FileSystem dock caches; **Rescan
  Project Files** is the row that makes a generated file show up.

## Setup

Create a new sheet and pick **Editor Tool** as its Sheet Type. The sheet opens with **On Editor Run**
already in it, and the picker's **Editor Tools** section holds everything below. Save the sheet as a
`.gd`, open that file in the script editor, and press **File > Run**.

```
On editor run (File > Run)
  -> make sure folder res://generated exists
  -> save MyResource to res://generated/data.tres
  -> rescan project files
```

## Verb reference

On the canvas these read as sentences with the values in bold, exactly as the rows draw them:

- open scene **res://levels/level_01.tscn**
- add **Sprite2D.new()** under **EditorInterface.get_edited_scene_root()**
- render **res://ship.tscn** to **res://thumbs/ship.png** at **512x512**

### Triggers

| Verb | What it does | Ships as |
|------|--------------|----------|
| On Editor Run | Runs the tool when you press File > Run in the script editor. | the `_run` function of an `EditorScript` |
| On Project Export | Runs while a project export is starting, before the files are written. | the `_on_project_export` export-plugin hook |
| On Plugin Enabled | Runs when the plugin is switched on - at editor start, or when you tick it. | the `_enter_tree` function of an `EditorPlugin` |
| On Plugin Disabled | Runs when the plugin is switched off or the editor closes. | the `_exit_tree` function of an `EditorPlugin` |
| On Object Selected | Runs when the user selects an object this plugin handles. | `_edit(object)` |
| On Draw Over 2D Viewport | The editor's 2D overlay pass - draw handles and guides on top of the scene. | `_forward_canvas_draw_over_viewport(overlay)` |
| On 2D Viewport Input | Input that lands in the 2D viewport, before the viewport itself sees it. | `_forward_canvas_gui_input(event)` |
| On Draw Gizmo | A gizmo's own paint pass, when its node moves or changes. | `_redraw()` |

### What a plugin adds to the editor

| Verb | What it does | Ships as |
|------|--------------|----------|
| Add Tools Menu Item | Adds an item to the editor's Project > Tools menu. | `add_tool_menu_item({title}, {handler})` |
| Remove Tools Menu Item | Takes the plugin's item back out of Project > Tools. | `remove_tool_menu_item({title})` |
| Add Dock | Hangs a Control in one of the editor's eight dock slots. | `add_control_to_dock({slot}, {control})` |
| Remove Dock | Takes a dock back out of the editor. | `remove_control_from_docks({control})` |
| Add Object Type | Teaches the editor a new object type, so it shows up in Create Node. | `add_custom_type({type_name}, {base}, {script}, {icon})` |
| Remove Object Type | Takes a custom object type back out of the Create Node dialog. | `remove_custom_type({type_name})` |
| Add Inspector Plugin | Registers a custom Inspector drawer. | `add_inspector_plugin({plugin})` |
| Remove Inspector Plugin | Takes a custom Inspector drawer back out. | `remove_inspector_plugin({plugin})` |
| Redraw Viewport Overlays | Asks the editor to run the overlay pass again. | `update_overlays()` |
| Editor Settings | The editor's own settings object - grid step, theme, font size. | `EditorInterface.get_editor_settings()` |
| Undo History | The editor's undo / redo history, to add do and undo steps to. | `get_undo_redo()` |

### Scene lifecycle

| Verb | What it does | Ships as |
|------|--------------|----------|
| Open Scene In Editor | Opens a `.tscn` as the current edited scene. | `EditorInterface.open_scene_from_path({path})` |
| Save Current Scene | Saves whatever scene is open in the editor. | `EditorInterface.save_scene()` |
| Save Scene As | Saves the current scene to a new path. | `EditorInterface.save_scene_as({path})` |
| Play Current Scene | Runs the edited scene, as if you pressed Play Scene. | `EditorInterface.play_current_scene()` |
| Stop Playing | Stops the game the editor started. | `EditorInterface.stop_playing_scene()` |
| Rescan Project Files | Re-imports the FileSystem dock so generated files appear. | `EditorInterface.get_resource_filesystem().scan()` |

### Selection and Inspector

| Verb | What it does | Ships as |
|------|--------------|----------|
| Select Node In Editor | Clears the selection and selects one node in the Scene dock. | `EditorInterface.get_selection().clear()` then `EditorInterface.get_selection().add_node({node})` |
| Inspect In Editor | Shows a node or resource in the Inspector dock. | `EditorInterface.inspect_object({object})` |
| Selected Nodes | The array of nodes selected in the Scene dock right now. | `EditorInterface.get_selection().get_selected_nodes()` |
| Edited Scene Root | The root node of the scene open in the editor. | `EditorInterface.get_edited_scene_root()` |

### Files and resources

| Verb | What it does | Ships as |
|------|--------------|----------|
| Save Resource To File | Writes a resource out to disk. | `ResourceSaver.save({resource}, {path})` |
| Make Sure Folder Exists | Creates a folder and any missing parents. | `DirAccess.make_dir_recursive_absolute({path})` |
| Resource Exists | True when a resource file is already at that path. | `ResourceLoader.exists({path})` |

### Scene builders

| Verb | What it does | Ships as |
|------|--------------|----------|
| Add Node To Edited Scene | Adds a node under a parent AND sets its owner, so the scene saves it. | a three-line block: a local for the node, `{parent}.add_child(...)`, then `.owner = EditorInterface.get_edited_scene_root()` |
| Save Node As Scene | Packs a node and its children and saves them as a `.tscn`. | a three-line block: `PackedScene.new()`, `.pack({node})`, `ResourceSaver.save(..., {path})` |

### Editor state

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is In Editor | True when the script is running inside the editor rather than the game. | `Engine.is_editor_hint()` |
| Editor Scale | The editor's display scale, 1.0 at 100%, for sizing tool UI. | `EditorInterface.get_editor_scale()` |

### The heavy chores

| Verb | What it does | Ships as |
|------|--------------|----------|
| Render Scene To Image | Instantiates a scene into an off-screen viewport, lets it settle a frame, saves a PNG. | a guarded block: a headless check, a missing-scene check, then a `SubViewport` parented to the editor's base control, two `await`s (`process_frame`, `RenderingServer.frame_post_draw`) and `get_texture().get_image().save_png({save_path})` |
| Preview Table Rolls | Rolls a weighted table many times and reports rolled percent, expected percent and the gap. | a block over a seeded `RandomNumberGenerator` that prints a `entry \| rolled \| expected \| delta` report and optionally writes it to a file |
| Write Version Stamp | Writes a small build stamp file: a version string plus the time it was written. | a `ConfigFile` with `build/version` and `build/stamped_at`, saved, with the save error read and warned about |

### Export bake step

| Verb | What it does | Ships as |
|------|--------------|----------|
| Export Is Debug | True when the export that triggered this bake step is a debug build. | `is_debug` |
| Export Has Feature | True when the export preset carries that feature tag. | `features.has({feature})` |

**Render Scene To Image** takes `scene_path`, `width`, `height` and `save_path`. **Preview Table
Rolls** takes `table`, `rolls`, `seed` and `save_path` (leave the save path empty to print only).
**Write Version Stamp** takes `path` and `version`, and the version defaults to the project's own
`application/config/version` setting.

## Use cases

**1. A tool that opens a level and saves it again.** The two-row shape every bulk edit is built on.

```gdscript
func _run() -> void:
	EditorInterface.open_scene_from_path("res://levels/level_01.tscn")
	EditorInterface.save_scene()
```

**2. Make a folder before writing into it.** `DirAccess` creates missing parents too, so one row is
enough for a nested path.

```gdscript
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://generated/tables")
```

**3. Write a resource, then make the editor notice it.** Without the rescan the file is on disk but
the FileSystem dock still shows the old project.

```gdscript
func _run() -> void:
	ResourceSaver.save(my_resource, "res://generated/tables/loot.tres")
	EditorInterface.get_resource_filesystem().scan()
```

**4. Do not overwrite work.** **Resource Exists** is a condition, so the write sits under it inverted.

```
On editor run (File > Run)
  Condition: resource res://generated/tables/loot.tres exists  (inverted)
    -> save MyTable to res://generated/tables/loot.tres
```

**5. Build a node into the scene you are editing.** **Add Node To Edited Scene** is the verb that
remembers the owner, which is the step everybody forgets: a node with no owner vanishes on save.

```gdscript
func _run() -> void:
	var __node_tool01 = Marker2D.new()
	EditorInterface.get_edited_scene_root().add_child(__node_tool01)
	__node_tool01.owner = EditorInterface.get_edited_scene_root()
```

**6. Turn a node into a reusable scene file.** Point **Save Node As Scene** at a node you just built
and it packs the whole subtree.

```gdscript
func _run() -> void:
	var __scene_tool02 = PackedScene.new()
	__scene_tool02.pack(EditorInterface.get_edited_scene_root())
	ResourceSaver.save(__scene_tool02, "res://prefabs/checkpoint.tscn")
```

**7. Act on whatever is selected.** **Selected Nodes** is an expression, so a For Each row walks it
and the body acts on each one.

```
On editor run (File > Run)
  -> For Each in Selected Nodes
      -> set item.modulate = Color.RED
```

**8. Select and inspect a node from a tool.** Handy as the last two rows of a generator: it leaves
the editor focused on what it just made.

```gdscript
func _run() -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(EditorInterface.get_edited_scene_root())
	EditorInterface.inspect_object(EditorInterface.get_edited_scene_root())
```

**9. Play the scene and stop it again.** A tool that runs a scene, waits, and stops it is a one-key
smoke test.

```gdscript
func _run() -> void:
	EditorInterface.play_current_scene()
	await get_tree().create_timer(5.0).timeout
	EditorInterface.stop_playing_scene()
```

**10. Guard a shared sheet so it only runs in the editor.** **Is In Editor** is the condition that
lets one sheet carry both game logic and tool logic.

```
Every Frame
  Condition: running in the editor
    -> print "editor preview tick"
```

**11. Size a tool's UI to the editor.** **Editor Scale** is 1.0 at 100%, 2.0 on a HiDPI editor.

```gdscript
func _run() -> void:
	panel.custom_minimum_size = Vector2(240, 120) * EditorInterface.get_editor_scale()
```

**12. Render a thumbnail for the asset browser.** The scene needs its own camera (or a Control
layout) - the renderer photographs what the scene itself shows.

```
On editor run (File > Run)
  -> render res://ships/interceptor.tscn to res://thumbs/interceptor.png at 512x512
```

**13. Batch thumbnails.** Put the render row inside a For Each over a list of scene paths and one
File > Run refreshes the whole store page.

**14. Check a loot table's real odds before shipping it.** **Preview Table Rolls** reads a table
resource's `entries`, a plain Dictionary of value to weight, or a path to either, and prints the gap
between what came out and what the weights implied.

```
On editor run (File > Run)
  -> preview 10000 rolls of res://loot/boss_drop.tres
```

The same seed always prints the same report, so two runs are comparable and a diff is meaningful.

**15. Keep the report.** Give **Preview Table Rolls** a Save To path and the report lands in a file
you can commit beside the table, so a balance change shows up in review.

**16. Stamp the build on export.** Under **On Project Export**, one row writes the version and the
moment it was written.

```gdscript
func _on_project_export() -> void:
	var __stamp_bake01 := ConfigFile.new()
	__stamp_bake01.set_value("build", "version", ProjectSettings.get_setting("application/config/version", "0.0.0"))
	__stamp_bake01.set_value("build", "stamped_at", Time.get_datetime_string_from_system(true))
	var __stamp_err_bake01 := __stamp_bake01.save("res://build_stamp.cfg")
	if __stamp_err_bake01 != OK:
		push_warning("[Write Version Stamp] Could not write %s (%s) - the build carries no stamp." % ["res://build_stamp.cfg", error_string(__stamp_err_bake01)])
```

**17. Keep test content out of release builds.** **Export Is Debug** reads the flag the exporter
handed the bake step.

```
On project export (bake step)
  Condition: the export is a debug build
    -> save DebugTable to res://generated/debug_data.tres
```

**18. Bake different data per platform.** **Export Has Feature** reads the preset's feature tags, so
`mobile`, `web` and your own custom tags each get their own branch.

```
On project export (bake step)
  Condition: the export has feature mobile
    -> save LowResAtlas to res://generated/atlas.tres
```

### Other use cases

**A scene-wide rename pass.** Walk the edited scene root's children in a For Each, set each node's name from a table, then Save Current Scene, so a naming convention lands across a whole level in one File > Run.

**A prefab factory.** Build a node tree row by row with Add Node To Edited Scene, then Save Node As Scene into a prefabs folder, so a designer gets a fresh variant without ever touching the Scene dock.

**A documentation figure run.** Render Scene To Image over a list of showcase scenes writes every screenshot a README needs at one size, so figures never drift out of date with the scenes.

**A pre-release audit tool.** Resource Exists over every path the game loads, printed as a checklist, so a missing asset is caught at File > Run instead of at a player's crash report.

**A per-platform asset swap.** On Project Export plus Export Has Feature writes one atlas for web and another for desktop into the same path, so the game loads one name and the exporter decides what is behind it.

## Tips and common mistakes

- **A Tool sheet is not a game sheet.** `EditorInterface` is null in an exported game. If a sheet
  might run in both, guard the editor rows with **Is In Editor**.
- **A node with no owner is not saved.** `add_child` alone leaves the node out of the `.tscn`.
  **Add Node To Edited Scene** sets the owner for you; a hand-written raw block usually does not.
- **Write, then rescan.** A file written by a tool is invisible to the FileSystem dock until
  **Rescan Project Files** runs. Import errors that "make no sense" are almost always this.
- **Rendering needs a window.** **Render Scene To Image** refuses to run under `--headless`: it
  pushes a warning naming the file it did not write, rather than saving a blank PNG. Run the tool
  from the real editor.
- **A rendered scene photographs itself.** If the scene has no camera and no Control layout, the
  image is empty. That is the scene's problem, not the verb's.
- **Preview Table Rolls needs weights above zero.** If every entry weighs zero, or the path resolves
  to nothing, the report says so by name instead of printing a table of zeroes. Read the second line.
- **The stamp is written at run time, not at compile time.** The generated code calls
  `Time.get_datetime_string_from_system(true)`, so the file changes on every run while the script
  stays byte-identical. That is deliberate: emission must be deterministic.
- **A failed stamp is loud.** Writing into a folder that does not exist, or into a read-only `res://`
  during a CI export, warns rather than silently shipping a stale stamp. Make the folder first.
- **Export Is Debug and Export Has Feature only mean anything inside On Project Export.** They read
  `is_debug` and `features`, which are the bake step's own parameters; elsewhere they will not
  compile.
- **Save Scene As does not switch which scene you are editing.** It writes a copy. Follow it with
  **Open Scene In Editor** if the tool should carry on in the new file.
