@tool
class_name EventSheetSignalFanout
extends RefCounted

# Q9 - "who reacts to this?", answered project-wide.
#
# A signal row is half a sentence on its own. `Player > Signal On Died` says something was announced
# and stops; `➜ Player On died` says something was heard and stops. The other half is in a different
# file every time, which is exactly the kind of question a reader of an event sheet never has to ask,
# because there the wiring IS the sheet.
#
# So both halves are recovered once and shown as a muted note: an emit says who listens, a handler
# says where the signal is raised. Both are derived, so nothing can go stale relative to a stored
# list, and both carry the file and line they came from so the note is click-to-jump.
#
# THREE PLACES A CONNECTION CAN LIVE, and all three are read:
#   1. `died.connect(_on_died)` / `player.died.connect(...)` in a script
#   2. `connect("died", ...)` / `player.connect("died", ...)` in a script
#   3. `[connection signal="died" from="Player" to="." method="_on_died"]` in a .tscn
#
# ONE index for the whole project, built lazily on the first question and cached for the session -
# a note drawn on a row must never cost a directory walk, and a row is drawn many times a second.
# The editor drops the cache on a filesystem change. Text only: nothing is loaded, nothing is
# instantiated, and headless answers exactly as the editor does.


## Folders whose contents are the plugin, not the user's project. Scanning them would drown a real
## answer in the editor's own vocabulary modules.
const SKIPPED_DIRS: PackedStringArray = ["res://addons", "res://.godot", "res://tests"]

## signal name -> Array[{label, path, line, kind}] - every place that LISTENS.
static var _listeners: Dictionary = {}

## signal name -> Array[{label, path, line, function}] - every place that RAISES.
static var _emitters: Dictionary = {}

static var _scanned: bool = false


## Drops the index. The editor calls this when the filesystem changes; tests call it between fixtures.
static func clear_cache() -> void:
	_listeners.clear()
	_emitters.clear()
	_scanned = false


## Everywhere one signal is listened for: Array[{label, path, line, kind}], newest question first
## built. Empty for a signal nothing connects, which is itself worth knowing.
static func listeners_of(signal_name: String) -> Array:
	_ensure_index()
	return (_listeners.get(_key(signal_name), []) as Array).duplicate(true)


## Everywhere one signal is raised: Array[{label, path, line, function}].
static func emitters_of(signal_name: String) -> Array:
	_ensure_index()
	return (_emitters.get(_key(signal_name), []) as Array).duplicate(true)


## The muted note an EMIT wears: `-> HUD, Level (2 listeners)`, "" when nothing listens. At most three
## names are spelled out - past that the count is the information and the list is noise.
static func listeners_note(signal_name: String) -> String:
	return listeners_note_for(listeners_of(signal_name))


## The same note over an already-gathered list. Pure, so the wording is pinned without a project scan.
static func listeners_note_for(found: Array) -> String:
	if found.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in found:
		var label: String = str((entry as Dictionary).get("label", ""))
		if not label.is_empty() and not Array(names).has(label):
			names.append(label)
	if names.is_empty():
		return ""
	var shown: PackedStringArray = names
	if names.size() > 3:
		shown = PackedStringArray(Array(names).slice(0, 3))
	var count_word: String = EventSheetL10n.translate("1 listener") if found.size() == 1 \
		else EventSheetL10n.translate("%d listeners") % found.size()
	return "→ %s (%s)" % [", ".join(shown), count_word]


## The muted note a HANDLER wears: `<- emitted in player.gd: Take Damage`, "" when nothing in the
## project raises the signal (an engine signal, most often, which needs no note).
static func raised_note(signal_name: String) -> String:
	return raised_note_for(emitters_of(signal_name))


## The same note over an already-gathered list. Pure, so the wording is pinned without a project scan.
static func raised_note_for(found: Array) -> String:
	if found.is_empty():
		return ""
	var first: Dictionary = found[0]
	var file_name: String = str(first.get("path", "")).get_file()
	var where: String = str(first.get("function", ""))
	var raised: String = EventSheetL10n.translate("emitted in %s") % file_name
	if not where.is_empty():
		raised = "%s: %s" % [raised, where]
	if found.size() > 1:
		raised = "%s %s" % [raised, EventSheetL10n.translate("(+%d more)") % (found.size() - 1)]
	return "← %s" % raised


## Where a click on a note lands: {path, line} of the first place the signal is listened for (for an
## emit note) or raised (for a handler note). {} when there is nowhere to go.
static func jump_target(signal_name: String, from_emit: bool) -> Dictionary:
	var found: Array = listeners_of(signal_name) if from_emit else emitters_of(signal_name)
	if found.is_empty():
		return {}
	var first: Dictionary = found[0]
	return {"path": str(first.get("path", "")), "line": int(first.get("line", 0))}


static func _key(signal_name: String) -> String:
	return signal_name.strip_edges().trim_prefix("\"").trim_suffix("\"")


