# EventForge module - File management (read / write / JSON, plus directory + file operations).
#
# Everyday on-disk work - save & load text, serialise to JSON, copy / move / delete files, and manage
# directories - so save systems, config files and level data never force a drop to GDScript. Each
# compiles to the exact native FileAccess / DirAccess call. Reads use the static, null-safe accessors
# (FileAccess.get_file_as_string / DirAccess.get_files_at - they return "" / [] on error rather than
# crashing); writes guard the FileAccess handle so a bad path can't null-deref. Grouped under
# Files / Files: Directories / Files: Archives.
#
# EVERY PATH FIELD SAYS ITS PLACE. The path parameters carry the `file_path` hint, which takes any
# GDScript expression exactly as an ordinary expression field does and is spelled apart from it only
# so a muted lead can sit under the box naming the place the path is in - user:// (the player's
# folder: writable, per-player, survives updates) or res:// (the game's own files: READ-ONLY once
# exported). The reading of those places, and where user:// really is on each desktop platform, live
# once in EventForgeFilePlaces, which the lead, the help strip and the Doctor all ask.
#
# AND A SLOT A METHOD IS ASKED OF WEARS BRACKETS. A parameter holds an EXPRESSION, so a template
# writing `{path}.get_base_dir()` asks that method of the LAST OPERAND of whatever was typed:
# `"user://runs/" + slot + ".txt"` makes the folder of `".txt"`, which is `""`. It parses, it runs,
# and it is quietly the wrong answer, which is the only kind of bug nothing ever reports. Every new
# template here spells it `({path}).get_base_dir()` instead. The rule is only about a method asked of
# a slot: a slot handed to a call as an ARGUMENT is already one whole expression, and `{uid}` is a
# baked identifier rather than an expression at all.
@tool
class_name EventForgeFileACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one reading of the trust line a scene file draws. Loaded by path rather than by class name so
## the vocabulary stays usable before the editor's class cache has seen the script - the same rule
## the compiler follows for the tables it shares.
const SceneTrust := preload("res://addons/eventforge/scene_trust.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Files - read / write / JSON / copy / move / delete (act on a path string or expression) ──
	descriptors.append(F.cond("FileExists", "File Exists", "FileAccess.file_exists({path})", "Files", "file {path} exists", "True when a file exists at that path, so you can check before reading or writing it.").param("path", "\"user://save.dat\"", "Path", "File path to test. Prefer user:// (res:// is read-only when exported).", "file_path"))
	descriptors.append(F.expr("ReadTextFile", "Read Text File", "FileAccess.get_file_as_string({path})", "Files", "text of file {path}", "Returns the whole file's contents as text (empty if it's missing or unreadable).").param("path", "\"user://save.dat\"", "Path", "File to read in full as a String (\"\" if it is missing or unreadable).", "file_path"))
	descriptors.append(F.expr("GetFileSize", "File Size (bytes)", "FileAccess.get_file_as_bytes({path}).size()", "Files", "size of file {path}", "Returns a file's size in bytes, or zero if the file doesn't exist.").param("path", "\"user://save.dat\"", "Path", "File to measure (0 bytes if missing).", "file_path"))
	descriptors.append(F.act("WriteTextFile", "Write Text File", "var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "Files", "write {text} to file {path}", "Saves text to a file, overwriting anything already there (great for save data).").param("path", "\"user://save.dat\"", "Path", "File to write. OVERWRITES any existing file. Use user:// (res:// is read-only when exported).", "file_path").param("text", "\"\"", "Text", "Text content to store.", "expression"))
	descriptors.append(F.act("AppendTextFile", "Append To File", "var __file_{uid} = FileAccess.open({path}, FileAccess.READ_WRITE)\nif __file_{uid}:\n\t__file_{uid}.seek_end()\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "Files", "append {text} to file {path}", "Adds text to the end of an existing file without erasing it (handy for logs).").param("path", "\"user://log.txt\"", "Path", "Existing file to append to (no-op if it does not exist - Write it first).", "file_path").param("text", "\"\"", "Text", "Text to append at the end of the file.", "expression"))
	descriptors.append(F.act("DeleteFile", "Delete File", "DirAccess.remove_absolute({path})", "Files", "delete file {path}", "Permanently deletes a file (or an empty folder) from disk.").param("path", "\"user://save.dat\"", "Path", "File (or empty directory) to delete.", "file_path"))
	descriptors.append(F.act("CopyFile", "Copy File", "DirAccess.copy_absolute({from}, {to})", "Files", "copy {from} to {to}", "Copies a file from one path to another, leaving the original in place.").param("from", "\"user://save.dat\"", "From", "Source file path.", "file_path").param("to", "\"user://backup.dat\"", "To", "Destination file path.", "file_path"))
	descriptors.append(F.act("MoveFile", "Move / Rename File", "DirAccess.rename_absolute({from}, {to})", "Files", "move {from} to {to}", "Moves or renames a file (or folder) to a new path.").param("from", "\"user://old.dat\"", "From", "Current file (or directory) path.", "file_path").param("to", "\"user://new.dat\"", "To", "New path / name.", "file_path"))

	# ── Files: Directories - make / remove / test / list directories ──
	descriptors.append(F.cond("DirExists", "Directory Exists", "DirAccess.dir_exists_absolute({path})", "Files: Directories", "directory {path} exists", "True when a folder exists at that path, useful before creating or listing it.").param("path", "\"user://data\"", "Path", "Directory path to test.", "file_path"))
	descriptors.append(F.act("MakeDir", "Make Directory", "DirAccess.make_dir_recursive_absolute({path})", "Files: Directories", "make directory {path}", "Creates a folder, building any missing parent folders along the way.").param("path", "\"user://data\"", "Path", "Directory to create (any missing parent directories are created too).", "file_path"))
	descriptors.append(F.act("RemoveDir", "Remove Directory", "DirAccess.remove_absolute({path})", "Files: Directories", "remove directory {path}", "Deletes an empty folder (clear out its files first).").param("path", "\"user://data\"", "Path", "EMPTY directory to remove (delete its files first).", "file_path"))
	descriptors.append(F.expr("ListFiles", "List Files", "DirAccess.get_files_at({path})", "Files: Directories", "files in {path}", "Returns the list of file names inside a folder (empty if the folder is missing).").param("path", "\"user://\"", "Path", "Directory whose file names to list (PackedStringArray; [] if missing).", "file_path"))
	descriptors.append(F.expr("ListDirs", "List Subdirectories", "DirAccess.get_directories_at({path})", "Files: Directories", "subdirectories in {path}", "Returns the list of subfolder names inside a folder.").param("path", "\"user://\"", "Path", "Directory whose subdirectory names to list.", "file_path"))

	# ── The three that say the place out loud ─────────────────────────────────────────────────
	#
	# Beside the twelve above rather than inside them: their ace_ids and templates are a
	# compatibility promise, so a sentence that needs a different LINE needs a different word.
	#
	#   the guarded read      a read that says what to use when the file is not there. The second
	#                         parameter IS the fallback - the familiar default argument - and leaving
	#                         it blank emits the plain read, unchanged.
	#   the write that makes  Godot will not create a folder on the way to opening a file, so a path
	#   its folder            with folders in it fails until somebody makes them. The choice is
	#                         stated on the row and the prelude is in the echo.
	#   the folder door       where user:// really is, opened on the player's own machine.
	descriptors.append(F.expr("ReadTextFileOr", "Read Text File (or a fallback)", "{?fallback}({/fallback}FileAccess.get_file_as_string({path}){?fallback} if FileAccess.file_exists({path}) else {fallback}){/fallback}", "Files", "text of file {path}, or {fallback}", "Reads a whole file as text, using the fallback you name when the file is not there. The guard is written into the line and shown on the row, so nothing happens that the code does not say.").param("path", "\"user://save.dat\"", "Path", "File to read in full as a String. Prefer user:// - res:// is read-only once the game is exported.", "file_path").param("fallback", "\"\"", "If missing", "What the expression reads as when there is no file at that path. Leave it blank to read the file plainly, exactly as Read Text File does.", "expression"))
	descriptors.append(F.act("WriteTextFileInFolder", "Write Text File (in a folder)", "{?folder=make its folder first}DirAccess.make_dir_recursive_absolute(({path}).get_base_dir())\n{/folder}var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "Files", "write {text} to file {path} - {folder}", "Saves text to a file inside a folder, optionally creating the folders on the way. The folder line is emitted above the write and shown in the row, never behind your back.").param("path", "\"user://runs/latest.txt\"", "Path", "File to write, inside one or more folders. OVERWRITES any existing file. Prefer user:// - res:// is read-only once the game is exported.", "file_path").param("text", "\"\"", "Text", "Text content to store.", "expression").param_choice("folder", "make its folder first", "Folder", "Whether to create the folders in that path before writing. Godot does not make them on the way to opening a file, so a write into a folder that is not there fails.", [{"key": "make its folder first", "label": "Make the folder first"}, {"key": "its folder is already there", "label": "The folder is already there"}]))
	descriptors.append(F.act("OpenUserDataFolder", "Open The Player's Data Folder", "OS.shell_open(ProjectSettings.globalize_path({path}))", "Files", "open the player's data folder {path}", "Opens the player's own data folder in their desktop file browser - the real folder user:// stands for on that machine.").param("path", "\"user://\"", "Path", "Folder to open, inside user://. The path is turned into a real one on the player's machine before it is handed to the desktop.", "file_path"))

	descriptors.append_array(_content_from_outside())
	descriptors.append_array(_archives())
	descriptors.append_array(_names_and_doors())
	descriptors.append_array(_scene_files())
	return descriptors


## ────────────────────────────────────────────────────────────────────────────────────────────────
## THE NAME THE PLAYER TYPED, THE PATH THAT IS STILL FREE, AND THE FOLDER SHOWN BACK TO THEM.
##
## Three small rows about the moment a game writes a file the player named. Two are EXPRESSIONS,
## because each one ANSWERS a question inside a path slot rather than doing anything; the third is an
## ACTION, because it does a deed on the desktop.
##
##   the safe name   the engine's own `String.validate_filename`, with the familiar default argument
##                   in the second slot. A player types "save 3/8?" and the file system refuses it;
##                   this answers "save 3_8_". A name that validates to nothing - blank, or spaces -
##                   answers the fallback instead, which is why the fallback is there.
##   the free path   the nearest path that is not taken yet, so a second screenshot does not erase
##                   the first. The rule is the one every desktop uses and it is spelled out in the
##                   line: `shot.png`, then `shot_1.png`, `shot_2.png`, up to the number in the slot.
##   the door back   `OS.shell_show_in_file_manager`, which opens the player's file browser with the
##                   file already selected. DESKTOP ONLY, said on the row.
##
## NEITHER EXPRESSION WRITES ANYTHING. Both answer with a String and nothing else: the write is the
## next row, spelled with the verb it was always spelled with. That is what keeps this a parameter and
## not a second way to save a file.
static func _names_and_doors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.expr("SafeFileName", "Safe File Name", _safe_name_template(), "Files", "safe file name of {name}, or {fallback}", "Answers with a file name that a file system will actually accept, using the engine's own validate_filename: the characters it refuses become underscores. A name that comes out empty answers with the fallback you name, so a player who typed nothing still gets a file rather than an error.").param("name", "\"\"", "Name", "The name to make safe - usually one the player typed. Every character a file system will not take is replaced with an underscore, and the ends are trimmed. Prefer a variable here: the line reads this twice.", "expression").param("fallback", "\"untitled\"", "If it is empty", "What to answer with when the name is nothing once it has been made safe - a blank box, or spaces. Leave it blank to answer with the empty name itself, exactly as the engine's own check does.", "expression").featured())
	descriptors.append(F.expr("FreeFilePath", "Free File Path", _free_path_template(), "Files", "free path near {path}, up to {at_most}", "Answers with the nearest path that has no file at it yet. A path that is free is answered back unchanged; one that is taken gets a number before its extension - shot.png, then shot_1.png, then shot_2.png - and the first free one is the answer. This asks about FILES: a folder sitting at that path is not seen.").param("path", "\"user://shot.png\"", "Path", "The path you would like. It is answered back unchanged when no file is there yet.", "file_path").param_typed("int", "at_most", "99", "At most", "How many numbers to try before giving up. The questions are only asked when the path you wanted is already taken - and then ALL of them are asked, not just up to the first free one: the line builds every candidate and keeps the free ones, so a taken path costs this many file_exists questions whatever the answer turns out to be. When all of them are taken the answer is the path you asked for, so the row after this one overwrites - name a number you are comfortable with.", "expression").featured())
	descriptors.append(F.act("ShowInFileManager", "Show In The File Manager", "OS.shell_show_in_file_manager(ProjectSettings.globalize_path({path}))", "Files", "show {path} in the file manager", "Opens the player's own file browser with that file selected, so they can see what the game just wrote. DESKTOP ONLY: Windows, macOS and Linux open a window, and a web or mobile build does nothing at all - so say on screen where the file went as well.").param("path", "\"user://save.dat\"", "Path", "The file or folder to show. A user:// or res:// path is turned into a real one on the player's machine first, and a path that is already real is handed over as it is.", "file_path"))
	return descriptors


