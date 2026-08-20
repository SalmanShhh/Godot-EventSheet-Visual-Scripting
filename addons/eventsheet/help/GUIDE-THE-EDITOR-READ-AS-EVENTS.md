# The Editor, Read as Events

This editor is written in the language it reads. Open its own repository and the Project bar grows one more folder - **This editor** - listing every file the plugin is built from as a sheet, grouped by what each file does. It is the plainest claim the project can make, and the first page a contributor should read: if the editor's own source reads as events, tool code reads as events.

Nothing here appears in your game. The folder needs two marks side by side - the plugin's `plugin.cfg` **and** the `tools/pack_builders/` folder next to it - and a project that merely installed the plugin has only the first. There is no setting to find and nothing to switch off.

## Table of Contents

1. [Opening the folder](#1-opening-the-folder)
2. [What each group is](#2-what-each-group-is)
3. [The plugin's own sheet](#3-the-plugins-own-sheet)
4. [Editing the editor from inside itself](#4-editing-the-editor-from-inside-itself)
5. [Show the events behind this](#5-show-the-events-behind-this)
6. [What is measured, and where](#6-what-is-measured-and-where)

---

## 1. Opening the folder

**View ▸ Project bar**, then **This editor** at the bottom of it. The Start page carries the same door as a card: *"This is the editor's own project - open its source as sheets"*.

The folder is built the moment it is first opened and forgotten again when it is folded, so a session that never opens it never pays for the scan. Double-clicking a file opens it as a sheet, **read-only**, with `part of this editor · read-only` and an **Edit anyway** chip on its bar.

![The Project bar's This editor folder, with the plugin and readings groups open](images/this-editor-folder.png)

## 2. What each group is

Files are grouped by **role**, not by folder, and the role is derived from the file's own shape:

| Group | What it holds | How it is recognised |
| --- | --- | --- |
| Plugin | the plugin itself | `extends EditorPlugin` |
| Workspace | dock, menus, dialogs | a helper holding a back-reference into the dock |
| Canvas | viewport, row builder, renderer, input | the files that draw rows and read the mouse |
| Readings | sentence grammar, facts, patterns | the files that decide what a row says |
| Importer | open a `.gd` as events | it lives under `importer/` |
| Compiler | events to GDScript | it lives under `compiler/` |
| Vocabulary | modules, registry, picker | the registration modules and the words they hold |
| Manual | docs dock, search, reference | the documentation surface |
| Tests | what the gates pin | `tests/*_test.gd` |
| Command tools | run from the command line | `extends SceneTree` under `tools/` |
| Pack recipes | the behaviors that ship | `tools/pack_builders/` |
| Everything else | the rest of these folders | anything the rules above do not name |

A new file lands in the right group the moment it is written. There is no list to maintain, which is the only way a listing of twelve hundred files stays true.

## 3. The plugin's own sheet

`plugin.gd` is the one file with a bar of its own:

![The plugin's own sheet, with Enabled, Reload, Output and plugin.cfg on its bar](images/this-editor-plugin-bar.png)

- **Enabled ●** is the plugin list's live state. It does not switch the plugin off - taking the editor down from inside itself is the one thing this bar will not do.
- **Reload ↻** is disable-then-enable through the editor, which is exactly what you would otherwise walk to Project Settings ▸ Plugins to press by hand.
- **Output ▾** is the editor's own log filtered to what the reload printed, and nothing else.
- **plugin.cfg ▸** opens the descriptor as setting rows - it is an INI of five keys - and its version row is the same number **Publish new version** bumps, so bumping the plugin is the gesture that bumps a behavior pack.

## 4. Editing the editor from inside itself

**Edit anyway** unlocks the sheet. The first save asks once:

> This file is part of the editor you are using. Saving reloads the plugin (your open sheets are kept). Continue?

with **Save, keep asking** and **Save, always**. After the write, the plugin reloads - *unless the saved file does not parse*. A file with an error is **not** reloaded: the version already running keeps running, and the bar goes red saying so. That refusal is the single thing that makes editing the editor from inside itself survivable, because a reload of a file that does not parse would leave no plugin loaded and no dock to fix it from.

## 5. Show the events behind this

**Ctrl+Shift+Alt-click** any control the plugin built - a toolbar button, a menu - and the file that built it opens as a sheet, at the row that names it. No registry is involved: a control carries the file that made it and the words it was made with, and the row is found the way you would find it, by the words.

The marks are written only while the This-editor folder is on, so an editor installed in a game project carries none of them.

## 6. What is measured, and where

Two numbers, on the same files, from the same walks the editor shows a reader:

- **Does it open?** Every file reaches rows rather than a wall of code. The coverage chip on any opened file's bar shows this, and `tests/handwritten_lift_gate_test.gd` pins it.
- **Do the rows say anything?** A *wordless* row is one with no words of its own: an entry of a list, a bare call, a set to a bare function name. `tests/plugin_reads_itself_test.gd` opens a rotating sample of forty files a day, checks each one round-trips byte-exact, and holds each group under a ceiling measured on the tree rather than guessed.

**Tools ▸ Project Doctor** reports the same numbers per group as notes, clickable straight into the worst file in each - and only while the This-editor folder is on, because answering means opening files.
