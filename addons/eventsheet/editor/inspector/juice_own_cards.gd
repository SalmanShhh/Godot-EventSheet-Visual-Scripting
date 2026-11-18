# Godot EventSheets - the juice cards a project writes for itself (editor-only, loaded by path).
#
# A card of your own is a script that extends JuiceCard. This file is what lets the Inspector treat it as
# a card like any other:
#
#   `kinds`      the project's own cards, read from Godot's list of the project's classes, so a card appears in
#                the Add box under "Yours" the moment its script has a class_name and goes when the file does.
#   `entry_for`  the kind entry of a SAVED card, found by the address of its script before any word, so a
#                card whose class was renamed is still the card it was.
#   `field`      the editor for one export, which is Godot's own editor for that kind of value: the colour box,
#                the range slider with its suffix, the file picker.
#
# The values a card holds are kept as keys named after its exports, in the same dictionary every other card
# is. Nothing here writes a file and nothing here adds a node to a scene.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no business there.
@tool
extends RefCounted

## The class every card of your own extends.
const BASE_CLASS: String = "JuiceCard"

## The family a card of your own belongs to. It is a word like the other families, so a row can mute it.
const FAMILY: String = "yours"

## The most bases a chain of classes is followed through, so a loop in a broken project ends.
const MOST_BASES: int = 32

## What the project's own cards were the last time they were read. They are read once and kept until the project's
## script files change (see `_watch`): a card edit never reads the project, however big the project is.
static var _kinds_cache: Array = []
static var _valid: bool = false
## Whether the editor's file-system signals are being listened to.
static var _watching: bool = false
## How many times the project's classes have been read, and how many card scripts those reads opened. A bounded-work
## pin reads them before and after an edit and wants no change.
static var scans: int = 0
static var files_read: int = 0


## Forgets what was read, so the next ask reads the project's classes again.
static func reset() -> void:
	_kinds_cache = []
	_valid = false


## Listens (once) to the editor's file system: a script added, removed or saved, or a change to the project's class
## list, is the only thing that can change what the project's own cards are, so that is when what was read is dropped.
static func _watch() -> void:
	if _watching or not Engine.is_editor_hint():
		return
	var files: EditorFileSystem = EditorInterface.get_resource_filesystem() if EditorInterface != null else null
	if files == null:
		return
	_watching = true
	var forget: Callable = Callable(load("res://addons/eventsheet/editor/inspector/juice_own_cards.gd"), "reset")
	files.script_classes_updated.connect(forget)
	files.filesystem_changed.connect(forget)


## The kind entries of every class of the project that extends JuiceCard, in the order their files sort.
static func kinds() -> Array:
	if _valid:
		return _kinds_cache
	_watch()
	scans += 1
	_valid = true
	_kinds_cache = []
	var found: Array = []
	var bases: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		bases[str(entry.get("class", ""))] = str(entry.get("base", ""))
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var named: String = str(entry.get("class", ""))
		if named != BASE_CLASS and _reaches_base(named, bases):
			found.append(entry)
	found.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.get("path", "")) < str(second.get("path", "")))
	for entry: Dictionary in found:
		_kinds_cache.append(_entry_of(str(entry.get("class", "")), str(entry.get("path", ""))))
	return _kinds_cache


## Whether a class's chain of bases reaches JuiceCard.
static func _reaches_base(class_name_text: String, bases: Dictionary) -> bool:
	var walk: String = class_name_text
	for step: int in range(MOST_BASES):
		if not bases.has(walk):
			return false
		walk = str(bases[walk])
		if walk == BASE_CLASS:
			return true
	return false


## The kind entry of a saved card of your own, found by the address of its script first and by its class
## name second. An empty entry when the project has no such card, which draws the card with the values it
## holds, as every unknown kind is drawn.
static func entry_for(card: Dictionary) -> Dictionary:
	var address: String = str(card.get("card_script", ""))
	if address.is_empty():
		return {}
	var wanted: String = _path_of(address)
	for entry: Variant in kinds():
		var own: Dictionary = entry as Dictionary
		if str(own.get("script_path", "")) == wanted and not wanted.is_empty():
			return own
	for entry: Variant in kinds():
		if str((entry as Dictionary).get("kind", "")) == str(card.get("verb", "")):
			return entry as Dictionary
	return {}


## The file a uid or a path names, or empty when it names nothing.
static func _path_of(address: String) -> String:
	if address.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(address)
		return ResourceUID.get_id_path(id) if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id) else ""
	return address


## The address a card keeps for a script: its uid when it has one, so moving the file is safe.
static func address_of(path: String) -> String:
	var id: int = ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else path