## The safe name's line. The fallback is the familiar default argument: leaving the slot blank emits
## the bare `validate_filename()` call, which is the engine's own answer with nothing added to it.
##
## THE GUARDED FORM WEARS ITS OWN BRACKETS, exactly as the sound loader's does. A safe name is written
## to be joined onto a folder and an extension, and a bare `a if b else c` spliced between two `+`
## signs binds the whole concatenation into the branches - which is a wrong path, not a parse error,
## so nothing would ever have said so.
##
## AND SO DOES THE SLOT, for the same reason read the other way round. A parameter slot holds an
## EXPRESSION, and `.validate_filename()` binds to the last operand of whatever is spliced in: a name
## written `typed + ".json"` validated the `".json"` and handed `..` through untouched, which is the
## one thing this row exists to stop. The slot is bracketed so the method is asked of the whole
## answer, whatever the answer was written as.
##
## AND THE LEADING DOTS COME OFF, because `..` is the one thing a player can type that a file system
## accepts and that is not a NAME at all: `validate_filename` leaves it exactly as it is, and
## `"user://saves".path_join("..")` is `user://`, which is the folder above the one the row meant.
## Stripping the dots off the front turns it into nothing, and nothing is what the fallback is for.
## A name that only BEGINS with a dot loses the dot and keeps the rest, which is the same answer.
static func _safe_name_template() -> String:
	return "{?fallback}({/fallback}({name}).validate_filename().lstrip(\".\")" \
		+ "{?fallback} if not ({name}).validate_filename().lstrip(\".\").is_empty()" \
		+ " else {fallback}){/fallback}"


