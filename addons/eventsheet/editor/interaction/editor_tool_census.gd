@tool
class_name EventSheetEditorToolCensus
extends RefCounted

# What a sheet or a pack ADDS TO THE EDITOR, derived rather than declared.
#
# A pack can carry a @tool script that hangs a dock, adds a Tools menu item or teaches the editor a
# new object type, and until now nothing anywhere said so: you installed the pack and found out by
# looking. This file is the one answer, and every surface that shows it (the Anatomy rail's EDITOR
# TOOLS section, a pack's Include bar, the picker's pack card) reads it from here.
#
# It is DERIVED on purpose, in the same spirit as the rest of the pack metadata: nothing to declare,
# nothing to keep in step, and a pack that stops adding a dock stops saying it does the moment it is
# rebuilt. Two doors, because the two callers have two different things in hand:
#   - `from_sheet` walks an opened sheet's rows, so an authored plugin sheet answers while it is
#     being written and the labels can name the actual title / type the row carries;
#   - `from_source` reads emitted GDScript, so an INSTALLED pack answers without being opened - the
#     text test is the plain engine call the action compiles to, which is the only thing that
#     survives to disk.
#
# Both return the same shape: `[{kind, label}]` in a fixed order (menu items, docks, object types,
# Inspector plugins), so the rail, the bar and the card list the same things in the same order.

## The four capabilities, in reading order. `ace_id` is what an authored row carries, `call` the
## engine method the action compiles to (the text `from_source` looks for), `noun` the singular word
## the summary counts in, and `label` the fallback when nothing better can be named.
const CAPABILITIES: Array[Dictionary] = [
	{"kind": "menu_item", "ace_id": "AddToolsMenuItem", "call": "add_tool_menu_item(", "noun": "Tools menu item", "label": "Tools menu item", "name_param": "title"},
	{"kind": "dock", "ace_id": "AddEditorDock", "call": "add_control_to_dock(", "noun": "dock", "label": "dock", "name_param": "control"},
	# The bottom row of panels, added by the same pair of verbs as a dock. Without this entry a
	# Bottom panel sheet claimed nothing on its own Include bar while a Dock panel sheet claimed one.
	{"kind": "bottom_panel", "ace_id": "AddBottomPanel", "call": "add_control_to_bottom_panel(", "noun": "bottom panel", "label": "bottom panel", "name_param": "title"},
	{"kind": "object_type", "ace_id": "AddEditorObjectType", "call": "add_custom_type(", "noun": "object type", "label": "object type", "name_param": "type_name"},
	{"kind": "inspector", "ace_id": "AddEditorInspectorPlugin", "call": "add_inspector_plugin(", "noun": "Inspector button", "label": "Inspector button", "name_param": ""},
]


