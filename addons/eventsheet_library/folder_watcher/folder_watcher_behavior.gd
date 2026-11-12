## @ace_tags(files, tools)
## @ace_category("Folder Watcher")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/folder_watcher/icon.svg")
class_name FolderWatcher
extends Node
## Watches one folder and raises On A File Appeared / Changed / Removed. Godot has no runtime file watcher, so this POLLS: it reads the folder every few seconds and compares what it finds with what it found last time, by name and by modified time. Watch Folder starts it, Stop Watching parks it, and a stopped watcher costs nothing per frame.

## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Folder Watcher needs a parent node: put it under one, or set Acts on.")

## Raised on the first look that finds a file the look before did not.
## @ace_trigger
## @ace_name("On A File Appeared")
signal file_appeared(path: String)
## Raised when a file that was already there has a DIFFERENT modified time from the one it had
## at the last look. Usually that means newer; a file restored from a backup or copied back
## over is older and is still a change. A program that writes a file in several goes can raise
## this more than once per save, and two writes inside the same second read as one.
##
## THE READING IS THE MODIFIED TIME AND NOTHING ELSE, so a replacement that carries the time
## the old file had is invisible here: a copy made with its timestamps preserved, or a file
## put back by a restore tool, is different content under an unchanged stamp. Asking the size
## as well would mean opening every watched file on every look, which is a cost this row does
## not pay behind your back - so what it can and cannot see is said instead.
## @ace_trigger
## @ace_name("On A File Changed")
signal file_changed(path: String)
## Raised on the first look that no longer finds a file the look before did. The path names
## what went; there is nothing left at it to read.
## @ace_trigger
## @ace_name("On A File Removed")
signal file_removed(path: String)

## Folder to watch; prefer user:// since res:// cannot be written once exported.
@export var watched_folder: String = "user://mods"
## Seconds between folder checks; a second or two is plenty.
@export var look_every_seconds: float = 2.0
## File name pattern to watch, using * and ?; for example *.json.
@export var only_names_like: String = "*"
## Start watching as soon as the node is ready.
@export var watch_on_ready: bool = false
## Files seen at the last look, with their modified time.
var _seen: Dictionary = {}
## Seconds since the folder was last checked.
var _since_last_look: float = 0.0
## True while the folder is being watched.
var _watching: bool = false

func _ready() -> void:
	# Nothing is being watched yet, so there is nothing to look for once a frame.
	set_process(false)
	if watch_on_ready:
		watch_folder(watched_folder, look_every_seconds)

func _process(delta: float) -> void:
	if not _watching:
		set_process(false)
		return
	_since_last_look += delta
	# A zero or negative interval would be a directory read every single frame, which is never
	# what anybody meant by an interval, so the shortest gap the watcher will honour is a tenth
	# of a second.
	var interval: float = maxf(look_every_seconds, 0.1)
	if _since_last_look < interval:
		return
	# The overshoot is CARRIED rather than thrown away. A frame almost never lands exactly on
	# the interval, and starting the count at zero each time adds a frame to every gap, so the
	# looks drift against the clock the row named. At most one interval is carried: a long stall
	# is a stall, not a reason to read the folder every frame until the arrears are paid.
	_since_last_look = minf(_since_last_look - interval, interval)
	_look()

## @ace_action
## @ace_featured
## @ace_name("Watch Folder")
## @ace_category("Folder Watcher")
## @ace_description("Starts watching a folder, looking every so many seconds. This is a POLL: the folder is read on that interval and compared with the reading before it, because Godot raises no file-change notification of its own at run time. The first look is the baseline and raises nothing - a folder that already holds files is not a folder where things just happened. A tenth of a second is the shortest gap honoured, so a zero or a negative number is a look every tenth of a second rather than a look every frame.")
## @ace_display_template("Watch folder [b]{folder}[/b] every [b]{every_seconds}[/b] s")
## @ace_param(folder, desc: "The folder to watch. Its files are read on the interval below; the folders inside it are not walked, and a folder that is not there yet raises nothing until it appears. Prefer user:// - res:// is the game's own files and is a packed archive once the game is exported.")
## @ace_param(every_seconds, desc: "Seconds between looks. Every look is one directory read plus one modified-time question per file, so a second or two is generous for a mods folder and far too often for one holding thousands of files. A TENTH OF A SECOND IS THE FLOOR: a zero or a negative number is honoured as 0.1, because a look every frame is not what anybody means by an interval.")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.watch_folder({folder}, {every_seconds})")
func watch_folder(folder: String, every_seconds: float) -> void:
	watched_folder = folder
	look_every_seconds = every_seconds
	# The baseline: what is there now, recorded without raising anything.
	_seen = _read_folder()
	_since_last_look = 0.0
	_watching = true
	# Looking costs a frame's attention only while a watch is running.
	set_process(true)