## The free path's line.
##
## THE PATH IS READ ONCE. It arrives as whatever expression the slot holds - a variable, a join, a
## Safe File Name of something the player typed - and every one of those may cost something to work
## out, so the line binds it to a name first and asks all its questions of that name.
##
## THE NUMBERED SUFFIX IS SPELLED OUT, and it is spelled by JOINING rather than by formatting.
## `get_basename()` is the path without its extension and `trim_prefix(get_basename())` is exactly
## what that removed - ".png", or nothing at all for a path that had no extension - so the number
## lands between them and a path with no extension gets no stray dot. Written as a join, the rule can
## be read straight off the row; written as a format string it is three specifiers and a list, which
## is the same answer nobody can check at a glance.
##
## THE LAST RESORT IS THE PATH ITSELF, appended after the free candidates so the answer is never
## nothing. A caller who has genuinely filled every number is overwriting, and the row's own help says
## so rather than the line failing somewhere else later.
##
## AND EVERY CANDIDATE IS ASKED ABOUT, not just up to the first free one. `map` then `filter` builds
## the whole list and keeps the free ones, so `at_most` questions are asked whenever the wanted path
## is taken, however early the free one turns up. Stopping at the first would want a loop, and a loop
## is not an expression - this row answers inside a path slot, which is what makes it a parameter
## rather than a second way to write a file. So the cost is stated on the slot instead of hidden.
static func _free_path_template() -> String:
	return "(func(__wanted: String) -> String: return __wanted if not FileAccess.file_exists(__wanted)" \
		+ " else (range(1, ({at_most}) + 1).map(func(__number: int) -> String:" \
		+ " return __wanted.get_basename() + \"_\" + str(__number)" \
		+ " + __wanted.trim_prefix(__wanted.get_basename())).filter(" \
		+ "func(__candidate: String) -> bool: return not FileAccess.file_exists(__candidate))" \
		+ " + [__wanted]).front()).call({path})"


