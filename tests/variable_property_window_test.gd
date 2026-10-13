# Godot EventSheets - the variable property window: every GDScript type, every Inspector look as a
# described dropdown with its details, where the variable sits in the Inspector, and the code each
# choice writes.
#
# The claims are pinned as the VALUES the window hands on, not as what it draws: which looks a type
# offers, the annotation a look and its details compile to, that a variable reopens on the look it was
# saved with (fold and unfold are inverses), that what the window has no field for rides through a
# save, and that values written as code (a StringName, an enum member, a function) reach the file as
# code on both of the sheet's stores.
@tool
class_name VariablePropertyWindowTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "variable_property_window_test"


static func run() -> bool:
	var host: Node = Node.new()
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> Variant: return null)
	var ok: bool = _looks_per_type(dialog)
	ok = _looks_compile(dialog) and ok
	ok = _sections(dialog) and ok
	ok = _values_as_code(dialog) and ok
	host.free()
	ok = _fold_and_unfold_are_inverses() and ok
	ok = _stores_write_code_values() and ok
	ok = _tree_rows_keep_what_the_window_sends() and ok
	ok = _tables_are_translated() and ok
	ok = _window_speaks_the_editor_language() and ok
	return ok


static func _looks_per_type(dialog: VariableDialog) -> bool:
	var rows: Array = []
	for expected: Array in [
		["int", ["", "slider", "no_handle", "progress_bar", "number_choices", "flags", "layers", "custom", "storage"]],
		["float", ["", "slider", "angle", "exp_slider", "no_handle", "progress_bar", "easing", "unit", "custom", "storage"]],
		["String", ["", "file", "folder", "multiline", "placeholder", "choices", "suggestions", "toggle_row", "password",
			"expression", "custom", "storage"]],
		["Vector3", ["", "link", "custom", "storage"]],
		["Callable", ["", "tool_button", "custom", "storage"]],
	]:
		dialog.open_for_edit("global", {}, "value", str(expected[0]), "", false, "Add", false, true)
		rows.append(["%s offers its looks" % expected[0], _look_ids(dialog), expected[1]])
		rows.append(["every %s look says what it shows and writes" % expected[0], _bare_looks(dialog), []])
	dialog.open_for_edit("global", {}, "hit", "Signal", "", false, "Add", false, true)
	rows.append(["a Signal cannot be an Inspector property", [dialog._exported_check.disabled, dialog._exported_check.button_pressed], [true, false]])
	return SUPPORT.pins(P, rows)


static func _looks_compile(dialog: VariableDialog) -> bool:
	var rows: Array = []
	dialog.open_for_edit("global", {}, "bullet_speed", "float", "10.0", false, "Add", false, true)
	_pick_look(dialog, "slider", {"min": "0", "max": "40", "step": "0.5", "unit": "tiles/s"})
	rows.append(["a slider with a unit", dialog.code_line_text(), "@export_range(0, 40, 0.5, \"suffix:tiles/s\") var bullet_speed: float = 10.0"])
	_pick_look(dialog, "angle", {"min": "0", "max": "360", "step": "0.1"})
	rows.append(["an angle in degrees", dialog.code_line_text(), "@export_range(0, 360, 0.1, \"radians_as_degrees\") var bullet_speed: float = 10.0"])
	_pick_look(dialog, "easing", {"curve": "both"})
	rows.append(["both easing flags at once", dialog.code_line_text(), "@export_exp_easing(\"attenuation\", \"positive_only\") var bullet_speed: float = 10.0"])
	dialog.open_for_edit("global", {}, "bullet_mask", "int", "1", false, "Add", false, true)
	_pick_look(dialog, "layers", {"layers": "3d_render"})
	rows.append(["a layers grid", dialog.code_line_text(), "@export_flags_3d_render var bullet_mask: int = 1"])
	dialog.open_for_edit("global", {}, "bullet_sprite", "String", "res://art/bullet.png", false, "Add", false, true)
	_pick_look(dialog, "file", {"filters": "*.png, *.webp", "reach": "anywhere on disk"})
	rows.append(["a file picker reaching the whole disk", dialog.code_line_text(),
		"@export_global_file(\"*.png\", \"*.webp\") var bullet_sprite: String = \"res://art/bullet.png\""])
	_pick_look(dialog, "custom", {"hint": "PROPERTY_HINT_MULTILINE_TEXT", "text": "", "usage": "PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY"})
	rows.append(["your own hint", dialog.code_line_text(),
		"@export_custom(PROPERTY_HINT_MULTILINE_TEXT, \"\", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var bullet_sprite: String = \"res://art/bullet.png\""])
	_pick_look(dialog, "choices", {"choices": "Round, Laser"})
	dialog._default_edit.text = ""
	var confirmed: Dictionary = _confirm(dialog)
	rows.append(["a dropdown's choices are the variable's options", Array(confirmed.get("options", PackedStringArray())), ["Round", "Laser"]])
	rows.append(["…and an empty value starts on the first", confirmed.get("default"), "Round"])
	return SUPPORT.pins(P, rows)