## Everything an authored sheet adds to the editor, as [{kind, label}]. Walks groups too, because a
## plugin that adds three docks legitimately files them under one group.
static func from_sheet(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	for capability: Dictionary in CAPABILITIES:
		_collect_rows(sheet.events, capability, found)
	return found


static func _collect_rows(rows: Array, capability: Dictionary, found: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_rows(group.events if not group.events.is_empty() else group.rows, capability, found)
			continue
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for action: Variant in event.actions:
			if not (action is ACEAction) or (action as ACEAction).ace_id != str(capability["ace_id"]):
				continue
			var named: String = _readable_name(str((action as ACEAction).params.get(str(capability["name_param"]), "")))
			found.append({"kind": str(capability["kind"]), "label": _label_for(capability, named)})


## Everything a COMPILED script adds to the editor, read off its text. Used for installed packs,
## which are emitted GDScript on disk and never opened. Counting the plain engine call is the whole
## test - that call IS the capability, whichever route in the editor wrote it.
static func from_source(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for capability: Dictionary in CAPABILITIES:
		var call_text: String = str(capability["call"])
		var search_from: int = source.find(call_text)
		while search_from >= 0:
			found.append({"kind": str(capability["kind"]),
				"label": _label_for(capability, _first_string_argument(source, search_from + call_text.length()))})
			search_from = source.find(call_text, search_from + call_text.length())
	return found


## The census of a whole pack directory under res://eventsheet_addons/, read off its scripts.
##
## Remembered per pack for the session: the picker asks this once per provider card as it fills the
## Objects tree, and answering means reading every .gd of that pack end to end. Dropped when the
## project's files change, like the other reads-of-files caches in this folder.
static func from_pack(pack_dir: String) -> Array[Dictionary]:
	var key: String = pack_dir.strip_edges()
	if _pack_cache.has(key):
		return (_pack_cache[key] as Array[Dictionary]).duplicate(true)
	var found: Array[Dictionary] = []
	var directory: String = "res://eventsheet_addons".path_join(key)
	var dir: DirAccess = DirAccess.open(directory)
	if key.is_empty() or dir == null:
		# Remembered like any other answer. A provider with no pack folder of its own - Core, and
		# every runtime-registered one - is asked this once per card of the object page, and every
		# one of those asks was opening a directory to find out there was nothing there.
		_pack_cache[key] = found
		return found.duplicate(true)
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.get_extension() == "gd":
			found.append_array(from_source(FileAccess.get_file_as_string(directory.path_join(file_name))))
	_pack_cache[key] = found
	return found.duplicate(true)


## Every installed pack's folder name, sorted. The census's own idea of where packs live, so a
## caller that wants to read them all - the picker's idle warm - does not have to keep a second
## one. Empty when the packs folder is not there.
static func pack_directories() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open("res://eventsheet_addons")
	if dir == null:
		return names
	for entry: String in dir.get_directories():
		if not entry.begins_with("."):
			names.append(entry)
	names.sort()
	return names


## Drops the remembered per-pack censuses. The editor calls this when the filesystem changes.
static func clear_cache() -> void:
	_pack_cache.clear()


static var _pack_cache: Dictionary = {}


## The Include-bar line: `adds 1 Tools menu item, 1 dock`, counted per kind in CAPABILITIES order.
## "" when the sheet or pack adds nothing, so the bar says nothing rather than saying "adds 0".
static func summary(entries: Array[Dictionary]) -> String:
	if entries.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for capability: Dictionary in CAPABILITIES:
		var count: int = 0
		for entry: Dictionary in entries:
			if str(entry.get("kind", "")) == str(capability["kind"]):
				count += 1
		if count == 0:
			continue
		var noun: String = EventSheetL10n.translate(str(capability["noun"]))
		parts.append("%d %s" % [count, noun if count == 1 else _plural(noun)])
	return "%s %s" % [EventSheetL10n.translate("adds"), ", ".join(parts)]


## The rail's own line for one entry: the label in the rail's own words.
static func labels(entries: Array[Dictionary]) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		texts.append(str(entry.get("label", "")))
	return texts


## `Tools menu ▸ Snap Selection` when the row named something, `Tools menu item` when it did not.
## Docks and object types read as `dock: Waypoints` / `object type: Waypoint`, which is the way the
## editor itself would describe them in the Scene dock and the Create Node dialog.
static func _label_for(capability: Dictionary, named: String) -> String:
	if named.is_empty():
		return EventSheetL10n.translate(str(capability["label"]))
	match str(capability["kind"]):
		"menu_item":
			return "%s ▸ %s" % [EventSheetL10n.translate("Tools menu"), named]
		"dock":
			return "%s: %s" % [EventSheetL10n.translate("dock"), named]
		"bottom_panel":
			return "%s: %s" % [EventSheetL10n.translate("bottom panel"), named]
		"object_type":
			return "%s: %s" % [EventSheetL10n.translate("object type"), named]
	return EventSheetL10n.translate(str(capability["label"]))


## The name inside a parameter, when the parameter IS a name: a quoted literal unquoted, or a bare
## identifier as it stands. An expression (`Control.new()`, a call, anything with punctuation) names
## nothing a reader would recognise, so it yields "" and the entry falls back to its plain label.
static func _readable_name(param_text: String) -> String:
	var text: String = param_text.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	if text.is_valid_identifier():
		return text
	return ""


## The first argument at `from_index`, when it is a plain quoted string. Text-level and deliberately
## unambitious: a call whose first argument is an expression names nothing, which is exactly what an
## unnamed entry should say.
static func _first_string_argument(source: String, from_index: int) -> String:
	var quote_at: int = source.find("\"", from_index)
	var comma_at: int = source.find(",", from_index)
	var close_at: int = source.find(")", from_index)
	if quote_at < 0:
		return ""
	# The quote has to be INSIDE this argument - past a comma or the closing bracket it belongs to
	# something else entirely.
	if comma_at >= 0 and quote_at > comma_at:
		return ""
	if close_at >= 0 and quote_at > close_at:
		return ""
	var end_quote: int = source.find("\"", quote_at + 1)
	if end_quote < 0:
		return ""
	return source.substr(quote_at + 1, end_quote - quote_at - 1)


## English pluralisation good enough for the four nouns this file counts. Kept private and small on
## purpose: a general pluraliser would be a translation problem, and these four are shipped words.
static func _plural(noun: String) -> String:
	if noun.ends_with("s") or noun.ends_with("x"):
		return noun + "es"
	return noun + "s"