## ────────────────────────────────────────────────────────────────────────────────────────────────
## ONE FILE THAT IS MANY FILES - the two archive verbs, and the three events an unpack raises.
##
## A mod folder, a screenshot batch, a level pack somebody sent: all of them are one .zip somewhere,
## and a project without these two rows drops to GDScript to open one. Both compile to the engine's
## own ZIPPacker / ZIPReader loop, written out where it can be read, and nothing else is involved -
## no import step, no virtual filesystem, no archive object living on between rows.
##
##   pack     the files in ONE folder, written into an archive. Not its subfolders - a recursive
##            walk is a different loop with a different failure, and a row that quietly did one
##            would surprise the first person whose folder had a `.import` directory in it.
##   unpack   every entry of the archive, written into a folder, WITH THE GUARD BELOW.
##
## THE GUARD IS THE POINT, AND IT IS IN THE CODE. A zip is user content, and an archive entry is a
## PATH the archive itself chose. An entry spelled `../../autoexec.cfg` resolves outside the folder
## the player pointed at, which is how an unpack becomes a write anywhere on their disk. So every
## entry's resolved path is compared against the target folder before a single byte is written, and
## one that climbs out stops the whole unpack and raises On Unpack Refused with the reason in it.
## The comparison is emitted into the sheet's own file: a guard nobody can read is a guard nobody
## can trust.
##
## THE THREE EVENTS. An archive can hold ten thousand entries, so the loop reports as it goes -
## On Unpack Progress once per entry, with what has landed so far and how many entries there are in
## all. On Unpack Finished ends a run that reached the last entry; On Unpack Refused ends one the
## guard stopped. Like the Ask rows above, the emitted loop calls all three BY NAME, so a sheet that
## unpacks needs an event for each - a sheet missing one does not compile, and says which.
##
## AND THE LOOP RUNS TO THE END INSIDE THE ONE ROW. There is no `await` in it, so the reports arrive
## in a burst and the window repaints once the row returns: a bar fed by them shows how far the run
## got, not the run happening. That is said on the trigger rather than left for somebody to find out
## on a big archive, and an unpack that yields between entries would be a different row with a
## different line - a coroutine - rather than this one quietly becoming one.
##
## USER CONTENT IS DATA, NEVER CODE. An entry is read as bytes and stored as bytes. Nothing here
## loads, parses or runs what came out of the archive.
static func _archives() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("PackFolderIntoZip", "Pack Folder Into Zip", _pack_template(), "Files: Archives", "pack folder {folder} into {archive}", "Writes the files in one folder into a .zip archive, using the engine's own packer. The loop is emitted into your script, so you can see exactly which files it walks - the ones directly in that folder, not the ones inside its subfolders.").param("folder", "\"user://runs\"", "Folder", "The folder whose files go into the archive. The files directly in it, not the contents of its subfolders.", "file_path").param("archive", "\"user://runs.zip\"", "Into archive", "The .zip file to write. OVERWRITES any archive already at that path. Prefer user:// - res:// is read-only once the game is exported.", "file_path").featured())
	descriptors.append(F.act("UnpackZipIntoFolder", "Unpack Zip Into Folder", _unpack_template(), "Files: Archives", "unpack {archive} into folder {folder}", "Reads a .zip archive and writes its entries into a folder. Every entry's path is checked against that folder BEFORE anything is written, and an entry that points outside it stops the unpack and raises On Unpack Refused - a zip is content somebody else made, and its entries name their own paths. The run reports itself through On Unpack Progress, and ends at On Unpack Finished, both of which the emitted loop calls by name. An entry the reader answers with no bytes for - a truncated or corrupted archive, and an entry that really is empty, which reads exactly the same way - is SKIPPED rather than written as a 0-byte file, and so is one the machine refuses to write; On Unpack Finished counts them, so a run that reached the end without unpacking all of it says so.").param("archive", "\"user://runs.zip\"", "Archive", "The .zip file to read. Nothing is written when it cannot be opened.", "file_path").param("folder", "\"user://unpacked\"", "Into folder", "The folder every entry is written under, created first if it is not there. NO entry may land outside it - the emitted guard stops the unpack on one that tries. Prefer a variable here: the line reads this to make the folder, again to work out where it really is, and once more for every entry in the archive.", "file_path").featured())
	descriptors.append(F.trig("OnUnpackProgress", "On Unpack Progress", "", "Files: Archives", "On unpack progress {entries} {bytes} {total}", "Runs once per entry an unpack writes, with what has landed so far and how many entries the archive holds - the two numbers a progress bar is made of. THE WHOLE UNPACK HAPPENS INSIDE THE ONE ROW: there is no waiting in the loop, so these arrive in a burst and the window repaints once the row is done. What a bar reads off them is how far the run got, not the run happening.").param_typed("int", "entries", "", "Entries", "How many entries have been written so far, counting the one that just landed.").param_typed("int", "bytes", "", "Bytes", "How many bytes have been written so far.").param_typed("int", "total", "", "Of", "How many entries the archive holds in all - the number to divide by. It counts the entries the loop will try, so the folder entries it steps over are not among them. An entry that is skipped never reports, so the last count can stop short of this."))
	descriptors.append(F.trig("OnUnpackRefused", "On Unpack Refused", "", "Files: Archives", "On unpack refused {entry} {reason}", "Runs when the guard stopped an unpack: an entry resolved to a path outside the folder it was being written into. Nothing more is written after this. Say so on screen - a refused archive is a broken or a hostile one, and the player is the only one who can decide which.").param("entry", "", "Entry", "The entry the guard stopped on, spelled exactly as the archive spells it.").param("reason", "", "Reason", "Why it was refused, in words worth showing the player."))
	descriptors.append(F.trig("OnUnpackFinished", "On Unpack Finished", "", "Files: Archives", "On unpack finished {entries} {bytes} {skipped}", "Runs when an unpack reached the last entry with nothing refused. The files are on disk by now, so this is where whatever was waiting for them starts - and the third number says whether they are all there.").param_typed("int", "entries", "", "Entries", "How many entries were written in total.").param_typed("int", "bytes", "", "Bytes", "How many bytes were written in total.").param_typed("int", "skipped", "", "Skipped", "How many entries did not land: one the reader answered with no bytes for - a truncated or corrupted archive, or an entry that really is empty, which reads exactly the same way - and one the machine refused to write, such as a name the file system will not take or a full disk. Nothing of theirs is on disk. A finish with a number here reached the end of the archive but did not unpack all of it, which is worth saying on screen rather than treating as a clean install."))
	return descriptors


## The pack loop: the engine's own packer, one file at a time, with the handle guarded exactly as
## every other write in this module guards it.
static func _pack_template() -> String:
	return "var __packer_{uid} := ZIPPacker.new()\n" \
		+ "if __packer_{uid}.open({archive}) == OK:\n" \
		+ "\tfor __entry_{uid}: String in DirAccess.get_files_at({folder}):\n" \
		+ "\t\t__packer_{uid}.start_file(__entry_{uid})\n" \
		+ "\t\t__packer_{uid}.write_file(FileAccess.get_file_as_bytes(({folder}).path_join(__entry_{uid})))\n" \
		+ "\t\t__packer_{uid}.close_file()\n" \
		+ "\t__packer_{uid}.close()"