static func _sections(dialog: VariableDialog) -> bool:
	var rows: Array = []
	dialog.open_for_edit("global", {"attributes": {"tooltip": "Tiles per second", "doc_after_group": true}}, "bullet_speed",
		"float", "10.0", false, "Add", false, true)
	dialog._category_edit.text = "Weapon"
	dialog._group_edit.text = "Bullet"
	dialog._prefix_check.button_pressed = true
	rows.append(["the prefix offered is the start the names share", dialog._prefix_edit.text, "bullet"])
	rows.append(["the code it writes carries the sections", dialog._help_strip.in_code_value.text,
		"@export_category(\"Weapon\")\n@export_group(\"Bullet\", \"bullet\")\n## Tiles per second\n@export var bullet_speed: float = 10.0"])
	rows.append(["a name that starts with the prefix is inside", dialog._prefix_note.visible, false])
	dialog._name_edit.text = "health"
	dialog._refresh_reading()
	rows.append(["a name that does not is said to be outside", dialog._prefix_note.text,
		"health does not start with bullet, so Godot leaves it outside Bullet. Rename it, or turn off the prefix."])
	var confirmed: Dictionary = _confirm(dialog)
	rows.append(["what the window has no field for rides through a save",
		(confirmed.get("attributes", {}) as Dictionary).get("doc_after_group"), true])
	rows.append(["the sections are written as attributes", [(confirmed.get("attributes", {}) as Dictionary).get("category"),
		(confirmed.get("attributes", {}) as Dictionary).get("group_prefix")], ["Weapon", "bullet"]])
	# Opened with a subgroup prefix and a group end, then the subgroup cleared and a group given: the
	# two keys no field shows no longer mean anything, so they leave with the save.
	dialog.open_for_edit("global", {"attributes": {"subgroup": "Trail", "subgroup_prefix": "trail", "group_end": true,
		"doc_after_group": true}}, "trail_length", "float", "1.0", false, "Add", false, true)
	dialog._subgroup_edit.text = ""
	dialog._group_edit.text = "Bullet"
	var kept: Dictionary = _confirm(dialog).get("attributes", {})
	rows.append(["a cleared subgroup takes its prefix with it, a group drops the end above it",
		[kept.has("subgroup_prefix"), kept.has("group_end"), kept.get("doc_after_group")], [false, false, true]])
	dialog.open_for_edit("global", {"attributes": {"subgroup": "Trail", "subgroup_prefix": "trail", "group_end": true}},
		"trail_length", "float", "1.0", false, "Add", false, true)
	kept = _confirm(dialog).get("attributes", {})
	rows.append(["...while they still mean something they ride through",
		[kept.get("subgroup_prefix"), kept.get("group_end")], ["trail", true]])
	return SUPPORT.pins(P, rows)


