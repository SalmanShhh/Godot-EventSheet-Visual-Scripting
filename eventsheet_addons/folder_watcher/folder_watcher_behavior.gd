## @ace_tags(files, tools)
## @ace_category("Folder Watcher")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/folder_watcher/icon.svg")
class_name FolderWatcher
extends Node
## Watches one folder and raises On A File Appeared / Changed / Removed. Godot has no runtime file watcher, so this POLLS: it reads the folder every few seconds and compares what it finds with what it found last time, by name and by modified time. Watch Folder starts it, Stop Watching parks it, and a stopped watcher costs nothing per frame.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("FolderWatcher behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On A File Appeared")
signal file_appeared(path: String)
## @ace_trigger
## @ace_name("On A File Changed")
signal file_changed(path: String)
## @ace_trigger
## @ace_name("On A File Removed")
signal file_removed(path: String)

## The folder to look in. Prefer user:// - a folder under res:// is packed into the export and cannot be written to once the game ships, so nothing in it will ever change.
@export var watched_folder: String = "user://mods"
## Seconds between looks. Every look is one directory read plus one modified-time question per file, so a second or two is generous for a mods folder and far too often for a folder holding thousands of files.
@export var look_every_seconds: float = 2.0
## Which file names count, as a pattern with * and ? in it - "*.json" for data files, "*" for all of them. Names that do not match are invisible to this watcher: they raise nothing, and they are not looked up.
@export var only_names_like: String = "*"
## Start watching as soon as the node is ready, using the folder and interval above. Off by default, because a watcher is usually started by the sheet at the moment the game actually cares.
@export var watch_on_ready: bool = false
var _seen: Dictionary = {}
var _since_last_look: float = 0.0
var _watching: bool = false

# Raised on the first look that finds a file the look before did not.
# Raised when a file that was already there has a NEWER modified time than it had at the last
# look. A program that writes a file in several goes can raise this more than once per save.
# Raised on the first look that no longer finds a file the look before did. The path names
# what went; there is nothing left at it to read.

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
	if _since_last_look < maxf(look_every_seconds, 0.1):
		return
	_since_last_look = 0.0
	_look()

## @ace_action
## @ace_featured
## @ace_name("Watch Folder")
## @ace_category("Folder Watcher")
## @ace_description("Starts watching a folder, looking every so many seconds. This is a POLL: the folder is read on that interval and compared with the reading before it, because Godot raises no file-change notification of its own at run time. The first look is the baseline and raises nothing - a folder that already holds files is not a folder where things just happened.")
## @ace_display_template("Watch folder [b]{folder}[/b] every [b]{every_seconds}[/b] s")
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

## @ace_hidden
func _look() -> void:
	var found: Dictionary = _read_folder()
	for entry: String in found:
		if not _seen.has(entry):
			file_appeared.emit(watched_folder.path_join(entry))
		elif int(_seen[entry]) != int(found[entry]):
			file_changed.emit(watched_folder.path_join(entry))
	for entry: String in _seen:
		if not found.has(entry):
			file_removed.emit(watched_folder.path_join(entry))
	_seen = found

# Folder Watcher: a POLL, not a subscription. Watch Folder starts looking every few seconds; the difference between one look and the next is what raises On A File Appeared / Changed / Removed. Stopped, it parks its per-frame tick and costs nothing.