## The unpack loop, guard and all.
##
## THE COMPARISON IS MADE ON REAL PATHS. `res://` and `user://` are Godot's own places and a `..`
## inside one of them means nothing until it is a real path, so both sides are globalized and
## simplified before they are compared - that is what turns `mods/../../autoexec.cfg` into the path
## it would really have written to. The folder keeps a trailing slash so a target of `user://mods`
## does not accept an entry landing in `user://mods_of_mine`.
##
## AN ENTRY THAT IS A FOLDER carries no bytes and is skipped: the folders that matter are the ones
## the files need, and those are made on the way in by the line above each write.
##
## THE COUNTS ARE WHAT LANDED. Both increments and the progress call sit INSIDE the `if __file:`
## guard, so an entry the machine refused to write - a name the file system will not take, a folder
## that could not be made, a full disk, a read-only path - moves neither the progress bar nor the
## totals On Unpack Finished is handed. A count of entries that were attempted is a count of nothing
## anybody can act on.
##
## AND WHAT DID NOT LAND IS COUNTED TOO, which is the other half of the same idea. An entry that
## moved nothing used to leave no trace at all: the finish said "9 entries" of a ten-entry archive
## and nothing anywhere said which one was missing or why. So the entries the loop could not write
## are counted into a third number and handed to On Unpack Finished beside the two.
##
## THE READER'S EMPTY ANSWER IS NOT A FILE. `ZIPReader.read_file` answers with an EMPTY byte array
## for an entry it could not decode - a truncated archive, a header that lies about its length, a CRC
## that does not match - and prints an engine message while doing it. There is no size to compare it
## against: the reader offers none. Writing that answer out lands a 0-byte file the game then reads
## as content, which is the one failure worse than no file at all. So an empty read is SKIPPED rather
## than written, and counted. An entry that really is empty reads exactly the same way and is skipped
## with it - the row says so, because a rule that cannot tell those two apart must say which way it
## errs.
##
## THE TOTAL IS COUNTED FIRST, and it counts the entries the loop will TRY: the folder entries are
## stepped over below, so counting them would hand a progress bar a denominator it can never reach.
## `ZIPReader` has no method that answers this, so the walk is written out where it can be read.
##
## THE REFUSAL LEAVES BY THE SAME DOOR AS THE FINISH. The guard records the entry and BREAKS rather
## than returning: a `return` inside a sheet function that answers with a value is a script that does
## not parse, and inside an ordinary handler it silently abandons every later row of the same event
## as well. So the loop ends once, the archive closes once, and the one line after it says which of
## the two events this run earned.
static func _unpack_template() -> String:
	return "var __reader_{uid} := ZIPReader.new()\n" \
		+ "if __reader_{uid}.open({archive}) == OK:\n" \
		+ "\tDirAccess.make_dir_recursive_absolute({folder})\n" \
		+ "\tvar __root_{uid} := ProjectSettings.globalize_path({folder}).simplify_path().trim_suffix(\"/\") + \"/\"\n" \
		+ "\tvar __total_{uid} := 0\n" \
		+ "\tfor __listed_{uid}: String in __reader_{uid}.get_files():\n" \
		+ "\t\tif not __listed_{uid}.ends_with(\"/\"):\n" \
		+ "\t\t\t__total_{uid} += 1\n" \
		+ "\tvar __written_{uid} := 0\n" \
		+ "\tvar __bytes_{uid} := 0\n" \
		+ "\tvar __skipped_{uid} := 0\n" \
		+ "\tvar __refused_{uid} := \"\"\n" \
		+ "\tfor __entry_{uid}: String in __reader_{uid}.get_files():\n" \
		+ "\t\tif __entry_{uid}.ends_with(\"/\"):\n" \
		+ "\t\t\tcontinue\n" \
		+ "\t\tvar __into_{uid} := ({folder}).path_join(__entry_{uid})\n" \
		+ "\t\tif not ProjectSettings.globalize_path(__into_{uid}).simplify_path().begins_with(__root_{uid}):\n" \
		+ "\t\t\t__refused_{uid} = __entry_{uid}\n" \
		+ "\t\t\tbreak\n" \
		+ "\t\tvar __data_{uid} := __reader_{uid}.read_file(__entry_{uid})\n" \
		+ "\t\tif __data_{uid}.is_empty():\n" \
		+ "\t\t\t__skipped_{uid} += 1\n" \
		+ "\t\t\tcontinue\n" \
		+ "\t\tDirAccess.make_dir_recursive_absolute(__into_{uid}.get_base_dir())\n" \
		+ "\t\tvar __file_{uid} := FileAccess.open(__into_{uid}, FileAccess.WRITE)\n" \
		+ "\t\tif __file_{uid}:\n" \
		+ "\t\t\t__file_{uid}.store_buffer(__data_{uid})\n" \
		+ "\t\t\t__file_{uid}.close()\n" \
		+ "\t\t\t__written_{uid} += 1\n" \
		+ "\t\t\t__bytes_{uid} += __data_{uid}.size()\n" \
		+ "\t\t\t_on_unpack_progress(__written_{uid}, __bytes_{uid}, __total_{uid})\n" \
		+ "\t\telse:\n" \
		+ "\t\t\t__skipped_{uid} += 1\n" \
		+ "\t__reader_{uid}.close()\n" \
		+ "\tif __refused_{uid}.is_empty():\n" \
		+ "\t\t_on_unpack_finished(__written_{uid}, __bytes_{uid}, __skipped_{uid})\n" \
		+ "\telse:\n" \
		+ "\t\t_on_unpack_refused(__refused_{uid}, \"it points outside the folder it is being unpacked into\")"