static func _values_as_code(dialog: VariableDialog) -> bool:
	var rows: Array = []
	dialog.open_for_edit("tree", {}, "bullet_anim", "StringName", "&\"fly\"", false, "Add", false, true)
	rows.append(["a StringName shows its words without the quotes", dialog._default_edit.text, "fly"])
	var confirmed: Dictionary = _confirm(dialog)
	rows.append(["…and is written back as code", [confirmed.get("default"), (confirmed.get("context", {}) as Dictionary).get("value_is_code")],
		["&\"fly\"", true]])
	dialog.open_for_edit("tree", {}, "bullet_offset", "Vector3", "Vector3(0.0, 1.0, 0.0)", false, "Add", false, true)
	var axes: Array = dialog._axis_box.get_children().filter(func(child: Node) -> bool: return child is LineEdit)
	rows.append(["a Vector3 is edited one axis at a time", axes.map(func(edit: LineEdit) -> String: return edit.text), ["0.0", "1.0", "0.0"]])
	(axes[2] as LineEdit).text = "2"
	(axes[2] as LineEdit).text_changed.emit("2")
	rows.append(["…composing back to the constructor", dialog._default_edit.text, "Vector3(0.0, 1.0, 2)"])
	dialog.open_for_edit("tree", {}, "bake_button", "Callable", "_bake", false, "Add", false, true)
	_pick_look(dialog, "tool_button", {"label": "Bake", "icon": "Bake"})
	rows.append(["an Inspector button", dialog.code_line_text(), "@export_tool_button(\"Bake\", \"Bake\") var bake_button = _bake"])
	dialog.set_enum_provider(func() -> Array: return [{"name": "Kind", "members": ["ROUND", "LASER = 4"]}])
	dialog.open_for_edit("tree", {}, "bullet_kind", "Kind", "Kind.ROUND", false, "Add", false, true)
	rows.append(["a sheet enum offers its members as the value", Array(dialog._value_suggestions()), ["Kind.ROUND", "Kind.LASER"]])
	confirmed = _confirm(dialog)
	rows.append(["…and the member is written as code", [confirmed.get("type"), confirmed.get("default"),
		(confirmed.get("context", {}) as Dictionary).get("value_is_code")], ["Kind", "Kind.ROUND", true]])
	dialog.set_enum_provider(Callable())
	dialog.open_for_edit("tree", {}, "muzzle", "Marker2D", null, false, "Add", false, true)
	confirmed = _confirm(dialog)
	rows.append(["an empty node slot starts at nothing", [confirmed.get("type"), confirmed.get("default")], ["Marker2D", null]])
	return SUPPORT.pins(P, rows)


## fold(unfold(attributes)) gives the attributes back for every look a file can open with, so a
## variable reopened and saved untouched writes the line it was read from.
static func _fold_and_unfold_are_inverses() -> bool:
	var rows: Array = []
	for sample: Array in [
		["float", {"range": {"min": "0", "max": "40", "step": "0.5", "suffix": "px", "or_greater": true}}],
		["float", {"range": {"min": "0", "max": "6.28", "step": "0.01", "angle": "degrees"}}],
		["float", {"range": {"min": "0.01", "max": "100", "step": "0.01", "exp": true}}],
		["int", {"flags": [{"label": "Fire", "value": ""}, {"label": "Ice", "value": "4"}]}],
		["int", {"enum_values": [{"label": "Slow", "value": "30"}]}],
		["int", {"layers": "avoidance"}],
		["float", {"exp_easing": true}],
		["String", {"file": {"mode": "file", "global": false, "filters": ["*.ogg"], "plain_path": true}}],
		["String", {"file": {"mode": "dir", "global": true}}],
		["String", {"custom_hint": {"hint": "PROPERTY_HINT_RANGE", "text": "0,10", "usage": ""}}],
		["Callable", {"tool_button": {"args": "\"Bake\",\"Bake\"", "label": "Bake"}}],
		["Vector2", {"drawer": "min_max", "range": {"min": "0", "max": "10", "step": "1"}}],
		["float", {"drawer": "unit", "unit_kinds": ["s", "ms"], "unit_store": "s"}],
		["String", {"suggestions": ["sword", "bow"]}],
		["Color", {"no_alpha": true}],
		["int", {"storage": true}],
	]:
		var unfolded: Array = EventSheetInspectorLooks.unfold(sample[1])
		rows.append(["%s reopens on %s" % [JSON.stringify(sample[1]), unfolded[0]],
			EventSheetInspectorLooks.fold(str(unfolded[0]), unfolded[1], str(sample[0])), sample[1]])
	return SUPPORT.pins(P, rows)


