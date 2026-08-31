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
| Image From File | A picture from outside the project, as a texture | `ImageTexture.create_from_image(Image.load_from_file({path}))`, wrapped as `(… if FileAccess.file_exists({path}) else {fallback})` when the fallback slot is filled |
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

### Files: Archives

One file that is many files. **Pack Folder Into Zip** writes the files in one folder into a `.zip`
using the engine's own `ZIPPacker`; **Unpack Zip Into Folder** reads one back with `ZIPReader`. Both
loops are emitted into your script, where you can read them.

An unpack is the one row here that handles a path somebody else chose. **An archive entry names its
own path**, and an entry spelled `../../autoexec.cfg` resolves outside the folder the player pointed
at - which is how an unpack becomes a write anywhere on their disk. So every entry's resolved path is
compared against the target folder before a single byte is written, the comparison is in the emitted
code, and an entry that climbs out leaves the loop and raises **On Unpack Refused** with the reason in
it. It leaves the loop rather than returning, so the rows after the unpack still run and the row still
fits inside a sheet function that answers with a value.

Like the Ask rows, the emitted loop calls its three answers **by name**, so a sheet that unpacks needs
an event for each of them or the script does not compile.

| Name | What it does | Ships as |
|------|--------------|----------|
| Pack Folder Into Zip | Writes the files directly in one folder into a `.zip` | `var __packer := ZIPPacker.new()`, `if __packer.open({archive}) == OK:`, then `start_file` / `write_file(FileAccess.get_file_as_bytes(…))` / `close_file` per file |
| Unpack Zip Into Folder | Reads a `.zip` and writes its entries into a folder, guarded | `var __reader := ZIPReader.new()`, the folder made first, then per entry the guard `if not ProjectSettings.globalize_path(__into).simplify_path().begins_with(__root):` before `FileAccess.open(…, FileAccess.WRITE)` |
| On Unpack Progress | Runs once per entry as an unpack writes it | `func _on_unpack_progress(entries: int, bytes: int) -> void:` |
| On Unpack Refused | Runs when the guard stopped an unpack, with the entry and the reason | `func _on_unpack_refused(entry: String, reason: String) -> void:` |
| On Unpack Finished | Runs when an unpack reached the last entry with nothing refused | `func _on_unpack_finished(entries: int, bytes: int) -> void:` |