static func _ensure_index() -> void:
	if _scanned:
		return
	# Set BEFORE the walk, never after: a scan that throws would otherwise leave the flag clear and
	# every row would re-walk the project. Half an index is a wrong note; a re-walk per frame is a
	# frozen editor.
	_scanned = true
	_scan_directory("res://")


static func _scan_directory(directory_path: String) -> void:
	if Array(SKIPPED_DIRS).has(directory_path.trim_suffix("/")):
		return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(full_path)
		else:
			var extension: String = entry.get_extension().to_lower()
			if extension == "gd":
				_index_script(full_path)
			elif extension == "tscn":
				_index_scene(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _index_script(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty() or not (text.contains("connect") or text.contains("emit")):
		return
	var label: String = object_label_of_script(path)
	var current_function: String = ""
	var line_number: int = 0
	for line: String in text.split("\n"):
		line_number += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if stripped.begins_with("func "):
			var bare: String = stripped.substr(5).get_slice("(", 0).strip_edges()
			current_function = EventSheetViewportLenses.humanize_identifier(bare, true)
		for connected: String in connected_signals_in(stripped):
			_record(_listeners, connected, {
				"label": label, "path": path, "line": line_number, "kind": "script"
			})
		for raised: String in emitted_signals_in(stripped):
			_record(_emitters, raised, {
				"label": label, "path": path, "line": line_number, "function": current_function
			})


static func _index_scene(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty() or not text.contains("[connection "):
		return
	var root_name: String = ""
	var line_number: int = 0
	for line: String in text.split("\n"):
		line_number += 1
		if line.begins_with("[node ") and root_name.is_empty() and not line.contains("parent="):
			root_name = _attribute(line, "name")
			continue
		if not line.begins_with("[connection "):
			continue
		var signal_name: String = _attribute(line, "signal")
		if signal_name.is_empty():
			continue
		var to_path: String = _attribute(line, "to")
		var label: String = root_name if (to_path == "." or to_path.is_empty()) else to_path.get_file()
		_record(_listeners, signal_name, {
			"label": label, "path": path, "line": line_number, "kind": "scene"
		})


## The signals one line CONNECTS to, in both spellings GDScript allows.
static func connected_signals_in(stripped: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	# `connect("died", ...)` and `player.connect("died", ...)` are the same marker, so one sweep
	# catches both spellings of the quoted form.
	var marker: String = "connect(\""
	var quoted: int = stripped.find(marker)
	while quoted >= 0:
		var start: int = quoted + marker.length()
		var end: int = stripped.find("\"", start)
		if end > start:
			var quoted_name: String = stripped.substr(start, end - start)
			if not Array(found).has(quoted_name):
				found.append(quoted_name)
		quoted = stripped.find(marker, quoted + 1)
	# `died.connect(...)` / `player.died.connect(...)`: the signal is the identifier before `.connect`.
	var plain: int = stripped.find(".connect(")
	while plain >= 0:
		if not stripped.substr(plain).begins_with(".connect(\""):
			var before: String = stripped.substr(0, plain)
			var identifier: String = _trailing_identifier(before)
			if not identifier.is_empty() and not Array(found).has(identifier):
				found.append(identifier)
		plain = stripped.find(".connect(", plain + 1)
	return found


## The signals one line RAISES, in both spellings.
static func emitted_signals_in(stripped: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var legacy: int = stripped.find("emit_signal(\"")
	if legacy >= 0:
		var start: int = legacy + "emit_signal(\"".length()
		var end: int = stripped.find("\"", start)
		if end > start:
			found.append(stripped.substr(start, end - start))
	var modern: int = stripped.find(".emit(")
	while modern >= 0:
		var identifier: String = _trailing_identifier(stripped.substr(0, modern))
		if not identifier.is_empty() and not Array(found).has(identifier):
			found.append(identifier)
		modern = stripped.find(".emit(", modern + 1)
	return found


## The identifier a text ENDS with, "" when it ends with anything else. `player.died` answers `died`,
## because the signal is the last hop of the chain and the object is everything before it.
static func _trailing_identifier(text: String) -> String:
	var index: int = text.length() - 1
	var collected: String = ""
	while index >= 0:
		var character: String = text[index]
		var is_word: bool = character == "_" \
			or (character >= "a" and character <= "z") \
			or (character >= "A" and character <= "Z") \
			or (character >= "0" and character <= "9")
		if not is_word:
			break
		collected = character + collected
		index -= 1
	return collected if EventSheetViewportLenses.is_identifier(collected) else ""


## The object one script drives, by the same rule the Include bar names it (Q4): the scene root that
## uses it, else the file name in the shape a reader writes it.
static func object_label_of_script(script_path: String) -> String:
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(script_path)
	var root_name: String = str(scene.get("root_name", ""))
	if not root_name.is_empty():
		return root_name
	return script_path.get_file().get_basename().to_pascal_case()


static func _record(into: Dictionary, signal_name: String, entry: Dictionary) -> void:
	var key: String = _key(signal_name)
	if key.is_empty():
		return
	if not into.has(key):
		into[key] = []
	(into[key] as Array).append(entry)


static func _attribute(line: String, key: String) -> String:
	var marker: String = "%s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""