## A value the window takes as code is written as it stands on the sheet's dictionary too, and an
## Inspector button compiles there as it does on a row.
static func _stores_write_code_values() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"state": {"type": "State", "default": "State.IDLE", "expression": true, "exported": true},
		"bake": {"type": "Callable", "default": "_bake", "expression": true, "exported": true,
			"attributes": {"tool_button": {"args": "\"Bake\"", "label": "Bake"}}},
	}
	var output: String = SUPPORT.compile_output(sheet, "user://eventsheets_property_window.gd")
	return SUPPORT.pins(P, [
		["an enum member is written as code", output.contains("@export var state: State = State.IDLE\n"), true],
		["an Inspector button compiles from the dictionary", output.contains("@export_tool_button(\"Bake\") var bake = _bake\n"), true],
	])


## Editing a row the file opened: the look the window sends is kept (it used to be thrown away for
## everything but sections), a Big text box compiles from the row, and "Write the type in code" on
## an untyped line writes the type.
static func _tree_rows_keep_what_the_window_sends() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(SUPPORT.reopen("extends Node\n\n@export var damage = 3\n@export_multiline var lines: String = \"\"\n"))
	var damage: LocalVariable = _row(dock, "damage")
	dock._variables._on_variable_dialog_confirmed("damage", "int", 3, "tree", {"editing": true, "variable_resource": damage,
		"write_type": true, "default_text": "3"}, false, true, PackedStringArray(), {"range": {"min": "0", "max": "10", "step": "1"}})
	var output: String = SUPPORT.compile_output(dock._current_sheet, "user://eventsheets_property_window_rows.gd")
	var rows: Array = [["the look and the written type reach the line", output.contains("@export_range(0, 10, 1) var damage: int = 3\n"), true]]
	var lines_row: LocalVariable = _row(dock, "lines")
	var host: Node = Node.new()
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.open_for_edit("tree", {"editing": true, "export_hint": lines_row.export_hint}, "lines", "String", "", false, "Edit", false, true)
	rows.append(["a Big text box the file wrote opens on its look", dialog._selected_look_id(), "multiline"])
	rows.append(["…and writes the same line", dialog.code_line_text(), "@export_multiline var lines: String = \"\""])
	host.free()
	dock.free()
	return SUPPORT.pins(P, rows)


static func _row(dock: EventSheetDock, row_name: String) -> LocalVariable:
	for entry: Variant in dock._current_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == row_name:
			return entry
	return null


static func _pick_look(dialog: VariableDialog, look_id: String, values: Dictionary) -> void:
	for key: Variant in values:
		dialog._look_values["%s|%s" % [look_id, key]] = values[key]
	dialog._select_look(look_id)
	dialog._rebuild_look_details()
	dialog._refresh_reading()


static func _confirm(dialog: VariableDialog) -> Dictionary:
	var seen: Dictionary = {}
	var listener: Callable = func(_n: String, type_name: String, default_value: Variant, _s: String, context: Dictionary, _c: bool,
			_e: bool, options: PackedStringArray, attributes: Dictionary, _r: bool, _st: bool) -> void:
		seen.merge({"type": type_name, "default": default_value, "context": context, "options": options, "attributes": attributes})
	dialog.variable_confirmed.connect(listener)
	dialog._on_confirmed()
	dialog.variable_confirmed.disconnect(listener)
	return seen


