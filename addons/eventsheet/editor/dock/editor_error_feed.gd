@tool
class_name EventSheetEditorErrorFeed
extends RefCounted

# Script errors of a game started from the editor, read from what the editor itself already receives.
#
# Godot sends every script error of a running game to the editor's debugger, whatever script raised it:
# the Debugger panel's Errors tab, its Stack Trace and the red line on the Script screen all come from
# that one message. The debugger node re-announces each message on its `debug_data` signal as
# (message, data), and for an "error" message the data is
#   [hour, minute, second, msec, source_file, source_func, source_line, error, description,
#    is_warning, stack_values, (file, function, line) * frames]
# so a failure in a hand-written script, in a file the sheet compiled, or in a `.gd` sheet that must
# stay byte-identical is read the same way, with nothing added to the game, its files or the project.
#
# Fragility, stated: `ScriptEditorDebugger` is an engine-internal class (not in the scripting API), so
# it is found by class name and its signal by name. If a Godot version renames either, `attach_all`
# finds nothing and `attach` returns false: the feed goes quiet and the debug compile's own announce
# (which a `.tres` sheet still carries) keeps working. Nothing here can raise.

## One script error, as the editor saw it. Fires for errors only (never warnings, never other messages).
signal error_seen(message: String, script_path: String, line: int)

const DEBUGGER_CLASS := "ScriptEditorDebugger"
const FEED_SIGNAL := "debug_data"
const ERROR_MESSAGE := "error"
## Where the pieces sit in an "error" message's data (see the layout above).
const SOURCE_FILE := 4
const SOURCE_LINE := 6
const ERROR_TEXT := 7
const DESCRIPTION := 8
const IS_WARNING := 9
const FIRST_FRAME := 11

var _attached: Array[Object] = []


## Every debugger node under `root` gets the feed. Idempotent. Returns how many nodes are attached.
func attach_all(root: Node) -> int:
	if root == null:
		return 0
	for found: Node in root.find_children("*", DEBUGGER_CLASS, true, false):
		attach(found)
	return _attached.size()


## Listens to one debugger node. False (a quiet no-op) when it has no such signal or is already attached.
func attach(debugger: Object) -> bool:
	if debugger == null or not debugger.has_signal(FEED_SIGNAL):
		return false
	var handler: Callable = _on_debug_data
	if debugger.is_connected(FEED_SIGNAL, handler):
		return false
	debugger.connect(FEED_SIGNAL, handler)
	_attached.append(debugger)
	return true


## Lets go of every node. The plugin calls this when it is taken out, so nothing of ours stays connected
## to the editor's own nodes.
func release() -> void:
	var handler: Callable = _on_debug_data
	for debugger: Object in _attached:
		if is_instance_valid(debugger) and debugger.is_connected(FEED_SIGNAL, handler):
			debugger.disconnect(FEED_SIGNAL, handler)
	_attached.clear()


func _on_debug_data(message: String, data: Array) -> void:
	# The signal carries every message the game sends, many a frame: the cheap test goes first.
	if message != ERROR_MESSAGE:
		return
	var seen: Dictionary = parse(message, data)
	if seen.is_empty():
		return
	error_seen.emit(str(seen.get("message", "")), str(seen.get("script_path", "")),
		int(seen.get("line", 0)))


## One debugger message -> {message, script_path, line}, or {} when it is not a script error worth saying
## (another kind of message, a warning, a short or malformed payload, an engine error with no script
## frame). The place is the script's own: the error's file when it is a script, else the first stack
## frame that is one - an engine error such as "Node not found" is raised in engine code on behalf of a
## script line, and that line is the one the reader wrote. Static and pure so the suite pins it.
static func parse(message: String, data: Array) -> Dictionary:
	if message != ERROR_MESSAGE or data.size() <= IS_WARNING:
		return {}
	if bool(data[IS_WARNING]):
		return {}
	var path: String = ""
	var line: int = 0
	var source: String = str(data[SOURCE_FILE])
	if is_script_path(source):
		path = source
		line = int(data[SOURCE_LINE])
	else:
		var index: int = FIRST_FRAME
		while index + 2 < data.size():
			if is_script_path(str(data[index])):
				path = str(data[index])
				line = int(data[index + 2])
				break
			index += 3
	if path.is_empty():
		return {}
	var text: String = str(data[ERROR_TEXT]).strip_edges()
	var description: String = str(data[DESCRIPTION]).strip_edges()
	if not description.is_empty() and description != text:
		text = description if text.is_empty() else "%s - %s" % [text, description]
	if text.is_empty():
		return {}
	return {"message": text, "script_path": path, "line": line}


## A GDScript file of the project (what a sheet can own): res:// and .gd.
static func is_script_path(path: String) -> bool:
	return path.begins_with("res://") and path.ends_with(".gd")


## Whether this (file, line) has already been said this run, remembering it when it has not. The same
## failure reaches the editor twice for a `.tres` sheet's debug compile (the engine's own message and
## the compile's announce) and again every frame a game goes on failing; the strip holds one report, so
## the first one wins and the rest are dropped. `seen` is the run's memory; the caller empties it when
## a new run starts.
static func is_repeat(seen: Dictionary, script_path: String, line: int) -> bool:
	var key: String = "%s:%d" % [script_path, line]
	if seen.has(key):
		return true
	seen[key] = true
	return false