## One card's kind entry, read from its script.
static func _entry_of(class_name_text: String, path: String) -> Dictionary:
	files_read += 1
	var script: Script = load(path) as Script
	var fields: Array = []
	var defaults: Dictionary = {"card_script": address_of(path)}
	var tips: Dictionary = _tooltips_of(path)
	var seen_seconds: bool = false
	if script != null:
		for property: Dictionary in script.get_script_property_list():
			var export_name: String = str(property.get("name", ""))
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) or not (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) or export_name == "script":
				continue
			var kind_of_value: int = int(property.get("type", TYPE_NIL))
			var default_value: Variant = script.get_property_default_value(export_name)
			var field: Dictionary = {"key": export_name, "label": export_name, "tooltip": str(tips.get(export_name, ""))}
			if kind_of_value == TYPE_NODE_PATH:
				field["drawer"] = "node"
				field["types"] = ["Node"]
				field["empty"] = ""
			else:
				field["drawer"] = "godot"
				field["spec"] = {"type": kind_of_value, "hint": int(property.get("hint", 0)), "hint_string": str(property.get("hint_string", "")), "usage": int(property.get("usage", 0))}
			if default_value != null and kind_of_value != TYPE_OBJECT and kind_of_value != TYPE_NODE_PATH:
				field["default"] = default_value
				defaults[export_name] = default_value
			fields.append(field)
			seen_seconds = seen_seconds or export_name == "seconds"
	return {
		"kind": class_name_text,
		"category": FAMILY,
		"label": label_of(class_name_text),
		"help": _help_of(path),
		"fields": fields,
		"live": [],
		"defaults": defaults,
		"search": PackedStringArray([class_name_text, "yours", "own", "custom"]),
		"script_path": path,
		"badge": EventSheetFeedbackCardSchema.seconds_badge
	}


## What a class is called in the Add box: "ScreenFlashCard" reads "Screen Flash", the way Godot reads a
## class name as words, with a closing Card dropped.
static func label_of(class_name_text: String) -> String:
	var words: String = class_name_text.capitalize()
	if words.ends_with(" Card") and words.length() > 5:
		words = words.trim_suffix(" Card")
	return words


## The `##` lines that describe the class: the first run of them after the class_name and extends lines, or
## the run above class_name, whichever the author wrote. Empty when there is none.
static func _help_of(path: String) -> String:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var run: PackedStringArray = PackedStringArray()
	var header_seen: bool = false
	for index: int in range(lines.size()):
		var trimmed: String = lines[index].strip_edges()
		if trimmed.begins_with("##"):
			run.append(trimmed.trim_prefix("##").strip_edges())
			continue
		if not run.is_empty():
			# A run that sits directly on a member is that member's tooltip, not the class's.
			if trimmed.begins_with("@export") or trimmed.begins_with("var ") or trimmed.begins_with("func "):
				run = PackedStringArray()
			elif header_seen or trimmed.begins_with("class_name") or trimmed.begins_with("extends"):
				return " ".join(run)
			else:
				run = PackedStringArray()
		if trimmed.begins_with("class_name") or trimmed.begins_with("extends"):
			header_seen = true
	return ""


## The tooltip of each export: the `##` lines directly above its `@export` line.
static func _tooltips_of(path: String) -> Dictionary:
	var tips: Dictionary = {}
	var run: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("##"):
			run.append(trimmed.trim_prefix("##").strip_edges())
		elif trimmed.begins_with("@export"):
			var named: String = trimmed.get_slice(" var ", 1).get_slice(":", 0).get_slice("=", 0).strip_edges() if trimmed.contains(" var ") else ""
			if not named.is_empty() and not run.is_empty():
				tips[named] = " ".join(run)
			run = PackedStringArray()
		else:
			run = PackedStringArray()
	return tips


## The editor for one export of a card of your own: Godot's own editor for its type, wired to the card.
## `write` stores the new value on the card; a resource is stored as the text of its file (a uid), the way
## every other file on a card is kept.
static func field(owner: Control, card: Dictionary, field_dict: Dictionary, write: Callable) -> Control:
	var key: String = str(field_dict.get("key", ""))
	var spec: Dictionary = field_dict.get("spec") if field_dict.get("spec") is Dictionary else {}
	var proxy: CardValues = CardValues.new()
	proxy.kind_of_value = int(spec.get("type", TYPE_NIL))
	proxy.listed = [{"name": key, "type": proxy.kind_of_value, "hint": int(spec.get("hint", 0)),
		"hint_string": str(spec.get("hint_string", "")), "usage": int(spec.get("usage", 0))}]
	proxy.values[key] = card.get(key, field_dict.get("default"))
	var editor: EditorProperty = EditorInspector.instantiate_property_editor(proxy, proxy.kind_of_value, key,
		int(spec.get("hint", 0)), str(spec.get("hint_string", "")), int(spec.get("usage", 0)), false)
	if editor == null:
		proxy.free()
		var unsupported: Label = Label.new()
		unsupported.text = EventSheetL10n.translate("Edit this value in the card's script.")
		unsupported.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		return unsupported
	editor.draw_label = false
	editor.use_folding = false
	editor.set_object_and_property(proxy, key)
	editor.property_changed.connect(func(property: StringName, value: Variant, _changed_field: StringName, _changing: bool) -> void:
		proxy.values[str(property)] = value
		write.call(stored_form(value))
		editor.update_property())
	editor.tooltip_text = str(field_dict.get("tooltip", ""))
	editor.tree_exited.connect(proxy.free)
	editor.update_property()
	return editor


## A value as a card keeps it: a resource as the text of its file, anything else as it is.
static func stored_form(value: Variant) -> Variant:
	if value is Resource:
		return EventSheetCardSchemas.resource_reference(value as Resource)
	return value


## The object Godot's editor edits in place of a card: it holds the values the card holds and answers for them
## by name, so the editor reads and writes a card as it would a resource.
class CardValues:
	extends Object

	var values: Dictionary = {}
	var kind_of_value: int = TYPE_NIL
	var listed: Array = []

	func _get(property: StringName) -> Variant:
		var held: Variant = values.get(str(property))
		if held is String and kind_of_value == TYPE_OBJECT:
			return load(held) if ResourceLoader.exists(held) else null
		return held

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func _get_property_list() -> Array:
		return listed
