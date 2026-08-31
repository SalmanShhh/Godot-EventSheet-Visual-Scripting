# EventForge module - File management (read / write / JSON, plus directory + file operations).
#
# Everyday on-disk work - save & load text, serialise to JSON, copy / move / delete files, and manage
# directories - so save systems, config files and level data never force a drop to GDScript. Each
# compiles to the exact native FileAccess / DirAccess call. Reads use the static, null-safe accessors
# (FileAccess.get_file_as_string / DirAccess.get_files_at - they return "" / [] on error rather than
# crashing); writes guard the FileAccess handle so a bad path can't null-deref. Grouped under
# Files / Files: Directories.
#
# EVERY PATH FIELD SAYS ITS PLACE. The path parameters carry the `file_path` hint, which takes any
# GDScript expression exactly as an ordinary expression field does and is spelled apart from it only
# so a muted lead can sit under the box naming the place the path is in - user:// (the player's
# folder: writable, per-player, survives updates) or res:// (the game's own files: READ-ONLY once
# exported). The reading of those places, and where user:// really is on each desktop platform, live
# once in EventForgeFilePlaces, which the lead, the help strip and the Doctor all ask.
@tool
class_name EventForgeFileACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Files - read / write / JSON / copy / move / delete (act on a path string or expression) ──
	descriptors.append(F.make_descriptor("Core", "FileExists", "File Exists", ACEDescriptor.ACEType.CONDITION, "FileAccess.file_exists({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File path to test. Prefer user:// (res:// is read-only when exported).", "file_path")], "Files", "file {path} exists")
		.described("True when a file exists at that path, so you can check before reading or writing it."))
	descriptors.append(F.make_descriptor("Core", "ReadTextFile", "Read Text File", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_string({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to read in full as a String (\"\" if it is missing or unreadable).", "file_path")], "Files", "text of file {path}")
		.described("Returns the whole file's contents as text (empty if it's missing or unreadable)."))
	descriptors.append(F.make_descriptor("Core", "GetFileSize", "File Size (bytes)", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_bytes({path}).size()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to measure (0 bytes if missing).", "file_path")], "Files", "size of file {path}")
		.described("Returns a file's size in bytes, or zero if the file doesn't exist."))
	descriptors.append(F.make_descriptor("Core", "WriteTextFile", "Write Text File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to write. OVERWRITES any existing file. Use user:// (res:// is read-only when exported).", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text content to store.", "expression")], "Files", "write {text} to file {path}")
		.described("Saves text to a file, overwriting anything already there (great for save data)."))
	descriptors.append(F.make_descriptor("Core", "AppendTextFile", "Append To File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.READ_WRITE)\nif __file_{uid}:\n\t__file_{uid}.seek_end()\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://log.txt\"", "Path", "Existing file to append to (no-op if it does not exist - Write it first).", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text to append at the end of the file.", "expression")], "Files", "append {text} to file {path}")
		.described("Adds text to the end of an existing file without erasing it (handy for logs)."))
	descriptors.append(F.make_descriptor("Core", "DeleteFile", "Delete File", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File (or empty directory) to delete.", "file_path")], "Files", "delete file {path}")
		.described("Permanently deletes a file (or an empty folder) from disk."))
	descriptors.append(F.make_descriptor("Core", "CopyFile", "Copy File", ACEDescriptor.ACEType.ACTION, "DirAccess.copy_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://save.dat\"", "From", "Source file path.", "file_path"), F.make_param("to", "String", "\"user://backup.dat\"", "To", "Destination file path.", "file_path")], "Files", "copy {from} to {to}")
		.described("Copies a file from one path to another, leaving the original in place."))
	descriptors.append(F.make_descriptor("Core", "MoveFile", "Move / Rename File", ACEDescriptor.ACEType.ACTION, "DirAccess.rename_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://old.dat\"", "From", "Current file (or directory) path.", "file_path"), F.make_param("to", "String", "\"user://new.dat\"", "To", "New path / name.", "file_path")], "Files", "move {from} to {to}")
		.described("Moves or renames a file (or folder) to a new path."))

	# ── Files: Directories - make / remove / test / list directories ──
	descriptors.append(F.make_descriptor("Core", "DirExists", "Directory Exists", ACEDescriptor.ACEType.CONDITION, "DirAccess.dir_exists_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory path to test.", "file_path")], "Files: Directories", "directory {path} exists")
		.described("True when a folder exists at that path, useful before creating or listing it."))
	descriptors.append(F.make_descriptor("Core", "MakeDir", "Make Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.make_dir_recursive_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory to create (any missing parent directories are created too).", "file_path")], "Files: Directories", "make directory {path}")
		.described("Creates a folder, building any missing parent folders along the way."))
	descriptors.append(F.make_descriptor("Core", "RemoveDir", "Remove Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "EMPTY directory to remove (delete its files first).", "file_path")], "Files: Directories", "remove directory {path}")
		.described("Deletes an empty folder (clear out its files first)."))
	descriptors.append(F.make_descriptor("Core", "ListFiles", "List Files", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_files_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose file names to list (PackedStringArray; [] if missing).", "file_path")], "Files: Directories", "files in {path}")
		.described("Returns the list of file names inside a folder (empty if the folder is missing)."))
	descriptors.append(F.make_descriptor("Core", "ListDirs", "List Subdirectories", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_directories_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose subdirectory names to list.", "file_path")], "Files: Directories", "subdirectories in {path}")
		.described("Returns the list of subfolder names inside a folder."))

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
	descriptors.append(F.make_descriptor("Core", "ReadTextFileOr", "Read Text File (or a fallback)", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_string({path}){?fallback} if FileAccess.file_exists({path}) else {fallback}{/fallback}", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to read in full as a String. Prefer user:// - res:// is read-only once the game is exported.", "file_path"), F.make_param("fallback", "String", "\"\"", "If missing", "What the expression reads as when there is no file at that path. Leave it blank to read the file plainly, exactly as Read Text File does.", "expression")], "Files", "text of file {path}, or {fallback}")
		.described("Reads a whole file as text, using the fallback you name when the file is not there. The guard is written into the line and shown on the row, so nothing happens that the code does not say."))
	descriptors.append(F.make_descriptor("Core", "WriteTextFileInFolder", "Write Text File (in a folder)", ACEDescriptor.ACEType.ACTION, "{?folder=make its folder first}DirAccess.make_dir_recursive_absolute({path}.get_base_dir())\n{/folder}var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://runs/latest.txt\"", "Path", "File to write, inside one or more folders. OVERWRITES any existing file. Prefer user:// - res:// is read-only once the game is exported.", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text content to store.", "expression"), F.make_param("folder", "String", "make its folder first", "Folder", "Whether to create the folders in that path before writing. Godot does not make them on the way to opening a file, so a write into a folder that is not there fails.", "", [{"key": "make its folder first", "label": "Make the folder first"}, {"key": "its folder is already there", "label": "The folder is already there"}])], "Files", "write {text} to file {path} - {folder}")
		.described("Saves text to a file inside a folder, optionally creating the folders on the way. The folder line is emitted above the write and shown in the row, never behind your back."))
	descriptors.append(F.make_descriptor("Core", "OpenUserDataFolder", "Open The Player's Data Folder", ACEDescriptor.ACEType.ACTION, "OS.shell_open(ProjectSettings.globalize_path({path}))", "", [F.make_param("path", "String", "\"user://\"", "Path", "Folder to open, inside user://. The path is turned into a real one on the player's machine before it is handed to the desktop.", "file_path")], "Files", "open the player's data folder {path}")
		.described("Opens the player's own data folder in their desktop file browser - the real folder user:// stands for on that machine."))

	descriptors.append_array(_content_from_outside())
	return descriptors


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
##                    AudioStream in one.
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
	descriptors.append(F.make_descriptor("Core", "OnFilesDropped", "On Files Dropped", ACEDescriptor.ACEType.TRIGGER, "", "files_dropped", [
		F.make_param("files", "PackedStringArray", "", "Files", "Every path the player let go of, in one list - a drop can carry more than one file. They are real paths on that machine, not res:// or user:// ones.")
	], "Files", "On files dropped {files}", "Node")
		.described("Runs when the player drags files from their desktop onto the game window and lets go. DESKTOP ONLY: Windows, macOS and Linux raise it, and a web or mobile build never does, so keep another way in beside it.").featured())

	# ── The ask door: two actions that open a chooser, two triggers that answer it ────────────────
	#
	# THE BRANCH IS IN THE CODE, NOT BEHIND IT. Most desktops have a chooser of their own and it is
	# the one the player knows; a platform without one still has to ask somehow. Both spellings are
	# emitted, in an if/else a reader can see, because a row that quietly picked one of two very
	# different windows would be a row nobody could debug.
	#
	# THE ANSWER IS A TRIGGER. `DisplayServer.file_dialog_show` returns an Error, not a path: the
	# chooser is another window, and the player answers it long after this line has run. So the two
	# ways it can end are the two events below, and the emitted code calls them by name.
	descriptors.append(F.make_descriptor("Core", "AskForAFileToOpen", "Ask For A File To Open", ACEDescriptor.ACEType.ACTION, _ask_template("Open a file", "OPEN_FILE"), "", [
		_filters_param("Which files the player may pick. One entry per line of the list, spelled the way Godot spells a filter: the patterns, a semicolon, then the words the chooser shows - \"*.png,*.jpg;Images\".")
	], "Files", "Ask for a file to open ({filters})")
		.described("Opens the player's own file chooser so they can pick a file to read. The answer arrives as On a file chosen, or as On the ask cancelled - both of which the sheet needs an event for, because the emitted line calls them by name.").featured())
	descriptors.append(F.make_descriptor("Core", "AskWhereToSave", "Ask Where To Save", ACEDescriptor.ACEType.ACTION, _ask_template("Save a file", "SAVE_FILE"), "", [
		_filters_param("Which kind of file is being written. One entry per line of the list, spelled the way Godot spells a filter: the patterns, a semicolon, then the words the chooser shows - \"*.png;PNG image\".")
	], "Files", "Ask where to save ({filters})")
		.described("Opens the player's own save chooser so they can name a file and a folder to write into. Nothing is written by this row: the path arrives as On a file chosen, and a write row does the writing."))
	descriptors.append(F.make_descriptor("Core", "OnFileChosen", "On A File Chosen", ACEDescriptor.ACEType.TRIGGER, "", "", [
		F.make_param("path", "String", "", "Path", "The file the player picked, as a real path on their machine. It is a path and nothing more - reading it is a separate row.")
	], "Files", "On a file chosen {path}")
		.described("Runs when the player answered an Ask row by picking a file. Both Ask rows end here, so a sheet that asks two different questions remembers which one it asked.").featured())
	descriptors.append(F.make_descriptor("Core", "OnAskCancelled", "On The Ask Cancelled", ACEDescriptor.ACEType.TRIGGER, "", "", [], "Files", "On the ask cancelled")
		.described("Runs when the player closed an Ask row's chooser without picking anything. Put whatever was waiting on the answer back the way it was here."))

	# ── The loaders: content from outside the project, with the fallback in the second slot ───────
	descriptors.append(F.make_descriptor("Core", "LoadImageFile", "Image From File", ACEDescriptor.ACEType.EXPRESSION, "ImageTexture.create_from_image(Image.load_from_file({path})){?fallback} if FileAccess.file_exists({path}) else {fallback}{/fallback}", "", [
		F.make_param("path", "String", "\"user://portrait.png\"", "Path", "The picture to read, in any format Godot decodes at runtime: .png, .jpg / .jpeg, .webp, .bmp, .tga, .svg, .ktx, .dds and .hdr.", "file_path"),
		F.make_param("fallback", "String", "null", "If missing", "What the expression reads as when there is no file at that path. Leave it blank to read the file plainly, with no guard around it.", "expression")
	], "Files", "image of file {path}, or {fallback}")
		.described("Reads a picture from outside the project and answers with a texture, ready to hand to a Sprite or a TextureRect. No import step is involved: what you get back is a texture in a variable, and it lives only as long as something holds it.").featured())
	descriptors.append(F.make_descriptor("Core", "LoadSoundFile", "Sound From File", ACEDescriptor.ACEType.EXPRESSION, _sound_template(), "", [
		F.make_param("path", "String", "\"user://track.ogg\"", "Path", "The sound to read. EXACTLY THREE formats decode at runtime and the line checks for those three by extension: .mp3, .ogg (Ogg Vorbis) and .wav. Prefer a variable here - the path is read once per format the line checks.", "file_path"),
		F.make_param("fallback", "String", "null", "If missing", "What the expression reads as when there is no file at that path, or when its extension is none of the three. Leave it blank to read the file plainly, with no guard around it.", "expression")
	], "Files", "sound of file {path}, or {fallback}")
		.described("Reads a sound from outside the project and answers with an audio stream, ready to hand to a player node. The line names one reader per format the engine decodes at runtime, so a file it cannot decode reads as the fallback rather than as silence nobody explained."))

	return descriptors


## The filters list both Ask rows carry. Same field, different words about what it is for, so each
## row's help strip describes the question that row is actually asking.
static func _filters_param(description: String) -> ACEParam:
	return F.make_param("filters", "PackedStringArray", "PackedStringArray([\"*.png,*.jpg;Images\"])", "Filters", description, "expression")


## The Ask rows' emitted lines. `mode` is the tail of the two constants that name the same choice on
## the two sides of the branch (DisplayServer.FILE_DIALOG_MODE_<mode> and FileDialog.FILE_MODE_<mode>),
## which is why one word fills both and the two halves cannot drift apart.
##
## The fallback half builds a FileDialog with ACCESS_FILESYSTEM, because the whole point of an ask is
## a file OUTSIDE the project - the default access would show the player res:// and nothing else. It
## frees itself once it is answered, so the row can be run again without stacking windows.
static func _ask_template(title: String, mode: String) -> String:
	return "if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):\n" \
		+ "\tvar __answer_{uid} := func(accepted: bool, paths: PackedStringArray, _filter_index: int) -> void:\n" \
		+ "\t\tif accepted and not paths.is_empty():\n" \
		+ "\t\t\t_on_file_chosen(paths[0])\n" \
		+ "\t\telse:\n" \
		+ "\t\t\t_on_ask_cancelled()\n" \
		+ "\tDisplayServer.file_dialog_show(\"%s\", \"\", \"\", false, DisplayServer.FILE_DIALOG_MODE_%s, {filters}, __answer_{uid})\n" % [title, mode] \
		+ "else:\n" \
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
## both. The conditional chain binds to the right, so each reader answers for its own extension and
## the last one is the else.
static func _sound_template() -> String:
	var extension: String = "{path}.get_extension().to_lower()"
	return "{?fallback}({/fallback}" \
		+ "AudioStreamMP3.load_from_file({path}) if %s == \"mp3\" else " % extension \
		+ "AudioStreamOggVorbis.load_from_file({path}) if %s == \"ogg\" else " % extension \
		+ "AudioStreamWAV.load_from_file({path})" \
		+ "{?fallback}) if FileAccess.file_exists({path}) else {fallback}{/fallback}"