![Four events in a sheet called ModInstaller, under a head whose files bands read user://pack.zip - read and written and user://mods - read and written with the ZIPReader line echoed beside each: On Created with System Unpack "user://pack.zip" into folder "user://mods", then On Unpack Progress setting Bar value to entries, On Unpack Refused setting Label text to "Refused: " and reason, and On Unpack Finished setting Label text to "Installed " and entries](../images/archive-unpack.png)

### Files: scene files

What the player *built* is not text and not a table: it is a branch of nodes. **Save Branch As Scene
File** writes one out as a `.tscn`, so a level, a room, a ship or a base somebody assembled survives
the game closing.

**The owner walk is the whole row.** `PackedScene.pack` writes out the root plus every node that root
**owns**, and a node added while the game runs is owned by nothing at all. So a plain pack-and-save
saves a scene holding one node, returns OK twice, and loads back empty - a bug nothing reports,
because nothing went wrong. The row walks the branch first and gives every ownerless node under it
the branch root as its owner, and that walk is emitted into your script where you can read it. A node
that already belongs to an instanced scene keeps its own owner and is saved as that instance rather
than as a copy of its insides.

Both failures are answered out loud: a pack can refuse a node that is not in a tree, and a write can
fail on a folder that is not there, a full disk or a read-only path. Either one prints through the
debugger rather than leaving no file and no word.

**Editor Tools ▸ Save Node As Scene is the same job on the other side of the line.** That one packs
the node you are *editing*, from a Tool sheet, where the Scene dock has already set every owner.
This one runs in the game, where nothing has an owner until somebody sets one. Two rows, one job, two
worlds - reach for the one whose world you are in.

**And a scene file is the one file in this guide that can carry behaviour.** A `.tscn` is a table of
resources, and a resource may be a *script*. Building one runs that script with everything your game
can reach. That is exactly right for a scene you shipped and exactly wrong for one that arrived from
somewhere else, so **Scene File Is Data-Only** is the question to ask first: it reads the file's own
resource table as text, builds nothing, and answers false for a scene that carries a script inside it
or points at one from anywhere but `res://`. It reads the one file you name - a scene that file points
at is a separate file with a table of its own.

| Name | What it does | Ships as |
|------|--------------|----------|
| Save Branch As Scene File | Writes a branch of the running game out as a `.tscn`, owner walk first | `for __part_{uid}: Node in __branch_{uid}.find_children("*", "", true, false):` giving every ownerless node an owner, then `PackedScene.new()`, `pack({branch})` and `ResourceSaver.save(…, {path})` with both failures pushed as errors |
| Scene File Is Data-Only | True when a scene file names no code: nothing written inside it, nothing pointed at outside `res://` | one call to the reader the compiler writes into your file, which reads the `[ext_resource]` / `[sub_resource]` table as text |

![Two events above the GDScript they compile to. The first is Keyboard On "save_level" pressed with System Save branch $Level as scene file "user://built_level.tscn"; the second is Keyboard On "load_level" pressed plus System scene file "user://built_level.tscn" is data-only, with System Add layout "user://built_level.tscn" on top as "Built". The code panel below shows the owner walk - a for over find_children with owned false, giving every node whose owner is null the branch as its owner - then PackedScene.new, pack, and ResourceSaver.save with both failures pushed as errors, and the load guarded by __eventsheets_scene_is_data_only](../images/scenes-save-branch.png)

### Watching a folder

Godot raises **no file-change notification at run time** on any platform it ships for. There is
nothing to subscribe to, so the **Folder Watcher** behavior pack does the only honest thing: it
*looks*, on an interval you set, and compares what it saw with what it saw last time - by file name
and by modified time.

Attach it to a node, then start it from a row. The row says the interval out loud, and so does the
band at the top of the sheet: `watching user://mods every 2.0 s`.

Its words, in the shapes they take:

- **Watch Folder** (action) starts looking at a folder every so many seconds. The first look is the
  baseline and raises nothing.
- **Stop Watching** (action) stops looking, and parks the per-frame tick so the node costs nothing.
- **Look Now** (action) takes one look immediately, without waiting for the interval.
- **Is Watching** (condition) is true between Watch Folder and Stop Watching.
- **Watched File Count** and **Watched File Names** (expressions) read back what the last look found,
  after the name filter.
- **On A File Appeared**, **On A File Changed** and **On A File Removed** are the three events one
  look can raise, each handing back the whole path.

![Two events in a sheet called ModFolder, under a head whose files band reads watching user://mods every 2.0 s with watch_folder("user://mods", 2.0) echoed beside it: On Created with FolderWatcher Watch folder "user://mods" 2, and a second On Created with FolderWatcher Stop watching](../images/folder-watcher.png)

**One look costs one directory read**, plus one modified-time question per file that passes the name
filter. Between looks it costs nothing, and a stopped watcher costs nothing at all - the tick is
parked with `set_process(false)`, so the engine stops visiting the node.

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

**25. Installing a mod the player downloaded.** The unpack reports itself, so the progress bar moves
and a hostile archive is refused out loud rather than quietly writing somewhere it should not.

```
On install pressed
  -> Unpack Zip Into Folder  "user://incoming/pack.zip", "user://mods"

On unpack progress entries bytes
  -> set ProgressBar value = entries

On unpack refused entry reason
  -> set StatusLabel text = "Refused " + entry + ": " + reason

On unpack finished entries bytes
  -> set StatusLabel text = str(entries) + " files installed."
```

**26. Bundling a run's replay files to send.** One folder in, one file out, with Ask Where To Save
collecting the destination first.

```
On share replay pressed
  -> Ask Where To Save  PackedStringArray(["*.zip;Replay bundle"])

On a file chosen path
  -> Pack Folder Into Zip  "user://replays", path
```

**27. A mods folder that reloads itself while the game runs.** The watcher polls, so the interval is
your choice and it is on the row. Two seconds is generous for a folder a person edits by hand.

```
On ready
  -> Watch Folder  "user://mods", 2.0

On a file appeared path
  -> Load Mod  path

On a file changed path
  -> Reload Mod  path

On a file removed path
  -> Unload Mod  path
```

**28. Stop watching when nobody is looking.** A watcher is only worth its directory read while the
screen that cares about it is open.

```
On mods screen closed
  -> Stop Watching
```

**29. A level editor that keeps what the player built.** The walk is what makes the file hold more
than its root, and the question is what makes loading one back safe when the file came from somebody
else's machine.

```
On save pressed
  -> Save Branch As Scene File  $Level, "user://built_level.tscn"

On load pressed
+ Scene file "user://built_level.tscn" is data-only
  -> Add Layout On Top  "user://built_level.tscn", "Built"
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
- **A packed scene saves what its root OWNS.** Nodes added while the game runs own nothing, so a
  plain pack writes a scene holding one node and says nothing about it. Save Branch As Scene File
  does the owner walk first, and the walk is in your script where you can read it.
- **A scene file can name a script.** Ask Scene File Is Data-Only before building one that did not
  come with the game. The Doctor's Files section says so on any row that skips the question.
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
- **Both Ask rows want a Node host.** When a platform has no chooser of its own the emitted else
  branch builds a `FileDialog`, adds it as a child and pops it up, so the row is filed on `Node` and
  offered in sheets whose script is one. Nothing about the emitted line changes.
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
  else reads as the fallback, because the line asks about the third extension too rather than letting
  a fourth one fall into the WAV reader. This is the engine's own runtime limit, not a choice these
  rows made.
- **A file that is THERE but unreadable is not a missing file.** The guard on all three loaders is
  `file_exists`, so a truncated `.png` or a `.ogg` that is really something else reaches its reader,
  and the reader answers with null and an engine message rather than with your fallback. Check the
  answer before using it when the file came from outside the game.
- **Safe File Name does not know the reserved device names.** `con`, `prn`, `aux`, `nul` and `com1`
  survive it, because `String.validate_filename` does not treat them specially, and Windows will not
  take a file called any of them. Adding a prefix or suffix of your own - `save_` in front of the
  player's name - is the reliable answer, and it is one row.
- **The loaders read the path more than once.** The guard reads it, and the sound chain reads it once
  per format it checks - so put a variable in that field rather than a call with a side effect.
- **A loaded image or sound is not a project resource.** It is not imported, it has no `.import`
  file, and it lives only as long as a variable, a node property or a sheet variable holds it.
- **An unpack needs all three answer events.** The emitted loop calls `_on_unpack_progress`,
  `_on_unpack_refused` and `_on_unpack_finished` by name, and those three functions are what
  On Unpack Progress / Refused / Finished compile to. Without them the script does not compile.
- **A refused unpack stops where it stopped.** The entries written before the bad one stay written.
  That is deliberate - the sheet is told which entry stopped it, and clearing up is a decision, not
  something a row should make on your behalf.
- **The unpack counts what LANDED, not what it tried.** An entry the machine would not write - a name
  the file system refuses, a folder it could not make, a full disk - moves neither the progress bar
  nor the totals On Unpack Finished carries. A finish saying nine entries after a ten-entry archive
  is a finish saying one did not land.
- **Pack Folder Into Zip is not recursive.** It walks the files directly in that one folder. A whole
  tree needs your own walk with List Subdirectories.
- **A packed archive stores bare file names**, so unpacking one lays its files flat in the target
  folder. That is what makes the round trip in these rows exact.
- **The Folder Watcher is a poll, not a subscription.** Godot has no runtime file watcher, so a
  change is noticed on the next look and no sooner. An interval of 2 seconds means "within two
  seconds", never "immediately".
- **The first look raises nothing.** Watch Folder records what is already there as its baseline. A
  folder that already holds two hundred files is not two hundred things that just happened.
- **A modified time is stamped to the nearest second.** A file written twice inside one second looks
  unchanged to the watcher, which is a real limit of the filesystem rather than of these rows.
- **A program that writes a file in several goes can raise On A File Changed more than once** for
  what a person would call one save. Debounce in your own row if that matters.
- **A watcher under `res://` will never see anything change.** `res://` is packed into the export and
  read-only there, so watch `user://` instead.
- **In an exported project, a converted `res://` text resource is stored with a trailing `.remap`.**
  Listing a `res://` data folder in an export will show names ending `.tres.remap` rather than
  `.tres`, which is a trap when you build a list from file names. The folder rows in the
  Reading Spreadsheets And Data Assets guide trim that suffix for you.