## ────────────────────────────────────────────────────────────────────────────────────────────────
## THE TWO DOORS CONTENT OUTSIDE THE PROJECT COMES IN THROUGH.
##
## Everything above works on a path the sheet already holds. These are the rows for a file the
## PLAYER names: one they drop on the window, and one they pick out of their own system's file
## chooser. Both doors hand back a path and nothing else, and the two loader expressions below turn
## such a path into a picture or a sound.
##
##   the drop door    the window's own `files_dropped` signal, connected in `_ready` exactly as
##                    every other signal trigger is. Desktop only, and the row says so.
##   the ask door     two ACTIONS that open a chooser, and two TRIGGERS that answer it. An ask has
##                    no return value on purpose: a native chooser is a separate window that answers
##                    whenever the player is ready, which is minutes after the row ran.
##   the loaders      Image.load_from_file / the three AudioStream readers, each with the FAMILIAR
##                    DEFAULT ARGUMENT as its second slot. No import pipeline is involved and none
##                    is wanted: a loaded image is a texture in a variable, and a loaded sound is an
##                    AudioStream in one. The guarded form WEARS ITS OWN BRACKETS, exactly as the safe
##                    name's does: an expression answers inside somebody else's sentence, and a bare
##                    `a if b else c` between two operators binds them into its branches.
##
## WHAT THIS IS NOT. It is not a save system - the game's own state belongs to the save_system pack's
## verbs, which write to user:// with no chooser in sight. These rows are for content the player
## brings: a portrait, a custom track, a level file somebody sent them.
##
## USER CONTENT IS DATA, NEVER CODE. Nothing here loads a script, a scene or a resource, and nothing
## here evaluates what it read. A dropped file is bytes and a path.
static func _content_from_outside() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The drop door ────────────────────────────────────────────────────────────────────────────
	#
	# Filed on `Node`, exactly as the shipped On Window Close Requested is, and for the same reason:
	# the window raises it but any node's script answers it, so every sheet may pick it and the row
	# reads with the node's own word in front rather than with System's.
	descriptors.append(F.trig("OnFilesDropped", "On Files Dropped", "files_dropped", "Files", "On files dropped {files}", "Runs when the player drags files from their desktop onto the game window and lets go. DESKTOP ONLY: Windows, macOS and Linux raise it, and a web or mobile build never does, so keep another way in beside it.", "Node").param_typed("PackedStringArray", "files", "", "Files", "Every path the player let go of, in one list - a drop can carry more than one file. They are real paths on that machine, not res:// or user:// ones.").featured())

	# ── The ask door: two actions that open a chooser, two triggers that answer it ────────────────
	#
	# THE BRANCH IS IN THE CODE, NOT BEHIND IT. Most desktops have a chooser of their own and it is
	# the one the player knows; a platform without one still has to ask somehow. Both spellings are
	# emitted, where a reader can see them, because a row that quietly picked one of two very
	# different windows would be a row nobody could debug.
	#
	# AND THE ASK'S OWN ANSWER IS READ. `DisplayServer.file_dialog_show` returns an Error, and it was
	# emitted as a bare statement - so a platform that SAYS it has a native chooser and then fails to
	# open one (a Linux build with no portal running is the everyday case) left the row with no window
	# on screen, no On A File Chosen and no On The Ask Cancelled: the player pressed the button and
	# nothing whatever happened. The question is now `no native chooser, OR asking for one did not
	# open it`, so both of those roads end at the engine's own FileDialog and the row keeps the
	# promise its help makes.
	#
	# THE ANSWER IS A TRIGGER, whichever chooser opened. The chooser is another window and the player
	# answers it long after this line has run, so the two ways it can end are the two events below,
	# and the emitted code calls them by name. The callback is built first for that reason: the
	# native call is handed it inside the very question that decides whether the native call happens.
	#
	# BOTH ARE FILED ON `Node`, exactly as On Files Dropped beside them is, because the fallback half
	# calls `add_child` and `popup_centered` on the host: a sheet whose script is not a Node cannot
	# run these rows, and a row offered where it cannot compile is a row that lies. The template is
	# untouched by the filing - the cross-node "On node" target is only added to a template whose
	# every line is a member operation, and this one leads with `var`.
	descriptors.append(F.act("AskForAFileToOpen", "Ask For A File To Open", _ask_template("Open a file", "OPEN_FILE"), "Files", "Ask for a file to open ({filters})", "Opens the player's own file chooser so they can pick a file to read. The answer arrives as On a file chosen, or as On the ask cancelled - both of which the sheet needs an event for, because the emitted line calls them by name. A platform with no chooser of its own, and one that has one but could not open it, both fall through to the engine's own window, so the row always ends at one of those two events.", "Node").param_built(_filters_param("Which files the player may pick. One entry per line of the list, spelled the way Godot spells a filter: the patterns, a semicolon, then the words the chooser shows - \"*.png,*.jpg;Images\".")).featured())
	descriptors.append(F.act("AskWhereToSave", "Ask Where To Save", _ask_template("Save a file", "SAVE_FILE"), "Files", "Ask where to save ({filters})", "Opens the player's own save chooser so they can name a file and a folder to write into. Nothing is written by this row: the path arrives as On a file chosen, and a write row does the writing. A platform with no chooser of its own, and one that has one but could not open it, both fall through to the engine's own window.", "Node").param_built(_filters_param("Which kind of file is being written. One entry per line of the list, spelled the way Godot spells a filter: the patterns, a semicolon, then the words the chooser shows - \"*.png;PNG image\".")))
	descriptors.append(F.trig("OnFileChosen", "On A File Chosen", "", "Files", "On a file chosen {path}", "Runs when the player answered an Ask row by picking a file. Both Ask rows end here, so a sheet that asks two different questions remembers which one it asked.").param("path", "", "Path", "The file the player picked, as a real path on their machine. It is a path and nothing more - reading it is a separate row.").featured())
	descriptors.append(F.trig("OnAskCancelled", "On The Ask Cancelled", "", "Files", "On the ask cancelled", "Runs when the player closed an Ask row's chooser without picking anything. Put whatever was waiting on the answer back the way it was here."))

	# ── The loaders: content from outside the project, with the fallback in the second slot ───────
	descriptors.append(F.expr("LoadImageFile", "Image From File", "{?fallback}({/fallback}ImageTexture.create_from_image(Image.load_from_file({path})){?fallback} if FileAccess.file_exists({path}) else {fallback}){/fallback}", "Files", "image of file {path}, or {fallback}", "Reads a picture from outside the project and answers with a texture, ready to hand to a Sprite or a TextureRect. No import step is involved: what you get back is a texture in a variable, and it lives only as long as something holds it.").param("path", "\"user://portrait.png\"", "Path", "The picture to read, in any format Godot decodes at runtime: .png, .jpg / .jpeg, .webp, .bmp, .tga, .svg, .ktx, .dds and .hdr.", "file_path").param("fallback", "null", "If missing", "What the expression reads as when there is no file at that path. Leave it blank to read the file plainly, with no guard around it. A file that IS there but cannot be decoded - a truncated picture, or something that is not one at all - answers with null and an engine message rather than with this, because the guard asks whether a file exists and not whether it is a picture.", "expression").featured())
	descriptors.append(F.expr("LoadSoundFile", "Sound From File", _sound_template(), "Files", "sound of file {path}, or {fallback}", "Reads a sound from outside the project and answers with an audio stream, ready to hand to a player node. The line names one reader per format the engine decodes at runtime, so a file it cannot decode reads as the fallback rather than as silence nobody explained.").param("path", "\"user://track.ogg\"", "Path", "The sound to read. EXACTLY THREE formats decode at runtime and the line checks for those three by extension: .mp3, .ogg (Ogg Vorbis) and .wav. Prefer a variable here - the path is read once per format the line checks.", "file_path").param("fallback", "null", "If missing", "What the expression reads as when there is no file at that path, or when its extension is none of the three. Leave it blank to read the file plainly, with no guard around it. A file that IS there with the right extension but cannot be decoded answers with null and an engine message rather than with this, because the guard asks whether a file exists and not whether it is a track.", "expression"))

	return descriptors


