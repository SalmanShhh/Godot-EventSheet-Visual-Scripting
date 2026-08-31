# Working With Files

Reading and writing on disk, from rows. **Write Text File** and **Read Text File** are a save system's
two halves. **File Exists** guards them. **Make Directory**, **List Files** and **List Subdirectories**
turn a folder into something a sheet can walk. And the JSON set crosses the text boundary in both
directions, so a dictionary of player state becomes one line in a file and comes back as a dictionary
again.

These rows are builtin vocabulary: nothing to enable, nothing to attach, available in the picker from
any sheet. Each compiles to the exact native `FileAccess`, `DirAccess` or `JSON` call. The reads use
the static, null-safe accessors on purpose - a missing file gives you empty text rather than a crash -
and the writes guard the file handle, so a bad path cannot null-dereference.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Why writes belong under user://](#why-writes-belong-under-user)
4. [Reference tables](#reference-tables)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Save games** - a dictionary of state, written as JSON and read straight back into a variable.
- **Settings files** - volume, resolution and keybinds in a file the player could edit by hand.
- **Save slots** - three files in a folder, listed and shown as a menu.
- **Backups** - copy the save aside before overwriting it.
- **Logs** - append a line per event to a text file you can read after a crash.
- **Level data** - a JSON file per level, loaded on demand.
- **Screenshot galleries** - list a folder of PNGs the game wrote earlier.
- **Mod folders** - a directory the player drops files into, listed at startup.
- **Importing** - paste a blob of JSON, validate it, then parse it.
- **Migration** - read the old file, write the new one, delete the old.
- **Custom avatars and soundtracks** - a picture or a track the player drops on the window, or picks
  out of their own file chooser, loaded straight into a variable.

## Core concepts

- **Reads are forgiving, writes are not.** **Read Text File** on a missing path gives `""`, and
  **List Files** on a missing folder gives an empty list. Writing to a path whose folder does not
  exist simply does nothing, silently. Make the directory first.
- **Write overwrites, Append adds.** **Write Text File** replaces the whole file. **Append To File**
  needs the file to already exist and does nothing if it does not, so write it once before appending.
- **JSON is a text boundary, not a data type.** **To JSON Text** turns a value into a string and
  **From JSON Text** turns a string back into a value. Once parsed, what you hold is an ordinary
  Dictionary or Array; edit it with the Variables vocabulary, not with anything here.
- **Invalid JSON parses as nothing.** **From JSON Text**, **Parse JSON Into Variable** and
  **Load JSON File** all give `null` when the text is bad or the file is missing. Guard with
  **JSON Is Valid**, or check the result before reading fields off it.
- **The two "delete" actions are the same call.** **Delete File** and **Remove Directory** both compile
  to `DirAccess.remove_absolute`, which only removes an EMPTY directory. Clear a folder's files before
  removing the folder.
- **Paths are expressions.** Every path parameter takes any expression, so
  `"user://slot_" + str(slot) + ".json"` is a perfectly ordinary path.

## Why writes belong under `user://`

`res://` is your project folder. In the editor it is a real, writable directory, which is exactly why
this trap survives testing: a save written to `res://save.dat` works perfectly right up until you
export. In an exported game `res://` lives inside the packed archive and is **read-only**. Every write
to it fails, and because the write actions guard the handle rather than crashing, they fail quietly.

`user://` is the per-user writable folder the engine provides on every platform (an application-data
directory on desktop, the sandboxed container on mobile and web). Every write path in this module
defaults to `user://` for that reason, and every path hint says so.

The rule in one line: **read from `res://`, write to `user://`**. Ship your level data, tables and
defaults under `res://`; put saves, settings, logs and screenshots under `user://`.

## Reference tables

Ships as is the template the row compiles to. Where a template carries `{uid}`, the editor bakes a
short per-row id into the local's name when you drop the row, so two of the same action in one script
never collide.

### Files

| Name | What it does | Ships as |
|------|--------------|----------|
| File Exists | True when a file exists at that path, so you can check before reading or writing | `FileAccess.file_exists({path})` |
| Read Text File | The whole file's contents as text, empty if missing or unreadable | `FileAccess.get_file_as_string({path})` |
| File Size (bytes) | A file's size in bytes, or zero if it does not exist | `FileAccess.get_file_as_bytes({path}).size()` |
| Write Text File | Saves text to a file, overwriting anything already there | `var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)` then a guarded `store_string({text})` and `close()` |
| Append To File | Adds text to the end of an existing file without erasing it | `var __file_{uid} = FileAccess.open({path}, FileAccess.READ_WRITE)` then `seek_end()`, `store_string({text})`, `close()` |
| Delete File | Permanently deletes a file (or an empty folder) from disk | `DirAccess.remove_absolute({path})` |
| Copy File | Copies a file to another path, leaving the original in place | `DirAccess.copy_absolute({from}, {to})` |
| Move / Rename File | Moves or renames a file or folder to a new path | `DirAccess.rename_absolute({from}, {to})` |

### Files: Directories

| Name | What it does | Ships as |
|------|--------------|----------|
| Directory Exists | True when a folder exists at that path | `DirAccess.dir_exists_absolute({path})` |
| Make Directory | Creates a folder, building any missing parent folders along the way | `DirAccess.make_dir_recursive_absolute({path})` |
| Remove Directory | Deletes an EMPTY folder (clear out its files first) | `DirAccess.remove_absolute({path})` |
| List Files | The list of file names inside a folder, empty if the folder is missing | `DirAccess.get_files_at({path})` |
| List Subdirectories | The list of subfolder names inside a folder | `DirAccess.get_directories_at({path})` |

### JSON

| Name | What it does | Ships as |
|------|--------------|----------|
| To JSON Text | Turns a dictionary, array, number, string or bool into compact JSON text | `JSON.stringify({value})` |
| To JSON Text (pretty) | The same, indented with tabs so a human can read it | `JSON.stringify({value}, "\t")` |
| From JSON Text | Reads JSON text back into a usable value, nothing when invalid | `JSON.parse_string({text})` |
| Parse JSON Into Variable | Parses JSON text and stores the result in a variable | `{var_name} = JSON.parse_string({text})` |
| JSON Is Valid | True when the given text is valid JSON | `JSON.parse_string({text}) != null` |
| Save JSON File | Serializes a value to pretty JSON and writes it to a file in one step | `var __json_{uid} = FileAccess.open({path}, FileAccess.WRITE)` then a guarded `store_string(JSON.stringify({value}, "\t"))` |
| Load JSON File | Reads a JSON file and parses it straight into a variable | `{var_name} = JSON.parse_string(FileAccess.get_file_as_string({path}))` |

### Files: content from outside the project

Every row above works on a path the sheet already holds. These are the rows for a file the *player*
names - one they drop on the window, one they pick out of their own system's chooser - and the two
loaders that turn such a path into a picture or a sound.

An ask has **no return value**, on purpose. A chooser is a separate window, and the player answers it
whenever they are ready, which is long after the row ran. So the answer arrives as an event, and the
emitted line calls that event's function by name: a sheet with an **Ask** row and no **On a file
chosen** event writes a call to a function that is not there. Add both events when you add the ask.

| Name | What it does | Ships as |
|------|--------------|----------|
| On Files Dropped | Runs when the player drags files onto the game window and lets go (desktop only) | `get_window().files_dropped.connect(_on_files_dropped)` in `_ready`, handler `_on_files_dropped(files: PackedStringArray)` |
| Ask For A File To Open | Opens the player's own file chooser so they can pick a file to read | `if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):` then `DisplayServer.file_dialog_show(…, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, {filters}, …)`, `else:` a `FileDialog` with `ACCESS_FILESYSTEM` |
| Ask Where To Save | Opens the player's own save chooser so they can name a file and a folder | The same branch, with `FILE_DIALOG_MODE_SAVE_FILE` / `FILE_MODE_SAVE_FILE` |
| On A File Chosen | Runs when the player answered an Ask row by picking a file | `func _on_file_chosen(path: String) -> void:` |
| On The Ask Cancelled | Runs when the player closed an Ask row's chooser without picking anything | `func _on_ask_cancelled() -> void:` |
| Image From File | A picture from outside the project, as a texture | `ImageTexture.create_from_image(Image.load_from_file({path}))`, with ` if FileAccess.file_exists({path}) else {fallback}` when the fallback slot is filled |
| Sound From File | A sound from outside the project, as an audio stream | `AudioStreamMP3.load_from_file({path})` / `AudioStreamOggVorbis…` / `AudioStreamWAV…`, chosen by extension, with the same optional `file_exists` guard |

![One event in a sheet called AvatarPicker: a green arrow trigger badge, the object Node, a files payload chip, and one action, System Set avatar to ImageTexture.create_from_image(Image.load_from_file(files' item 0))](../images/user-content-drop.png)

![Three events in the same sheet: ChooseButton On Pressed with the action System Ask for a file to open (PackedStringArray(["*.png;Images"])), then System On A File Chosen with System Set avatar to ImageTexture.create_from_image(Image.load_from_file(path)), then System On The Ask Cancelled with StatusLabel Set text to "Kept the old picture."](../images/user-content-ask.png)

**No import pipeline is involved, and none is wanted.** A loaded image is a texture in a variable and
a loaded sound is an audio stream in one: they live as long as something holds them and no longer,
they are not `.import`ed, and they never become project resources. That is the honest shape for
content the game did not ship with.

**This is not the save system.** The game's own state belongs to the Save System pack's verbs, which
write under `user://` with no chooser in sight. These rows are for content the *player* brings: a
portrait, a custom track, a level file somebody sent them.

**User content is data, never code.** Nothing here loads a script, a scene or a resource, and nothing
here evaluates what it read. A dropped file is bytes and a path.

## Use cases

**1. The whole save system, in two rows.** Save JSON File and Load JSON File collapse the write and
the parse into one row each.

```
On save pressed
  -> Save JSON File  "user://save.json", save

On Ready
  -> Load JSON File  save, "user://save.json"
```

```gdscript
func _ready() -> void:
	save = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
```

**2. Do not load a save that is not there.** Load JSON File on a missing path leaves the variable
holding `null`, which turns the first field read into an error. Guard it.

```
On Ready
  Condition: File Exists  "user://save.json"
    -> Load JSON File  save, "user://save.json"
  Else
    -> set save = {"level": 1, "score": 0}
```

**3. Save slots.** The path is an expression, so the slot number just goes into it.

```
On slot chosen
  -> Save JSON File  "user://slot_" + str(slot) + ".json", save
```

**4. Show which slots are filled.**

```
On save menu opened
  -> Repeat 3 times
       Condition: File Exists  "user://slot_" + str(loopindex) + ".json"
         -> mark slot loopindex as used
       Else
         -> mark slot loopindex as empty
```

**5. Back the save up before overwriting it.**

```
On save pressed
  Condition: File Exists  "user://save.json"
    -> Copy File  "user://save.json", "user://save.bak"
  -> Save JSON File  "user://save.json", save
```

**6. A settings file a player could edit.** To JSON Text (pretty) writes it indented.

```
On settings changed
  -> Write Text File  "user://settings.json", To JSON Text (pretty)(settings)
```

```gdscript
func _on_settings_changed() -> void:
	var __file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if __file:
		__file.store_string(JSON.stringify(settings, "\t"))
		__file.close()
```

**7. A log file.** Write once to create it, then append a line at a time.

```
On Ready
  -> Write Text File  "user://log.txt", "session started\n"

On enemy killed
  -> Append To File  "user://log.txt", "killed " + enemy_name + "\n"
```

Append To File does nothing at all on a file that does not exist, which is why the Write row comes
first.

**8. Make the folder before you write into it.** A write into a folder that is not there fails
silently, and Make Directory builds every missing parent.

```
On run finished
  -> Make Directory  "user://replays"
  -> Save JSON File  "user://replays/" + run_id + ".json", replay
```

**9. Check a folder exists before listing it.**

```
On mods scanned
  Condition: Directory Exists  "user://mods"
    -> set mod_files = List Files("user://mods")
  Else
    -> Make Directory  "user://mods"
```

**10. Build a menu from a folder.** List Files gives names, not paths, so store the list and join the
folder back on as you walk it.

```
On replay menu opened
  -> set replay_files = List Files("user://replays")
  -> For Each item of replay_files
       -> add a menu row labelled item
       -> remember its path as "user://replays/" + item
```

**11. Walk a tree of folders.** List Subdirectories is the other half.

```
On profile menu opened
  -> set profiles = List Subdirectories("user://profiles")
```

**12. Delete a save.** Delete File is permanent and has no undo.

```
On delete slot confirmed
  -> Delete File  "user://slot_" + str(slot) + ".json"
```

**13. Empty a folder and then remove it.** Remove Directory only removes an EMPTY folder, so the
files have to go first.

```
On profile deleted
  -> For Each item of List Files("user://profiles/" + name)
       -> Delete File  "user://profiles/" + name + "/" + item
  -> Remove Directory  "user://profiles/" + name
```

**14. Rename a profile.** Move / Rename File works on folders as well as files.

```
On profile renamed
  -> Move / Rename File  "user://profiles/" + old_name, "user://profiles/" + new_name
```

**15. Refuse a save that is suspiciously large.** File Size (bytes) reads 0 for a missing file, so the
same row also catches "not there".

```
On load pressed
  Condition: File Size (bytes)("user://save.json") > 0
  Condition: File Size (bytes)("user://save.json") < 1000000
    -> Load JSON File  save, "user://save.json"
  Else
    -> show "That save file cannot be read."
```

**16. Validate pasted text before parsing it.** JSON Is Valid is the gate on a paste box or an import
button.

```
On import pressed
  Condition: JSON Is Valid  ImportBox.text
    -> Parse JSON Into Variable  imported, ImportBox.text
    -> apply the imported loadout
  Else
    -> show "That is not valid data."
```

**17. Parse text you already hold.** From JSON Text is the expression form, for when the JSON came
from somewhere other than a file - a server reply, the clipboard, a table cell.

```
On server replied
  -> set leaderboard = From JSON Text(response_body)
```

**18. Read a level definition shipped with the game.** Level data belongs under `res://`, and reading
from there is fine in an export.

```
On level starts
  -> Load JSON File  level_data, "res://levels/level_" + str(level) + ".json"
```

**19. Compact JSON when a human will never read it.** To JSON Text has no indentation, so a share
payload or a network body stays small.

```
On share pressed
  -> Set Clipboard Text  To JSON Text(loadout)
```

**20. Read a file as raw text when it is not JSON at all.** Read Text File is the generic reader: a
CSV, a changelog, a licence, a shader source.

```
On credits opened
  -> set CreditsLabel text = Read Text File("res://credits.txt")
```

**21. A custom avatar, dropped on the window.** On Files Dropped hands you every path at once, so the
first one is the picture and Image From File is the whole read.

```
On files dropped files
  -> set AvatarRect texture = Image From File(files[0], AvatarRect.texture)
```

**22. The same avatar, asked for instead of dropped.** The ask opens the player's own chooser, and the
answer comes back as its own event - which is also where the picture is actually loaded.

```
On avatar button pressed
  -> Ask For A File To Open  PackedStringArray(["*.png,*.jpg;Images"])

On a file chosen path
  -> set AvatarRect texture = Image From File(path, AvatarRect.texture)

On the ask cancelled
  -> set StatusLabel text = "Kept the old picture."
```

**23. A player-supplied soundtrack.** Sound From File reads the three formats the engine decodes at
runtime, and the fallback keeps the shipped track playing when the file is not one of them.

```
On files dropped files
  -> set MusicPlayer stream = Sound From File(files[0], MusicPlayer.stream)
  -> Play Sound  MusicPlayer
```

**24. Exporting a level the player made.** Ask Where To Save collects a path and writes nothing; the
write is the row after it, in the answer event, where the path exists.

```
On export pressed
  -> Ask Where To Save  PackedStringArray(["*.json;Level file"])

On a file chosen path
  -> Write Text File  path, To JSON Text (pretty)(level)
```

### Other use cases

**Crash breadcrumbs.** Append one line per major event to `user://log.txt` and ask players to attach the file to a bug report, so a hard-to-reproduce fault arrives with its own history.

**Screenshot gallery.** Take Screenshot writes PNGs into `user://shots`, and List Files turns that folder into an in-game gallery with no index file to maintain.

**Cloud-save merge.** Read both the local and the downloaded save, compare their stored timestamps, and write the newer one back with Save JSON File before the game loads it.

**Level editor export.** Serialize the tile grid with To JSON Text (pretty) and Write Text File into `user://levels`, so a player-made level is a text file they can share as-is.

**Config-driven balance.** Ship the tuning numbers as a `res://balance.json`, load them on ready, and let a copy in `user://` override it when it exists, so testers can retune without a rebuild.

## Tips and common mistakes

- **`res://` is read-only in an exported game.** Every write path here defaults to `user://` for that
  reason. A save that works in the editor and vanishes after export is nearly always this.
- **A failed write is silent.** The write actions guard the file handle, so a bad path does nothing
  rather than crashing. If a file never appears, check the folder exists and the path starts with
  `user://`.
- **Write Text File overwrites the whole file.** There is no "insert" and no partial write. Read,
  change the text, write it back.
- **Append To File does nothing on a file that is not there.** It opens READ_WRITE, which fails on a
  missing path. Write the file once first.
- **Make the directory first.** Writing into `user://replays/x.json` when `user://replays` does not
  exist quietly fails. Make Directory is recursive, so one call builds the whole chain, and calling it
  on a folder that already exists is harmless.
- **Remove Directory only removes an EMPTY folder.** Delete the files inside it first.
- **Delete File is permanent.** There is no trash. Copy File first if the player might want it back.
- **A missing file reads as empty, not as an error.** Read Text File gives `""` and File Size (bytes)
  gives 0. That is convenient, but it means "empty file" and "no file" look identical downstream - use
  File Exists when the difference matters.
- **Invalid JSON parses to nothing, quietly.** Parse JSON Into Variable and Load JSON File both leave
  the variable holding `null` when the text is bad, and the error only shows up at the first field
  read. Guard with JSON Is Valid or File Exists.
- **JSON Is Valid reads a document holding just the word `null` as invalid**, because its template is
  `JSON.parse_string(text) != null`. That is a shipped compatibility promise, so it will not change.
  For a readable reason instead of a yes or no, the **Explain JSON Problem** expression reports the
  line and the message, and branching on its emptiness sidesteps the disagreement entirely.
- **JSON flattens types.** Every number comes back a float, and there is no Vector2 in JSON at all, so
  a saved `Vector2(3, 4)` returns as something else. If you need types to survive exactly, the share
  code rows in the Copying, Sharing And Remembering Values guide encode Godot's own binary Variant
  form instead.
- **JSON dictionary keys are always strings.** A dictionary keyed by numbers goes out as `"1"` and
  comes back as `"1"`, so a lookup by `1` misses.
- **Save JSON File always writes pretty.** If you want compact output on disk, use To JSON Text with
  Write Text File instead.
- **List Files gives names, not paths.** Join the folder back on before opening one.
- **List Files is not recursive.** It lists one folder. Walk subfolders yourself with
  List Subdirectories if you need a tree.
- **On Files Dropped is desktop only.** Windows, macOS and Linux raise it; a web or mobile build never
  does. Keep an Ask For A File To Open button beside it so the feature has a way in everywhere.
- **An Ask row needs both answer events.** The emitted line calls `_on_file_chosen` and
  `_on_ask_cancelled` by name, and those two functions are what On A File Chosen and On The Ask
  Cancelled compile to. Without them the script does not compile.
- **Both Ask rows end in the same two events.** If one sheet asks two different questions, remember
  which one it asked - a variable set just before the ask is enough.
- **Ask Where To Save writes nothing.** It collects a path. The write is a separate row in the answer
  event, which is also the only place the path exists.
- **A dropped or chosen path is a real path on that machine**, not a `res://` or `user://` one. Copy
  the file under `user://` if the game should still have it next time it starts.
- **Sound From File decodes exactly three formats:** `.mp3`, `.ogg` (Ogg Vorbis) and `.wav`. Anything
  else reads as the fallback. This is the engine's own runtime limit, not a choice these rows made.
- **The loaders read the path more than once.** The guard reads it, and the sound chain reads it once
  per format it checks - so put a variable in that field rather than a call with a side effect.
- **A loaded image or sound is not a project resource.** It is not imported, it has no `.import`
  file, and it lives only as long as a variable, a node property or a sheet variable holds it.
- **In an exported project, a converted `res://` text resource is stored with a trailing `.remap`.**
  Listing a `res://` data folder in an export will show names ending `.tres.remap` rather than
  `.tres`, which is a trap when you build a list from file names. The folder rows in the
  Reading Spreadsheets And Data Assets guide trim that suffix for you.
