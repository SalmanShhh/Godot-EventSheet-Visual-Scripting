# Editor Tools Guide - Automate the Godot Editor with Event Sheets

An **editor tool** is an event sheet whose events run inside the Godot editor itself, never in the game. The same rows you use for gameplay - a trigger, some conditions, some actions - become one-click project chores: rename fifty nodes, generate a folder skeleton, sanity-check the open scene, stamp out a default settings file. The sheet compiles to a plain `@tool` script extending `EditorScript` (zero plugin dependency, like every compiled sheet), and you fire it from the script editor with **File > Run** (Ctrl+Shift+X). If you have ever copy-pasted a ten-line `EditorScript` from a forum, this is that - but as readable rows, with a picker full of editor verbs, and a Doctor that nudges you when a scene-mutating tool forgets undo.

---

## Table of Contents

1. [What is an editor tool](#1-what-is-an-editor-tool)
2. [Your first tool in 60 seconds](#2-your-first-tool-in-60-seconds)
3. [How it runs - File > Run, editor vs game](#3-how-it-runs---file--run-editor-vs-game)
4. [The vocabulary - Editor Tools ACEs](#4-the-vocabulary---editor-tools-aces)
5. [Inspector buttons - any function becomes a button](#5-inspector-buttons---any-function-becomes-a-button)
6. [Live Inspector warnings - required and validate](#6-live-inspector-warnings---required-and-validate)
7. [Undo done right](#7-undo-done-right)
8. [Use cases](#8-use-cases)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. What is an editor tool

Three ingredients make a sheet an editor tool, and the starter sets all three for you:

- **Tool mode** - the sheet emits `@tool` at the top of the script, so Godot is allowed to run it inside the editor.
- **Host: `EditorScript`** - the compiled script extends `EditorScript`, the engine's "run me once from the editor" class.
- **The On Editor Run trigger** - shows in the picker as "On editor run (File > Run)" and compiles to `_run()`, the function `EditorScript` calls when you run the file. It lives in the **Editor Tools** category and carries the "runs once" tempo badge, same as On Ready.

Everything else is ordinary event-sheet authoring. Conditions gate, actions do, functions and variables work exactly as they do in a gameplay sheet. The difference is only *where* the code runs: in the editor process, on the scene you are editing, before the game ever starts.

There is a second, softer flavor of editor tool that does not use `EditorScript` at all: a normal node or resource sheet with **Tool** enabled in the Sheet Type dialog. That gives you `@tool` on a script that lives in your scenes, which is what powers Inspector buttons and live validation (sections 5 and 6). Use the EditorScript flavor for one-click project chores; use the @tool-node flavor when the tool belongs to a specific node or resource.

---

## 2. Your first tool in 60 seconds

**1. Scaffold it.** In the workspace toolbar open the **Sheet** menu and pick **New Editor Tool…** (the same starter is also in the New Sheet template menu, under "Editor Tools - run inside the editor", as **Editor Tool (one-click chore)**).

**2. Read what you got.** The starter is deliberately tiny - one comment explaining the shape, and one event:

```
Comment: "Editor Tool - these events run inside the EDITOR when you run the
          compiled script (script editor > File > Run), never in the game."

On Editor Run
  -> GDScript block:
     var scene_root: Node = EditorInterface.get_edited_scene_root()
     if scene_root == null:
         print("Open a scene first.")
     else:
         print("%s has %d nodes." % [scene_root.name, scene_root.get_child_count()])
```

A safe, visible chore: count the nodes in the scene you have open and print the result.

**3. Run it.** Save the sheet (compile-on-save keeps the generated script fresh), open the compiled `.gd` in Godot's script editor, and pick **File > Run** (Ctrl+Shift+X). Look at the Output panel - your event just ran inside the editor.

That is the whole loop: edit rows, save, File > Run, read the Output panel. Everything below is vocabulary and polish on top of that loop.

---

## 3. How it runs - File > Run, editor vs game

**File > Run is the trigger.** `EditorScript` scripts are not attached to nodes and do not run with the game. The editor runs them on demand: with the script open in the script editor, **File > Run** (Ctrl+Shift+X) calls the script's `_run()` function once - and `_run()` is exactly what your **On Editor Run** event compiled to. One run, top to bottom, then done. There is no `_process`, no frames, no signals waiting around afterward.

**It acts on the editor's world, not the game's.** Inside On Editor Run, "the scene" means the scene open in the editor (`EditorInterface.get_edited_scene_root()`), "the selection" means the nodes highlighted in the Scene dock, and any node you add or property you change lands in the *edited* scene - the change is part of your project the moment you save the scene, no game required.

**Changes still need a scene save.** Your tool mutates the in-memory edited scene. Press Ctrl+S in the editor (or end the tool with the **Save Current Scene** action) to write it to disk.

**Files written by a tool need a rescan.** If your tool writes `.tres` or `.tscn` files to disk, the FileSystem dock does not notice by itself - end the tool with **Rescan Project Files** so they appear immediately.

**Editor-only verbs stay in the editor.** The Editor Tools actions call `EditorInterface`, which only exists in the editor process. Keep them in Tool sheets; a gameplay sheet that needs to know where it is running can use the **Is In Editor** condition (`Engine.is_editor_hint()`) as a guard.

---

## 4. The vocabulary - Editor Tools ACEs

Open the picker inside an On Editor Run event and the **Editor Tools** category has the everyday editor-automation verbs. They compile to the exact plain Godot the editor exposes - `EditorInterface`, `ResourceSaver`, `DirAccess`, `Engine`, plus `SubViewport` / `RenderingServer` for Render Scene To Image, `RandomNumberGenerator` for Preview Table Rolls and `ConfigFile` for Write Version Stamp - with zero plugin references, so the generated script works in any Godot project.

### Trigger

| Trigger | Fires when |
|---|---|
| On Editor Run | You run the compiled script from the script editor with File > Run (Ctrl+Shift+X). Compiles to `_run()`. Runs once per invocation. |
| On Project Export | A project export starts, before the files are written. Compiles to `_on_project_export(is_debug, features)`. Runs once per export - see "The export bake step" below. |

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Open Scene In Editor | `path` | Opens a `.tscn` as the current edited scene. |
| Save Current Scene | (none) | Saves the scene currently open in the editor. |
| Save Scene As | `path` | Saves the current scene to a new path. |
| Play Current Scene | (none) | Runs the open scene, as if you pressed Play Scene. |
| Stop Playing | (none) | Stops the game that was started from the editor. |
| Rescan Project Files | (none) | Re-imports the FileSystem dock so files a tool just wrote show up right away. |
| Select Node In Editor | `node` | Clears the selection and selects a node in the Scene dock. |
| Inspect In Editor | `object` | Shows a node or resource in the Inspector dock. |
| Save Resource To File | `resource`, `path` | Writes a resource out to a `.tres` / `.res` file. |
| Make Sure Folder Exists | `path` | Creates a folder (and any missing parents) so a tool can write into it. |
| Add Node To Edited Scene | `node`, `parent` | Adds a new node under a parent AND sets its owner to the edited scene root, so it is saved with the scene. Three lines of scene-building in one pickable row. |
| Save Node As Scene | `node`, `path` | Packs a node and its children into a `PackedScene` and saves it as a `.tscn`. |
| Render Scene To Image | `scene_path`, `width`, `height`, `save_path` | Instantiates a scene into an off-screen viewport, lets it settle a frame, and saves what it shows as a PNG. |
| Preview Table Rolls | `table`, `rolls`, `seed`, `save_path` | Rolls a weighted table N times and reports rolled percent vs the percent each weight implies, plus the gap. |
| Write Version Stamp | `path`, `version` | Writes a small `ConfigFile` build stamp: the version string plus the date and time it was written. |

### Conditions

| Condition | Parameters | True when |
|---|---|---|
| Resource Exists | `path` | A resource file already exists at the given path - the guard for "create the default file only once". |
| Is In Editor | (none) | The script is running inside the editor (`Engine.is_editor_hint()`), not the running game. The guard for @tool node sheets. |
| Export Is Debug | (none) | The export that triggered this bake step is a debug build. Only inside On Project Export. |
| Export Has Feature | `feature` | The export preset carries the given feature tag (`mobile`, `web`, one of your own). Only inside On Project Export. |

### Expressions

| Expression | Returns | What it gives you |
|---|---|---|
| Edited Scene Root | Node | The root node of the scene currently open in the editor. |
| Selected Nodes | Array | The nodes currently selected in the Scene dock. |
| Editor Scale | float | The editor's display scale (1.0 at 100%), for sizing tool UI. |

The one trap in this table: adding a node to the edited scene by hand needs *three* steps (create, `add_child`, set `owner`), and forgetting the owner means the node silently vanishes when the scene saves. **Add Node To Edited Scene** exists so you never hit that - it does all three.

### Render Scene To Image - and what it does when there is no screen

Point it at a `.tscn`, give it a size and a save path, and you get a PNG: a level-select thumbnail, a store screenshot, a figure for your design doc, a sprite baked out of a 3D model. Under the hood it does what a hand-written screenshot script does - instantiate the scene into a `SubViewport`, wait one frame for it to settle, wait for the frame to actually be drawn, then `save_png` the viewport texture - and then frees the viewport again.

Two things decide whether you get a picture:

- **The scene needs its own camera.** The renderer photographs what that scene shows. A `Node2D` scene wants a `Camera2D`, a 3D scene wants a `Camera3D` (and a light), and a `Control` scene just needs a layout. A scene with no camera renders as empty, which is the picture it honestly has to give.
- **The editor needs a window.** Rendering is done by the GPU, and a headless run (`--headless`, a CI job, the plugin's own test suite) has no renderer at all. The action checks for that first and pushes a clear warning - "this run has no display, so nothing was written" - instead of saving a blank image or crashing on a null texture. Run it from a normal editor and it works; run it headless and it tells you why it did not.

### Preview Table Rolls - see the odds you actually shipped

Weights are easy to write and hard to feel. "Common 60, rare 30, epic 9, legendary 1" looks reasonable until you play for an hour and never see an epic. This action rolls the table for you - a thousand times by default - and prints a small report:

```
Table roll preview - 1000 rolls, seed 12345
entry | rolled | expected | delta
common | 59.70% | 60.00% | -0.30%
rare | 30.40% | 30.00% | +0.40%
epic | 8.90% | 9.00% | -0.10%
legendary | 1.00% | 1.00% | +0.00%
```

Per entry: the percent that actually came out, the percent its weight implies, and the gap. It reads the weighted-table resources the plugin ships (any resource with an `entries` list of value/weight rows - a Random Table, a Loot Table) *and* a plain Dictionary you type into the field, like `{"common": 60, "rare": 30, "epic": 9, "legendary": 1}`. Pass a resource path as a String and it loads it for you.

It is pure arithmetic - no renderer, no scene - so it runs anywhere, including headless. The seed is a parameter, so the same seed always gives the same report: change a weight, re-run with the same seed, and the difference you see is the weight change and nothing else. Leave **Save To** empty to print to the Output panel only, or give it a path to keep the report as a file you can diff between balance passes.

It is not only for loot. Gacha pity tables, crit chances, encounter tables, biome weights in a procedural generator, dialogue variation picks - anything you wrote as weights can be checked before a player finds the bug for you.

### The export bake step - On Project Export

**On Project Export** is the second trigger an Editor Tool sheet can use. It fires when you press Export (or run an export from the command line), before the exported files are written, so whatever it writes is part of the build instead of a chore somebody has to remember. It receives two facts about the export, and two conditions read them:

- **Export Is Debug** - true for a debug build. Guard your test content with it and the release build never sees it.
- **Export Has Feature** - true when the export preset carries a feature tag (`mobile`, `web`, `windows`, or a custom tag you added in Project > Export). Bake different data per platform without a second sheet.

**Write Version Stamp** is the verb that makes it useful on day one: it writes a tiny `ConfigFile` holding your version string and the moment the stamp was written, which the game reads back in three lines:

```gdscript
var stamp := ConfigFile.new()
stamp.load("res://build_stamp.cfg")
print(stamp.get_value("build", "version"), " built ", stamp.get_value("build", "stamped_at"))
```

The timestamp is read when the tool *runs*, never baked into the generated script, so saving the sheet twice produces identical code - the same determinism rule every compiled sheet follows.

Four practical notes:

- **Keep a bake step synchronous.** An export cannot wait for a row that waits: the moment the handler hits an `await`, the exporter carries on packaging files, and anything after that point may miss the build. The one Editor Tools verb that waits is **Render Scene To Image** (it waits for a drawn frame), so a thumbnail belongs in a File > Run tool rather than in a bake step. If a bake step does pause, the Output panel says so: "N tool(s) paused on an await and did not finish before the export continued."
- **The sheet must be an Editor Tool sheet** (Sheet Type > Editor Tool, so it compiles to `@tool` + `extends EditorScript`). A node sheet that declares the trigger is skipped with a warning naming the file, because instantiating a node script during an export would leak a node into the editor.
- **Create the file once before you rely on it.** The bake step rewrites the file at export time, and an export reads what is on disk - but a path the project has never seen may not be in the export's file list yet. Run the tool once (File > Run), let the FileSystem dock pick the file up, and every export after that refreshes its contents.
- **Several bake steps run in path order.** If two tools touch the same file, that order is the same on your machine and in CI.

---

## 5. Inspector buttons - any function becomes a button

Any sheet function can become a one-click button in the Inspector. Open the function's dialog and fill in the **Inspector button** field with a label ("Re-bake", "Fill With Test Data", "Snap To Grid"). The compiler emits one line per labeled function:

```gdscript
@export_tool_button("Re-bake") var _btn_rebake: Callable = rebake
```

Select a node (or resource) using that script and the Inspector shows a **Re-bake** button; pressing it runs the function's rows, right there in the editor.

This is the beginner path to editor tools, and it shines on **@tool sheets that live in your scenes** - a level chunk with a "Rebuild Colliders" button, a spawn table resource with a "Roll Ten Samples" button. The button IS the function; its rows are the tool. No EditorScript, no File > Run, no menu - the tool sits next to the data it operates on.

Two rules:

- **The sheet must be a Tool sheet.** `@export_tool_button` only runs its Callable in the editor when the script is `@tool`. The compiler warns you at save time if a function has a button label but the sheet is not tool mode: enable **Tool** in the Sheet Type dialog.
- Leave the field empty and nothing is emitted - the button is strictly opt-in per function.

---

## 6. Live Inspector warnings - required and validate

Tool-mode sheets can also police their own data while a designer edits it, using two variable attributes:

- **Required** - mark an exported variable as required and the Inspector shows a warning badge above the property while it is unset or empty (a Resource slot left null, a String left `""`).
- **Validate** - point a variable at a sheet function that returns a warning String (`""` means valid). While the property is edited, the editor calls the function and shows the returned message above the field, live. Needs a @tool sheet to run in-editor; it is silent otherwise.

You do not have to wire validate by hand. One call does it:

```gdscript
EventSheets.attach_validator(sheet, "max_health")
```

This creates a `validate_max_health` sheet function (a ready-to-edit condition/action skeleton returning a warning String), wires the variable's `validate` attribute to it, and reuses the function if it already exists. The Custom Resource wizard's "Add a validation check" box calls exactly this, so ticking that box in the wizard is the no-code path.

A typical validator body, as rows:

```
Function: validate_max_health  (returns String)
  Condition: max_health <= 0
    -> Return  "Max health must be positive."
  -> Return  ""
```

---

## 7. Undo done right

An editor tool that adds, removes, or reparents nodes in the open scene should register those changes with the editor's undo system - otherwise Ctrl+Z cannot take them back, and one mis-aimed run can wreck a scene someone spent an hour arranging.

**The Doctor watches for this.** The Project Doctor has a dedicated check: any tool-mode sheet whose compiled script touches the edited scene (`get_edited_scene_root`) and mutates it (`add_child`, `remove_child`, `queue_free`, `reparent`, sets `owner`) without any `create_action` / `EditorUndoRedoManager` in sight gets an **info** finding:

> This editor tool changes the open scene (add/remove/reparent nodes) without registering undo, so Ctrl+Z can't take the change back. Wrap the edits in EditorInterface.get_editor_undo_redo() create_action/commit_action (ignore for one-off scripts you re-run freely).

It is info-level on purpose: a throwaway script you re-run freely does not need undo. A tool teammates click does.

**The pattern.** Undo registration is a paired do/undo recipe, so it lives in a GDScript block inside your On Editor Run event:

```gdscript
var undo := EditorInterface.get_editor_undo_redo()
var parent := EditorInterface.get_edited_scene_root()
var marker := Marker2D.new()
marker.name = "SpawnPoint"
undo.create_action("Add spawn point")
undo.add_do_method(parent, "add_child", marker)
undo.add_do_property(marker, "owner", parent)
undo.add_do_reference(marker)
undo.add_undo_method(parent, "remove_child", marker)
undo.commit_action()
```

One `create_action` per user-facing step, `add_do_*` for the change, `add_undo_*` for its exact reverse, `commit_action` to seal it (which also performs the do side). After the run, Ctrl+Z in the editor removes the spawn point again. Keep the rest of the tool - the guards, the loops over Selected Nodes, the prints - as ordinary rows, and reach for the code block only for this paired recipe.

Tools that only *read* (scene checks, reports) or only write *files* (generators guarded by Resource Exists) never need any of this, and the Doctor will not bother you about them.

---

## 8. Use cases

Every walkthrough below is an event sheet you can build today. EditorScript tools start from **Sheet > New Editor Tool…** and run with File > Run; the Inspector-button ones are @tool sheets on a node or resource.

### 1. Scene node census (the starter, verbatim)

The scaffolded chore: report how big the open scene is.

```
On Editor Run
  -> GDScript block:
     var scene_root: Node = EditorInterface.get_edited_scene_root()
     if scene_root == null:
         print("Open a scene first.")
     else:
         print("%s has %d nodes." % [scene_root.name, scene_root.get_child_count()])
```

Run it on your biggest scene and you have a free complexity check. Grow it by walking children and counting per-type.

### 2. Batch-rename the selected nodes

Select twenty copy-pasted `Sprite2D`s in the Scene dock, run, get `Coin_1` … `Coin_20`.

```
On Editor Run
  -> GDScript block:
     var i := 1
     for node in EditorInterface.get_selection().get_selected_nodes():
         node.name = "Coin_%d" % i
         i += 1
  -> Editor Tools: Save Current Scene
```

The loop body is two lines, and the **Selected Nodes** expression is the same array if you prefer to feed it into a For Each.

### 3. Drop a configured node into the scene

One click adds a spawn marker under the scene root - created, parented, AND owned, so it survives the save.

```
On Editor Run
  -> Editor Tools: Add Node To Edited Scene   node: Marker2D.new()   parent: Edited Scene Root
  -> Editor Tools: Save Current Scene
```

Add Node To Edited Scene is the row that makes this safe: doing it by hand and forgetting `owner` means the node evaporates on save.

### 4. Extract the selected node into its own scene

Turn an in-place built enemy into a reusable `.tscn`.

```
On Editor Run
  -> GDScript block:
     var picked: Array = EditorInterface.get_selection().get_selected_nodes()
     if picked.is_empty():
         print("Select the node to extract first.")
         return
  -> Editor Tools: Save Node As Scene   node: picked[0]   path: "res://scenes/extracted.tscn"
  -> Editor Tools: Rescan Project Files
```

Save Node As Scene packs the node and its children into a PackedScene and writes the file; the rescan makes it show up in the FileSystem dock immediately.

### 5. Project folder skeleton generator

Every new project wants the same folders. Make it one run.

```
On Editor Run
  -> Editor Tools: Make Sure Folder Exists   "res://scenes"
  -> Editor Tools: Make Sure Folder Exists   "res://scripts"
  -> Editor Tools: Make Sure Folder Exists   "res://art/sprites"
  -> Editor Tools: Make Sure Folder Exists   "res://audio/sfx"
  -> Editor Tools: Rescan Project Files
```

Parents are created too, so `res://art/sprites` works even when `res://art` does not exist yet.

### 6. Create the default settings file, exactly once

A generator that is safe to run any number of times, because a condition guards it.

```
On Editor Run
  Condition: (invert) Editor Tools: Resource Exists   "res://data/settings.tres"
    -> Editor Tools: Save Resource To File   resource: GameSettings.new()   path: "res://data/settings.tres"
    -> Editor Tools: Rescan Project Files

On Editor Run
  Condition: Editor Tools: Resource Exists   "res://data/settings.tres"
    -> System: Print   "settings.tres already there - nothing to do."
```

**Resource Exists** is the idempotence guard; the second event just makes reruns talk instead of staying silent.

### 7. Scene sanity check that points at the offender

A read-only linter: find every `Sprite2D` with no texture, and put the first one in front of you.

```
On Editor Run
  -> GDScript block:
     var bad: Array[Node] = []
     for node in EditorInterface.get_edited_scene_root().find_children("*", "Sprite2D"):
         if node.texture == null:
             bad.append(node)
     if bad.is_empty():
         print("All sprites have textures.")
         return
     print("%d sprites missing textures." % bad.size())
  -> Editor Tools: Select Node In Editor   bad[0]
  -> Editor Tools: Inspect In Editor       bad[0]
```

Select Node In Editor highlights it in the Scene dock and Inspect In Editor opens it in the Inspector - the tool does not just complain, it takes you there.

### 8. One-key playtest of the arena scene

Whatever you are working on, jump straight into the level you always test in.

```
On Editor Run
  -> Editor Tools: Save Current Scene
  -> Editor Tools: Open Scene In Editor   "res://scenes/arena.tscn"
  -> Editor Tools: Play Current Scene
```

Save what you had, open the arena, play it. Bind the script to a shortcut via Godot's editor settings and it is genuinely one key.

### 9. Select everything in a group

"Where are all the checkpoints in this scene?" - answered by the Scene dock lighting up.

```
On Editor Run
  -> GDScript block:
     EditorInterface.get_selection().clear()
     for node in EditorInterface.get_edited_scene_root().find_children("*"):
         if node.is_in_group("checkpoint"):
             EditorInterface.get_selection().add_node(node)
```

From there, every Inspector edit is a multi-edit across the whole group.

### 10. Snap the selected nodes to the grid, with undo

The classic layout chore, done politely: Ctrl+Z restores the old positions.

```
On Editor Run
  -> GDScript block:
     var undo := EditorInterface.get_editor_undo_redo()
     undo.create_action("Snap selection to grid")
     for node in EditorInterface.get_selection().get_selected_nodes():
         if node is Node2D:
             undo.add_do_property(node, "position", (node.position / 32.0).round() * 32.0)
             undo.add_undo_property(node, "position", node.position)
     undo.commit_action()
```

Because it registers undo, the Doctor's editor-tool-undo check has nothing to say, and neither does the teammate whose careful off-grid nudge you just rounded away.

### 11. A "Re-bake" Inspector button on a level chunk

The @tool-node flavor. A level-chunk sheet (Tool enabled in Sheet Type) has a `rebuild_colliders` function; open the function dialog and set **Inspector button** to `Re-bake`.

```
Function: rebuild_colliders
  -> (rows that delete the old StaticBody2D children and rebuild them from the tilemap)
```

Compiles to `@export_tool_button("Re-bake") var _btn_rebuild_colliders: Callable = rebuild_colliders`. Select the chunk in any scene and the Inspector shows a Re-bake button; pressing it runs the rows. No EditorScript, no File > Run.

### 12. A "Fill With Test Data" button on a Custom Resource

Data assets can carry their own tools. On a `LootTable` Custom Resource sheet (Tool enabled), give a function a button label:

```
Function: fill_with_test_data      Inspector button: "Fill With Test Data"
  -> Variables: Set entries to ["sword", "shield", "potion", "gold"]
  -> Variables: Set fallback to "coin"
```

Every `.tres` made from the resource now has the button in its Inspector - designers stamp out believable test assets in one click instead of typing arrays.

### 13. Live validation on a designer-facing field

Stop bad data at the door instead of debugging it at runtime. Call `EventSheets.attach_validator(sheet, "spawn_interval")` (or tick "Add a validation check" in the Custom Resource wizard), then edit the generated skeleton:

```
Function: validate_spawn_interval  (returns String)
  Condition: spawn_interval <= 0.0
    -> Return  "Spawn interval must be greater than zero."
  -> Return  ""
```

While anyone edits `spawn_interval` in the Inspector, the message appears live above the field the moment the value goes non-positive, and vanishes when it is fixed.

### 14. A required resource slot that badges until filled

A boss sheet that is broken without its phase table should say so in the Inspector, not crash at runtime. Mark the exported `phase_table` variable **required** (in the variable's Inspector attributes) and the editor shows a warning badge above the property while the slot is still null. Pair it with a validator for deeper checks:

```
Function: validate_phase_table  (returns String)
  Condition: phase_table != null and phase_table.phases.is_empty()
    -> Return  "Phase table has no phases."
  -> Return  ""
```

Required covers "empty"; validate covers "filled in wrong".

### 15. Editor-scale-aware tool output

If a tool builds any editor-side UI (a debug overlay, a generated Control), size it with the **Editor Scale** expression so it looks right on hiDPI machines:

```
On Editor Run
  -> Editor Tools: Add Node To Edited Scene   node: Label.new()   parent: Edited Scene Root
  -> GDScript block:
     var label := EditorInterface.get_edited_scene_root().get_node("Label")
     label.text = "PLACEHOLDER - replace before ship"
     label.scale = Vector2.ONE * EditorInterface.get_editor_scale()
```

At 200% editor scale the marker label doubles with everything else instead of turning into fine print.

### 16. A pre-commit scene audit you run before every push

Chain the read-only checks into one report: count nodes, list missing textures, flag nodes still named `Node2D`, and print a single verdict line you can trust at a glance.

```
On Editor Run
  -> Functions: Call check_missing_textures
  -> Functions: Call check_default_names
  -> GDScript block:
     print("Scene audit done - see lines above. Clean if nothing was flagged.")
```

Each check is a sheet function (so the audit reads as a table of contents), and because nothing mutates, it is safe to run on any scene at any time.

### 17. Thumbnails for every level, in one run

The level-select screen wants a picture per level, and taking them by hand is the chore nobody does twice.

```
On Editor Run
  -> For Each level in ["forest", "caves", "summit"]
       -> Editor Tools: Render Scene To Image
            scene_path: "res://levels/%s.tscn" % level
            width: 320   height: 180
            save_path: "res://ui/thumbs/%s.png" % level
  -> Editor Tools: Rescan Project Files
```

Each level scene needs its own camera framing the shot. Re-run after any art change and every card in the menu is current again. The same row bakes store screenshots at 1920x1080, or renders a 3D prop at 128x128 to use as a 2D icon.

### 18. Check the loot odds before a player does

You wrote the weights. This tells you what they mean.

```
On Editor Run
  -> Editor Tools: Preview Table Rolls
       table: "res://data/boss_drops.tres"
       rolls: 10000   seed: 1
       save_path: "res://data/boss_drops_odds.txt"
```

Read the report in the Output panel, then keep the file next to the table. Change a weight, run again with the same seed, and diff the two reports: only the balance change moved. A Dictionary works just as well when the odds still live in your head - `{"nothing": 70, "coin": 25, "relic": 5}`.

### 19. Stamp the build number into every export

The support question "which build are you on?" answered by the build itself.

```
On Project Export
  -> Editor Tools: Write Version Stamp   path: "res://build_stamp.cfg"   version: ProjectSettings.get_setting("application/config/version", "0.0.0")
```

Read it back on your title screen and show it in the corner. Because the trigger fires on every export, the stamp can never be stale - there is no step to forget. And if the file cannot be written (a folder that does not exist, a read-only checkout), the action warns with the reason rather than leaving you reading yesterday's build number.

### 20. Ship different data to mobile, and no test content to release

One bake step, two guards, three outcomes.

```
On Project Export
  Condition: Editor Tools: Export Has Feature   "mobile"
    -> Editor Tools: Save Resource To File   resource: load("res://data/quality_low.tres")   path: "res://data/quality.tres"

On Project Export
  Condition: (invert) Editor Tools: Export Is Debug
    -> GDScript block:
       DirAccess.remove_absolute("res://data/debug_unlocks.tres")
       print("release export - debug unlocks removed")
```

The mobile preset gets the low-quality settings resource; the release build loses the debug unlocks; the debug build keeps everything. No branch of this lives in your game code.

### Other use cases

- **Placeholder sweeper.** Walk the open scene for nodes in a `placeholder` group, print each one's path, and Select Node In Editor the first - the pre-ship "did we leave any grey boxes in" button.
- **Scene screenshot lister.** For each `.tscn` in a folder, Open Scene In Editor and print which ones are missing a matching thumbnail file, so the level-select screen never ships a blank card.
- **Autoload data refresher.** Rebuild a generated `.tres` (drop tables, localization indexes) from source data with Save Resource To File, then Rescan Project Files - the "regenerate everything" button for data pipelines.
- **Nightly-save panic button.** Stop Playing, Save Current Scene, and print a timestamp - one run that gets you out of a playtest with everything written to disk.
- **Onboarding tour script.** Open Scene In Editor on the project's main scene, Select Node In Editor on the player, Inspect In Editor its stats resource - a runnable "start here" for new teammates.

---

## 9. Troubleshooting

- **File > Run is greyed out or does nothing.** You must have the *compiled script* (the `.gd`) open and focused in Godot's script editor - not the sheet tab. Save the sheet first so the script exists and is fresh, open it, then Ctrl+Shift+X.
- **"Open a scene first." / null scene root.** `Edited Scene Root` is null when no scene is open in the editor. Tools that act on the open scene should guard for it, exactly like the starter does.
- **The node my tool added disappeared when I saved the scene.** Its `owner` was never set, so the scene save skipped it. Use **Add Node To Edited Scene**, which parents the node AND sets its owner in one row.
- **My tool wrote a file but the FileSystem dock does not show it.** The dock scans on its own schedule. End the tool with **Rescan Project Files**.
- **The Inspector button does not appear (or does nothing).** The sheet must be a Tool sheet - `@export_tool_button` only runs in the editor under `@tool`. The compiler warns on save: "Tool buttons need a @tool sheet to run in the editor - enable Tool in the Sheet Type dialog." Also re-select the node after recompiling so the Inspector rebuilds.
- **My validator never shows its message.** Same root cause: validate runs in-editor only on @tool sheets, and it is silent otherwise. Check Tool in the Sheet Type dialog, and make sure the function returns `""` (not nothing) for the valid case.
- **The Doctor flagged "editor-tool-undo" - do I have to fix it?** It is an info finding, not an error. For a one-off script you re-run freely, ignore it. For a tool other people click, wrap the scene edits in `EditorInterface.get_editor_undo_redo()` `create_action` / `commit_action` as shown in section 7, and the finding goes away.
- **Editor Tools actions crash in the running game.** `EditorInterface` exists only in the editor process. Keep Editor Tools verbs in Tool sheets; in a @tool node sheet that also runs in-game, gate editor-only rows behind the **Is In Editor** condition.
- **Ctrl+Z after a run undoes nothing.** Direct mutations (plain `add_child`, plain property sets) bypass the editor's undo history by design. Only changes registered through `create_action` / `add_do_*` / `add_undo_*` / `commit_action` are undoable.
- **Render Scene To Image wrote nothing and warned about a display.** You ran it in a headless Godot (`--headless`, a CI job). There is no renderer there, so the action refuses rather than saving a blank file. Run it from the normal editor.
- **The rendered PNG is empty (or transparent).** The scene has nothing photographing it. Add a `Camera2D` / `Camera3D` to the scene you are rendering (a 3D scene also needs a light), or render a `Control` scene, which needs neither.
- **Preview Table Rolls printed "no entry has a weight above zero".** The table it read had entries, but every weight was zero or negative - fill in the resource's `entries` grid. If the path is the problem instead, the report says that in its own words: "no table at res://...", naming the path it could not find.
- **The rolled percentages change every run.** They should not - the seed is a parameter. If they move, the **Seed** field is being fed something that changes (a call to `randi()`, a time value). Put a plain number in it.
- **My On Project Export step never ran.** Three things to check, in order: the sheet's type is **Editor Tool** (a node sheet is skipped, with a warning naming the file in the Output panel); the sheet has been saved since you added the trigger, so the compiled `.gd` actually declares the handler; and the file you are exporting to is a *project* export, not a "play the scene" run.
- **The file my bake step writes is not in the exported build.** The export reads what is on disk, so a file the project has never seen may not be in its file list yet. Run the tool once with File > Run, let the FileSystem dock index the new file, and later exports pick up the refreshed contents.