## The filters list both Ask rows carry. Same field, different words about what it is for, so each
## row's help strip describes the question that row is actually asking.
static func _filters_param(description: String) -> ACEParam:
	return F.make_param("filters", "PackedStringArray", "PackedStringArray([\"*.png,*.jpg;Images\"])", "Filters", description, "expression")


## The Ask rows' emitted lines. `mode` is the tail of the two constants that name the same choice on
## the two sides of the branch (DisplayServer.FILE_DIALOG_MODE_<mode> and FileDialog.FILE_MODE_<mode>),
## which is why one word fills both and the two halves cannot drift apart.
##
## THE NATIVE ASK'S ERROR IS PART OF THE QUESTION. `file_dialog_show` answers with an Error, and a
## platform can report the feature and still fail to open the window - so the fallback is reached by
## `not has_feature(...) or file_dialog_show(...) != OK` rather than by an `else` the failure could
## never get to. `or` stops at the first true half, so a platform with no native chooser never makes
## the call at all.
##
## The fallback half builds a FileDialog with ACCESS_FILESYSTEM, because the whole point of an ask is
## a file OUTSIDE the project - the default access would show the player res:// and nothing else. It
## frees itself once it is answered, so the row can be run again without stacking windows.
static func _ask_template(title: String, mode: String) -> String:
	return "var __answer_{uid} := func(accepted: bool, paths: PackedStringArray, _filter_index: int) -> void:\n" \
		+ "\tif accepted and not paths.is_empty():\n" \
		+ "\t\t_on_file_chosen(paths[0])\n" \
		+ "\telse:\n" \
		+ "\t\t_on_ask_cancelled()\n" \
		+ "if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)" \
		+ " or DisplayServer.file_dialog_show(\"%s\", \"\", \"\", false, DisplayServer.FILE_DIALOG_MODE_%s, {filters}, __answer_{uid}) != OK:\n" % [title, mode] \
		+ "\tvar __chooser_{uid} := FileDialog.new()\n" \
		+ "\t__chooser_{uid}.title = \"%s\"\n" % title \
		+ "\t__chooser_{uid}.access = FileDialog.ACCESS_FILESYSTEM\n" \
		+ "\t__chooser_{uid}.file_mode = FileDialog.FILE_MODE_%s\n" % mode \
		+ "\t__chooser_{uid}.filters = {filters}\n" \
		+ "\t__chooser_{uid}.file_selected.connect(_on_file_chosen)\n" \
		+ "\t__chooser_{uid}.file_selected.connect(__chooser_{uid}.queue_free.unbind(1))\n" \
		+ "\t__chooser_{uid}.canceled.connect(_on_ask_cancelled)\n" \
		+ "\t__chooser_{uid}.canceled.connect(__chooser_{uid}.queue_free)\n" \
		+ "\tadd_child(__chooser_{uid})\n" \
		+ "\t__chooser_{uid}.popup_centered(Vector2i(720, 480))"


## The sound loader's line: one reader per format the engine decodes at runtime, chosen by extension.
## ONE line rather than a lambda called on the spot, deliberately - an expression that spans lines is
## fine inside an action and a parse error inside a condition, and this one is meant to be usable in
## both. The conditional chain binds to the right, so each reader answers for its own extension.
##
## THE THIRD EXTENSION IS ASKED FOR TOO, whenever a fallback is named. The row's own help says the
## fallback answers "when its extension is none of the three", and it did not: a `.flac` fell off the
## end of the chain into the WAV reader, which answered with null and an engine error on the console.
## So the guarded form ends at the fallback rather than at a reader, and the promise on the row is the
## one the line keeps. The unguarded form is unchanged - nothing to fall back TO is exactly what
## leaving the slot blank asks for.
##
## AND THE WHOLE LINE WEARS BRACKETS, not just the chain inside it. This is the only expression here
## whose value is a conditional even with no fallback named, so it is the only one that needs an
## OUTER pair regardless: `a if b else c` spliced between two operators binds them into its branches,
## and `Sound From File == null` in a Compare Values row read as `<stream> if the file is there else
## (null == null)` - which answers a STREAM where a comparison was asked for. A wrong answer, not a
## parse error, so nothing would ever have said so. The inner pair stays where it was, around the
## extension chain, so the guard still reads as one thing the file's presence chooses.
static func _sound_template() -> String:
	var extension: String = "({path}).get_extension().to_lower()"
	return "({?fallback}({/fallback}" \
		+ "AudioStreamMP3.load_from_file({path}) if %s == \"mp3\" else " % extension \
		+ "AudioStreamOggVorbis.load_from_file({path}) if %s == \"ogg\" else " % extension \
		+ "AudioStreamWAV.load_from_file({path})" \
		+ "{?fallback} if %s == \"wav\" else {fallback}) " % extension \
		+ "if FileAccess.file_exists({path}) else {fallback}{/fallback})"


