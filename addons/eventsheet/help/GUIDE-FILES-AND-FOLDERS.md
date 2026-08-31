# Files and Folders - Where a Game May Write, and What It May Trust

A game reads and writes files all day: settings, a log, a screenshot the player wanted to keep, a
level somebody sent them, a folder of mods. Godot gives you two places to put them and a handful of
static calls to do it with, and every row in this guide compiles to exactly those calls. There is no
virtual filesystem here, no wrapper object living between your sheet and the disk, and no import
step. A row that reads a file writes `FileAccess.get_file_as_string(...)` into your script, and a
hand-written `FileAccess.get_file_as_string(...)` opens back as that row.

This page is the lesson. The full reference tables for every verb live in the
[Working With Files](Modules/Working-With-Files.md) module page; what follows is the order to learn
them in and the four or five things that catch everybody.

## Table of Contents

1. [The two places](#the-two-places)
2. [The guard you can see](#the-guard-you-can-see)
3. [A spreadsheet, read as rows](#a-spreadsheet-read-as-rows)
4. [The drop and the ask](#the-drop-and-the-ask)
5. [The watcher, and why it polls](#the-watcher-and-why-it-polls)
6. [One file that is many files](#one-file-that-is-many-files)
7. [The name the player typed](#the-name-the-player-typed)
8. [Mods: a format is data the game interprets](#mods-a-format-is-data-the-game-interprets)
9. [Where the save system starts](#where-the-save-system-starts)
10. [Tips and common mistakes](#tips-and-common-mistakes)

## The two places

Godot has exactly two places a path can name, and telling them apart is the single commonest way a
project that runs perfectly in the editor fails on the first machine it is sent to.

| The place | What it is | What you may do |
|---|---|---|
| `res://` | The game's OWN files, packed into the build | Read. In an exported game it is inside the pack, and every write to it fails |
| `user://` | The PLAYER'S folder, one per player, kept across updates | Read and write. Saves, settings, logs and screenshots all live here |

**The export trap is quiet, which is why it survives testing.** In the editor `res://` is an ordinary
folder on your disk, so a save written to `res://save.dat` works right up until you export. After
that the pack is an archive rather than a folder, the write fails, and because every write row guards
its file handle rather than crashing, it fails without a word.

The rule in one line: **read from `res://`, write to `user://`.** Ship your tables, levels and
defaults under `res://`; put everything the game itself produces under `user://`.

**Where `user://` really is** depends on the machine, which is the point of it. On Windows it is
under the user's `AppData\Roaming` folder, on macOS under `Library/Application Support`, on Linux
under `.local/share`, and on mobile and web it is the sandboxed store the platform gives the app.
You never have to know which: the engine resolves `user://` on that machine, and
**Open The Player's Data Folder** opens the resolved folder in their own file browser when you want
to show them where something went.

### The place is written under the field

Every path field in the file vocabulary says which place its path is in, in a muted line under the
box, and it updates as you type. A path the field cannot read a place off - a variable, an
expression, something built with `%` - says so rather than guessing.

![The parameters dialog for Write Text File, the Path field holding "user://save.dat" with a muted lead under it reading user:// - the player's folder: writable, one per player, kept across updates](images/file-place-field.png)

### And the Doctor says it about the whole project

**Tools > Project Doctor** carries a **Files** section with four checks, run over your project's own
scripts as well as its sheets:

- **A write aimed at `res://`** - the export trap, reported as an error with a one-click fix that
  rewrites the path under `user://`. A *read* of `res://` is never reported: reading the game's own
  files is what `res://` is for.
- **An absolute path in a file call** - a path naming a folder that exists on exactly one computer.
- **A `user://` read with nothing said about a missing file** - a note rather than a warning, with a
  door that respells the row as the guarded read below.
- **An outside path handed to `load()`** - the trust boundary, which has a chapter of its own further
  down.

Each fix shows what it would change before it changes it, as before-and-after pairs of the row's own
value, and lands as one undo.

## The guard you can see

Reads are forgiving and writes are not, and both of those facts are things you can *see* in the
emitted line rather than behaviour you have to remember.

**Read Text File** on a missing path answers with `""`, because `FileAccess.get_file_as_string` does.
When empty text is not the answer you wanted, **Read Text File (or a fallback)** takes what to use
instead in its second slot - the familiar default argument, not a new kind of sentence - and writes
the guard into the line:

```gdscript
extends Node


func _ready() -> void:
	var settings: String = FileAccess.get_file_as_string("user://settings.json") if FileAccess.file_exists("user://settings.json") else "{}"
	print(settings)
```

Leave that second slot blank and the plain read is emitted, unchanged. Nothing happens that the line
does not say.

The write half has the same shape. Godot will not create a folder on the way to opening a file, so a
write to `user://runs/latest.txt` does nothing at all until something makes `user://runs`.
**Write Text File (in a folder)** offers the choice on the row itself, and when you take it the
folder line is emitted **above the write, where you can read it**:

```gdscript
extends Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://runs/latest.txt".get_base_dir())
	var file = FileAccess.open("user://runs/latest.txt", FileAccess.WRITE)
	if file:
		file.store_string("run finished")
		file.close()
```

![A parameters dialog for Read Text File (or a fallback): the Path field, the If missing field holding "{}", and the ships-as line showing the whole conditional expression the row compiles to](images/file-guarded-read.png)

That is the rule the whole file vocabulary is written to: **an emitted guard is shown, never
performed behind your back.** A prelude that makes a folder, a check that a file is there, the
comparison an unpack makes before it writes - all of them are lines in your script.

## A spreadsheet, read as rows

A `.csv` is the format every spreadsheet exports and every designer already has, and there are two
rows for reading one because there are honestly two answers.

- **Table From File** parses the file itself, in a single expression, under a quoting policy written
  down in the vocabulary. It is a fold, so it fits anywhere an expression fits.
- **Table Of File** hands the job to `FileAccess.get_csv_line` - **the engine's own reader** - so its
  quoting is whatever Godot does with a quote and this plugin has no opinion about it. It needs a
  loop, so it is emitted as a lambda called on the spot and belongs in a Set action rather than in a
  condition.

**Table Of File** also asks the question a fold cannot: whether the first line names the columns at
all. Say *the first line names the columns* and every row arrives as a record you read fields off;
say *every line is a row* and a headerless file keeps its first line instead of losing it.

**Write Table To File** is its inverse through `store_csv_line`, which is what makes a file written
by one read back unchanged by the other.

```gdscript
extends Node


func _ready() -> void:
	var items: Array = (func(__path: String) -> Array:
		var __file: FileAccess = FileAccess.open(__path, FileAccess.READ)
		if __file == null:
			return []
		var __rows: Array = []
		var __columns: PackedStringArray = __file.get_csv_line(",")
		while not __file.eof_reached():
			var __cells: PackedStringArray = __file.get_csv_line(",")
			if __cells.size() == 1 and __cells[0].is_empty():
				continue
			var __record: Dictionary = {}
			for __column: int in mini(__columns.size(), __cells.size()):
				__record[__columns[__column]] = __cells[__column]
			__rows.append(__record)
		return __rows).call("res://data/items.csv")
	print(items.size())
```

![An event sheet row reading Set items to table of res://data/items.csv - the first line names the columns, with the engine's own reader echoed beside it](images/engine-table-read.png)

For a plain text file there is **For Each Line In File**, a looping condition: the file is read once,
blank lines are skipped, Windows and old-Mac line endings are handled, and the event's actions run
once per line with the current one readable as `line`.

### The band at the top says what this sheet touches

A sheet that reads or writes files grows a **files** band in its head, one entry per path, saying
what happens to it: `user://save.json - read and written`. A row that starts a watch reads
`watching user://mods every 2.0 s`, because a folder read once and a folder read every two seconds
for the rest of the session are not the same thing to say about a sheet.

![A sheet head with a files band listing user://pack.zip - read and written and user://mods - read and written, each with the engine call echoed beside it](images/files-band.png)

## The drop and the ask

Everything above works on a path the sheet already holds. Content the **player** names comes in
through two doors, and both of them hand back a path and nothing else.

**On Files Dropped** is the window's own `files_dropped` signal as an event: the sheet connects it in
`_ready` on `get_window()`, exactly as a hand-written project already writes it, and the paths ride
into the event as a chip. It is **desktop only** - Windows, macOS and Linux raise it, a web or mobile
build never does - and the row says so, not a doc nobody opened.

```gdscript
extends Node


func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)


func _on_files_dropped(files: PackedStringArray) -> void:
	print(files[0])
```

![One event in a sheet called AvatarPicker: a green arrow trigger badge, the object Node, a files payload chip, and one action, System Set avatar to ImageTexture.create_from_image(Image.load_from_file(files' item 0))](images/user-content-drop.png)

**Ask For A File To Open** and **Ask Where To Save** open the platform's own file chooser where the
platform has one, through `DisplayServer.file_dialog_show`, and where it has none the `FileDialog`
fallback is emitted as a **visible `else`**. Both spellings are in the code a reader can see, because
a row that quietly picked one of two very different windows would be a row nobody could debug.

**The answer is an event, never a return value.** A chooser is a separate window and the player
answers it long after the row ran, so both Ask rows end in **On A File Chosen** or
**On The Ask Cancelled**, and the emitted line calls those two events' functions by name. A sheet
that asks needs both events, or the script it compiles to calls a function that is not there:

```gdscript
extends Node


func _on_file_chosen(path: String) -> void:
	print(path)


func _on_ask_cancelled() -> void:
	print("kept the old one")
```

![Three events in the same sheet: ChooseButton On Pressed with the action System Ask for a file to open (PackedStringArray(["*.png;Images"])), then System On A File Chosen with System Set avatar to ImageTexture.create_from_image(Image.load_from_file(path)), then System On The Ask Cancelled with StatusLabel Set text to "Kept the old picture."](images/user-content-ask.png)

Two expressions turn such a path into something the game can use. **Image From File** reads a picture
with `Image.load_from_file` into an `ImageTexture`; **Sound From File** names one engine reader per
format the engine decodes at runtime and picks by extension, which is exactly three: `.mp3`, `.ogg`
and `.wav`. Each takes its fallback in the second slot, the familiar default argument again - leave
it blank and the plain load is emitted.

**No import pipeline is involved and none is wanted.** A loaded image is a texture in a variable and
a loaded sound is an audio stream in one. They live as long as something holds them and no longer,
they are never `.import`ed, and they never become project resources. That is the honest shape for
content the game did not ship with.

## The watcher, and why it polls

Godot raises **no file-change notification at run time** on any platform it ships for. There is
nothing to subscribe to and nothing a plugin could subscribe to on your behalf. So the **Folder
Watcher** pack does the only honest thing available: it **looks**, on an interval you name, and
compares what it saw with what it saw last time, by file name and by modified time.

A poll calls itself a poll here. The row reads `Watch folder "user://mods" every 2.0 s` and so does
the band, because "watching" that quietly costs a directory read every frame is the kind of thing a
project finds out about on somebody else's slow disk.

- **Watch Folder** starts it. The first look is the **baseline** and raises nothing: a folder that
  already holds two hundred files is not two hundred things that just happened.
- **Stop Watching** parks the per-frame tick with `set_process(false)`, so a stopped watcher is a
  node the engine no longer visits at all.
- **Look Now** takes one look immediately, which is what you want straight after your own game wrote
  into the folder.
- **On A File Appeared / Changed / Removed** are what a difference between two looks means, each
  handing back the whole path.

One look costs one `DirAccess.get_files_at` plus one modified-time question per file that passes the
name filter, and between looks it costs nothing. The walk is sorted, so two machines watching the
same folder raise the same events in the same order.

![Two events in a sheet called ModFolder, under a head whose files band reads watching user://mods every 2.0 s with watch_folder("user://mods", 2.0) echoed beside it: On Created with FolderWatcher Watch folder "user://mods" 2, and a second On Created with FolderWatcher Stop watching](images/folder-watcher.png)

The pack's own page - [Folder Watcher](Addons/Folder-Watcher.md) - has the sixteen worked cases, the
Inspector properties and the mistakes that bite.

## One file that is many files

A mods folder, a screenshot batch, a level pack somebody sent: all of them are one `.zip` somewhere.
**Pack Folder Into Zip** and **Unpack Zip Into Folder** sit beside the twelve original file verbs,
over the engine's own `ZIPPacker` and `ZIPReader`, and both loops are emitted into your script where
they can be read. The pack walks the files directly in one folder, not its subfolders, and the row
says so rather than surprising the first person whose folder had a `.import` directory in it.

**The unpack guard is the feature, and it is visible in the emitted code.** An archive entry names
its own path, and one spelled `../../autoexec.cfg` resolves outside the folder the player pointed at,
which is how an unpack becomes a write anywhere on their disk. So every entry's resolved path is
compared against the target folder before a single byte is written - both sides globalized and
simplified, the folder keeping its trailing slash so `user://mods` cannot accept
`user://mods_of_mine` - and an entry that climbs out closes the archive, stops the whole unpack and
raises **On Unpack Refused** with the entry and the reason on it.

A huge archive meets a progress bar rather than a frozen game: **On Unpack Progress** reports the
entries and bytes that have landed, once per entry, and **On Unpack Finished** ends a run that
reached the last entry. Like the Ask rows, the emitted loop calls all three answers **by name**, so
a sheet that unpacks needs an event for each:

```gdscript
extends Node


func _on_unpack_progress(entries: int, bytes: int) -> void:
	print(entries)


func _on_unpack_refused(entry: String, reason: String) -> void:
	print(reason)


func _on_unpack_finished(entries: int, bytes: int) -> void:
	print(bytes)
```

![Four events in a sheet called ModInstaller, under a head whose files bands read user://pack.zip - read and written and user://mods - read and written with the ZIPReader line echoed beside each: On Created with System Unpack "user://pack.zip" into folder "user://mods", then On Unpack Progress setting Bar value to entries, On Unpack Refused setting Label text to "Refused: " and reason, and On Unpack Finished setting Label text to "Installed " and entries](images/archive-unpack.png)

## The name the player typed

A player names a screenshot, a save slot, a level. What they type is not a file name yet.

**Safe File Name** answers with one a file system will actually take, over the engine's own
`String.validate_filename`: the characters it refuses become underscores and the ends are trimmed.
It is an **expression**, so it goes in the path slot of the write that was already there rather than
becoming a second way to save a file. Its second slot is the familiar default argument: a name that
comes out empty answers with it, so a player who typed nothing gets a file instead of an error.

**Free File Path** answers with the nearest path nothing is sitting at yet, so a second screenshot
does not erase the first. The rule is the one every desktop uses and it is spelled out in the emitted
line: `shot.png`, then `shot_1.png`, then `shot_2.png`, up to the number in the slot. The path is
read once, the numbers are only tried when the path you wanted is taken, and a run that fills every
number answers the path you asked for - which the row's own help says out loud, because that next
write overwrites.

```gdscript
extends Node


func _ready() -> void:
	var typed: String = "save 3/8?"
	var file = FileAccess.open("user://saves/" + (typed.validate_filename() if not typed.validate_filename().is_empty() else "untitled") + ".json", FileAccess.WRITE)
	if file:
		file.store_string("{}")
		file.close()
```

The brackets are not decoration: a bare `a if b else c` spliced between two `+` signs binds the whole
join into the branches, which is a wrong path rather than a parse error, so the guarded form wears
its own.

**Show In The File Manager** opens the player's own file browser with the file selected, over
`OS.shell_show_in_file_manager`. It is **desktop only**, said on the row: a web or mobile build does
nothing at all, so say on screen where the file went as well.

## Mods: a format is data the game interprets

Letting players add content is a good idea, and it has exactly one shape that stays safe as the game
grows: **a mod format is data your game interprets.** The mod file lists what it wants; your sheet
decides what each entry means. Nothing the player supplies is ever executed.

The worked example is a **kinds table**. A mod file is a list of entries, each with a `kind` your
game knows and values your game reads:

```json
[
	{"kind": "enemy", "name": "Slime", "hp": 30, "speed": 40},
	{"kind": "item", "name": "Blue Potion", "heals": 25},
	{"kind": "line", "who": "guard", "says": "You again."}
]
```

Your sheet reads the file, walks the entries and answers each `kind` with rows you wrote. An entry
whose kind is not in the table is ignored and reported, which is also what makes a mod written for
last year's version fail politely instead of half-loading:

```gdscript
extends Node


func _ready() -> void:
	var mod: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://mods/pack.json"))
	for entry: Dictionary in mod:
		match entry.get("kind", ""):
			"enemy":
				print(entry.get("name", ""))
			"item":
				print(entry.get("heals", 0))
			_:
				push_warning("unknown kind")
```

Every door in this guide is data-shaped for the same reason. **Image From File** gives you a texture,
**Read Text File (or a fallback)** gives you text, **Table Of File** gives you rows and columns.
A file that arrives through one of those cannot bring behaviour with it.

**What `load()` does instead is the thing worth knowing.** `load()` and `ResourceLoader.load()` work
on an outside path - that is exactly why nothing else in the engine warns about it - and a `.tscn` or
a `.tres` can name a **script**. Loading one runs its author's code with everything your game can
reach: the player's files, their network, their machine. So the Doctor's Files section reports a path
that came in through one of the game's own doors - dropped on the window, chosen by the player, found
in a watched folder, written out of an unpacked archive - being handed to `load()`, and offers the
three data-shaped doors instead.

It is a **warning and not an error**. A game whose mods *are* code is a real decision that some
projects make deliberately; what is not a decision is making it without knowing. The check reads
names inside one file - a door's own handler parameter, anything assigned from one, anything a `for`
walks out of one, any path written under a folder that file watches or unpacks into - and it does not
follow a path across files or through a call into another body, so a quiet file is not a proof and
the finding says so.

## Where the save system starts

**None of this is the save system.** The game's own state - the slot, the run, the settings the
player edits through your options screen - belongs to the Save System pack, whose verbs write under
`user://` with no chooser in sight and carry slots, formats, migration and a backup ring with them.
See [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md) for those.

The line between the two is worth saying once and keeping: **the save system is for state your game
produced; these rows are for content that arrives from outside it.** A portrait the player dropped
on the window, a track they picked out of their own folder, a level pack somebody sent them, a
spreadsheet a designer maintains. When the two meet - a save file the player wants to keep a copy of,
say - the save pack writes it and **Show In The File Manager** or **Ask Where To Save** is how the
player gets at it.

## Tips and common mistakes

- **Write to `user://`, read from `res://`.** A `res://` write works in the editor and fails silently
  in every exported build. The Doctor's Files section finds it before your players do.
- **Godot does not make a folder on the way to a file.** A write into a folder that is not there does
  nothing at all. Use **Write Text File (in a folder)**, or a **Make Directory** row above the write.
- **A missing file reads as empty, not as an error.** That is a fine answer when you meant it. When
  you did not, say what you meant with **Read Text File (or a fallback)**.
- **Append needs the file to exist.** **Append To File** opens for read-write and does nothing when
  there is no file, so write it once before you append to it.
- **A path field is an expression field.** `"user://slot_" + str(slot) + ".json"` is a perfectly
  ordinary path. The place lead simply says *unknown* when it cannot read a literal, which is the
  honest answer rather than a guess.
- **An ask needs both its answers.** A sheet with an Ask row and no **On A File Chosen** event
  compiles to a call to a function that is not there.
- **A drop is desktop only.** Keep a button beside it that opens the ask, or mobile players have no
  way in at all.
- **A watcher under `res://` will never see anything change.** It is packed and read-only in an
  exported game. Watch `user://`.
- **An unpack writes files; it does not install them.** The guard keeps entries inside the folder you
  named. What the files then *mean* is your sheet's decision, which is the whole point of the kinds
  table above.
- **User content is data, never code.** Read a picture as a picture, text as text and a table as a
  table. Reach for `load()` on a player's file only if you have decided, on purpose, that your mods
  are programs.