## @ace_action
## @ace_featured
## @ace_name("Stop Watching")
## @ace_category("Folder Watcher")
## @ace_description("Stops looking. The per-frame tick is parked, so a stopped watcher is a node the engine no longer visits at all, and nothing is read from disk until it is started again.")
## @ace_display_template("[b]Stop[/b] watching the folder")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.stop_watching()")
func stop_watching() -> void:
	_watching = false
	set_process(false)

## @ace_action
## @ace_name("Look Now")
## @ace_category("Folder Watcher")
## @ace_description("Takes one look immediately, without waiting for the interval, and raises whatever the difference means. Use it after your own game has written into the folder, when waiting a second or two for the next look would just be a pause nobody asked for.")
## @ace_display_template("[b]Look[/b] at the folder now")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.look_now()")
func look_now() -> void:
	_since_last_look = 0.0
	_look()

## @ace_condition
## @ace_name("Is Watching")
## @ace_category("Folder Watcher")
## @ace_description("True while a watch is running - that is, between Watch Folder and Stop Watching.")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.is_watching()")
func is_watching() -> bool:
	return _watching

## @ace_expression
## @ace_name("Watched File Count")
## @ace_category("Folder Watcher")
## @ace_description("How many files the last look found, after the name filter. Zero before the first look.")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.watched_file_count()")
func watched_file_count() -> int:
	return _seen.size()

## @ace_expression
## @ace_name("Watched File Names")
## @ace_category("Folder Watcher")
## @ace_description("The file names the last look found, after the name filter, in sorted order. Names, not whole paths - join one onto the folder to read it.")
## @ace_icon("res://eventsheet_addons/folder_watcher/icon.svg")
## @ace_codegen_template("$FolderWatcher.watched_file_names()")
func watched_file_names() -> Array:
	return _seen.keys()

## What the folder held at the last look: file name -> the time that file was last modified.
## The whole mechanism is this dictionary compared with the next look's.
## @ace_hidden
func _read_folder() -> Dictionary:
	var found: Dictionary = {}
	# One directory read per look. The names are sorted so two machines walking the same folder
	# raise the same events in the same order - the engine promises no order of its own.
	var names: PackedStringArray = DirAccess.get_files_at(watched_folder)
	names.sort()
	for entry: String in names:
		if not only_names_like.is_empty() and not entry.match(only_names_like):
			continue
		found[entry] = FileAccess.get_modified_time(watched_folder.path_join(entry))
	return found

## One look: read the folder, raise what the difference means, and keep the new reading as the
## one the next look is compared against.
## @ace_hidden
func _look() -> void:
	# A FOLDER THAT IS NOT THERE IS NOT A FOLDER THAT EMPTIED. DirAccess answers with an
	# empty list for a folder that was deleted, unmounted or is on a drive somebody unplugged,
	# exactly as it does for one holding nothing - so a look taken then would raise On A File
	# Removed for every file it held, and On A File Appeared for every one of them when it came
	# back. Nothing is compared until the folder answers again.
	if not DirAccess.dir_exists_absolute(watched_folder):
		return
	var found: Dictionary = _read_folder()
	for entry: String in found:
		if not _seen.has(entry):
			file_appeared.emit(watched_folder.path_join(entry))
		# DIFFERENT, not newer. A file restored from a backup or copied back over carries an
		# OLDER modified time and really has changed, so this asks whether the time moved rather
		# than which way it moved. Two writes inside the same second read as one look's worth.
		elif int(_seen[entry]) != int(found[entry]):
			file_changed.emit(watched_folder.path_join(entry))
	for entry: String in _seen:
		if not found.has(entry):
			file_removed.emit(watched_folder.path_join(entry))
	_seen = found

# Folder Watcher: a POLL, not a subscription. Watch Folder starts looking every few seconds; the difference between one look and the next is what raises On A File Appeared / Changed / Removed. Stopped, it parks its per-frame tick and costs nothing.