## ────────────────────────────────────────────────────────────────────────────────────────────────
## SCENE FILES: what the player built, written down - and the question to ask before reading one back.
##
## A scene file is the one file format in this list that can carry BEHAVIOUR. A `.tscn` is a table of
## resources, and a resource may be a script, so building one runs its author's code with everything
## this game can reach. That single fact is what makes these two rows a pair rather than two rows:
## one writes a scene file out of the running game, and the other is the question worth asking before
## anything reads one back in.
##
##   the writer   Save Branch As Scene File. The OWNER WALK is the row: Godot packs the children a
##                branch root OWNS, and a node added while the game runs has no owner at all, so a
##                plain pack writes an empty scene and reports nothing. The walk is emitted into the
##                script where it can be read, exactly as the archive loop beside it is.
##   the question Scene File Is Data-Only. It reads the file's own resource table as TEXT and builds
##                nothing, so asking is safe on a file this game did not write. It reads TAGS rather
##                than lines, because that is what the engine's own parser reads: `type = "Script"`
##                with spaces around the `=`, and a tag broken over two lines, are the same tag to
##                the engine, and a reading that went by substring answered true for both while the
##                script they name loaded. And it refuses EVERY `ext_resource` that points outside
##                res://, not only the scripts - a scene may name another scene or a `.tres`, each
##                with a table of its own that this reading does not open.
##
## THE EDITOR HAS ITS OWN TWIN, and the two are deliberately separate rows. Editor Tools ▸ Save Node
## As Scene packs the node you are EDITING, from a Tool sheet, with the editor's own owners already
## set by the Scene dock; this one runs in the GAME, where nothing has an owner until somebody sets
## one. Same call, different world, and a row that pretended to be both would be wrong in one of them.
##
## WHAT THIS IS NOT. It is not the save system - the game's own state belongs to the Save System
## pack's verbs. A scene file is the shape for something the player ASSEMBLED out of nodes: a level,
## a room, a ship, a base. And it is not the named-scenes registry either: naming a scene by a short
## word instead of a path is that pack's job, and nothing here keeps a second list.
static func _scene_files() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("SaveBranchAsSceneFile", "Save Branch As Scene File", _save_branch_template(), "Files", "save branch {branch} as scene file {path}", "Writes a branch of the running game out as a scene file, so a level, a room or a ship the player assembled can be loaded again later. It walks the branch first and lends every ownerless node under it the branch root as its owner, because Godot writes out only what the root owns - that walk is the whole reason this is a row and not one line - and gives that ownership back once the file is packed, so the running game is left as it was and a branch inside a branch you already saved still writes a whole file. Editor Tools ▸ Save Node As Scene is the same job on the editor's side of the line, packing the node you are editing from a Tool sheet; this is the game's side, writing what the player made. Both the pack and the write report a failure through the debugger rather than doing nothing quietly.").param_typed("Node", "branch", "self", "Branch", "The node whose whole branch is written out. It becomes the root of the scene file, and every node under it that has no owner yet is LENT this node as its owner while the file is packed - which is what puts them in the file at all - and gets it back the moment the pack is done, so saving a branch and then a branch above it both write whole files. A node that already belongs to another scene keeps that owner and is left out, so a branch full of instanced scenes saves as the branch plus those instances, not as a copy of their insides.", "expression").param("path", "\"user://built_level.tscn\"", "Save To", "Where to write the scene file. Prefer user:// - res:// is the game's own files and is read-only once the game is exported, so a level the player built cannot be saved there.", "file_path").featured())
	descriptors.append(F.cond("SceneFileIsDataOnly", "Scene File Is Data-Only", "%s({path})" % SceneTrust.HELPER_NAME, "Files", "scene file {path} is data-only", "True when a scene file brings nothing in from outside the game: no script written inside it, nothing built by a value in a node's body, and every file it points at under res://, which is the game's own. It reads the file's own resource table as TEXT, tag by tag the way the engine's own parser reads it, and instantiates nothing. Ask it above a row that builds a scene which did not come with the game - a level the player built, a pack somebody sent them - because a scene file can name a script, and building one runs that script with everything this game can reach. Anything it cannot read as a scene table answers false, because an unfamiliar file is not a file that has been cleared. A true answer means the file brings no code of its OWN: a cleared scene may still hold a connection, an animation track or a placeholder that reaches your game's own methods, so it is still somebody else's data.").param("path", "\"user://built_level.tscn\"", "Scene File", "The scene file to read. It is read as TEXT and nothing in it is built, so asking this question about a file from anywhere is safe. A file that is missing, unreadable, or saved in the binary form this cannot read answers false - an unreadable file is not a file that has been cleared.", "file_path").featured())
	return descriptors


## The save row's emitted lines. The owner walk, the pack, and the write, each of which can be read.
##
## THE WALK IS FIRST AND IT IS THE POINT. `PackedScene.pack` writes out the root plus every node the
## ROOT OWNS, and a node added while the game runs is owned by nothing at all - so a branch the player
## built packs as a scene holding one node, saves perfectly, and loads back empty. Nothing reports
## that: pack() returns OK, ResourceSaver.save() returns OK, and the file is simply not what anybody
## meant. The walk asks for the children NOT already owned (`find_children` with its owned flag off),
## and gives an owner only to those that have none - a node that belongs to an instanced scene keeps
## its own owner, which is what makes that instance save as an instance instead of as a copy.
##
## AND THE OWNERSHIP IS GIVEN BACK, which is the other half of the same idea. The walk BORROWS: it
## remembers which nodes it adopted and puts their owner back to nothing the moment the pack is done.
## Without that the row is not repeatable - save the Room, then save the Level it is in, and the
## Level's file comes back holding a childless Room, because the props now belong to the Room and
## pack() writes out only what the ROOT owns. Both engine calls still answer OK, nothing is reported,
## and the file is silently short: the very failure the walk exists to prevent, made by the walk.
## Giving the ownership back also means the row leaves the running game exactly as it found it -
## a save is a save, not an edit.
##
## BOTH FAILURES ARE ANSWERED. `pack` refuses a node that is not in a tree; a write can fail on a
## folder that is not there, a full disk or a read-only path. Either one leaves no file and, without
## these two lines, no word about it anywhere.
static func _save_branch_template() -> String:
	return "var __branch_{uid}: Node = {branch}\n" \
		+ "var __adopted_{uid}: Array[Node] = []\n" \
		+ "for __part_{uid}: Node in __branch_{uid}.find_children(\"*\", \"\", true, false):\n" \
		+ "\tif __part_{uid}.owner == null:\n" \
		+ "\t\t__part_{uid}.owner = __branch_{uid}\n" \
		+ "\t\t__adopted_{uid}.append(__part_{uid})\n" \
		+ "var __scene_{uid} := PackedScene.new()\n" \
		+ "var __packed_{uid} := __scene_{uid}.pack(__branch_{uid})\n" \
		+ "for __lent_{uid}: Node in __adopted_{uid}:\n" \
		+ "\t__lent_{uid}.owner = null\n" \
		+ "if __packed_{uid} != OK:\n" \
		+ "\tpush_error(\"Save Branch As Scene File: %s could not be packed (error %d).\" % [__branch_{uid}.name, __packed_{uid}])\n" \
		+ "elif ResourceSaver.save(__scene_{uid}, {path}) != OK:\n" \
		+ "\tpush_error(\"Save Branch As Scene File: nothing was written to %s.\" % {path})"