static func _look_ids(dialog: VariableDialog) -> Array:
	var ids: Array = []
	for index: int in range(dialog._look_option.item_count):
		ids.append(str(dialog._look_option.get_item_metadata(index)))
	return ids


static func _bare_looks(dialog: VariableDialog) -> Array:
	var bare: Array = []
	for index: int in range(dialog._look_option.item_count):
		if not dialog._look_option.get_item_tooltip(index).contains("\nWrites "):
			bare.append(dialog._look_option.get_item_text(index))
	return bare


## The window's tables stay English - each word is the key its translation is filed under - and are
## translated as they are shown, so the harvest (which reads only literal arguments) never sees them.
## This is the gate it cannot be: every word a table shows has a row in every bundled language.
static func _tables_are_translated() -> bool:
	var words: PackedStringArray = PackedStringArray()
	for entry: Array in VariableDialog.TYPES:
		words.append_array([str(entry[0]), str(entry[2]), str(entry[3])])
	for field: Variant in VariableDialog.FIELD_HELP:
		words.append_array([str(field), str(VariableDialog.FIELD_HELP[field])])
	for scope: Variant in VariableDialog.SCOPE_FACTS:
		words.append_array([str(VariableDialog.SCOPE_FACTS[scope]["short"]), str(VariableDialog.SCOPE_FACTS[scope]["long"])])
	for look: Dictionary in EventSheetInspectorLooks.LOOKS:
		words.append_array([str(look["label"]), str(look["tip"])])
		for field: Array in look.get("fields", []):
			words.append(str(field[1]))
			if str(field[2]) == "tick":
				words.append(str(field[4]))
	words.append_array(PackedStringArray(EventSheetInspectorLooks.PLAIN_LABELS.values()))
	words.append_array(PackedStringArray(EventSheetInspectorLooks.REACH))
	var missing: Array = []
	for locale: String in ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]:
		var cells: Dictionary = _csv_cells("res://addons/eventsheet/translations/%s.csv" % locale)
		for word: String in words:
			if str(cells.get(word, "")).strip_edges().is_empty():
				missing.append("%s: %s" % [locale, word])
	return SUPPORT.check(P, "every word the window's tables show is translated in all eight languages", missing, [])


## In German the window reads German: the look list, a look's hover, the type list and a field's help.
static func _window_speaks_the_editor_language() -> bool:
	var before: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("de")
	var host: Node = Node.new()
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> Variant: return null)
	dialog.open_for_edit("global", {}, "speed", "float", "1.0", false, "Add", false, true)
	var rows: Array = [
		["the plain look", dialog._look_option.get_item_text(0), "Einfache Zahl"],
		["a look's name", EventSheetInspectorLooks.label(EventSheetInspectorLooks.by_id("slider")), "Schieberegler"],
		["a look's hover, the annotation kept as code", EventSheetInspectorLooks.description(EventSheetInspectorLooks.by_id("angle")),
			"Ein Winkel: in Radiant gespeichert, in Grad angezeigt und eingegeben.
Schreibt @export_range(0, 360, 0.1, \"radians_as_degrees\")"],
		["the type, kept as code beside its words", dialog._type_option.get_item_text(dialog._type_option.selected), "float · Zahl mit Nachkommastellen"],
		["a field's help", VariableDialog.field_help("Subgroup"), "Ein Ordner innerhalb der Gruppe (@export_subgroup)."],
		["the window's own words", [dialog._dialog.title, dialog._changes_fold.title], ["Variable hinzufügen", "Wenn sie sich ändert"]],
	]
	host.free()
	EventSheetL10n.set_locale(before)
	return SUPPORT.pins(P, rows)


static func _csv_cells(path: String) -> Dictionary:
	var cells: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1:
			cells[row[0]] = row[1]
	return cells
