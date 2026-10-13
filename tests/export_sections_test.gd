# EventForge - how an opened script's Inspector sections read on the sheet. A category is a band, a
# group a strip holding its run, a subgroup a strip inside its group, `@export_group("")` the line a
# group ends on; a prefix group takes only the names that start with its prefix, tints that start, and
# the member it shuts out says why in the help strip. A type the code does not write reads as inferred,
# and the Properties dialog offers to write it. Every reading leaves the file byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const ExportSections := preload("res://addons/eventsheet/editor/interaction/export_sections.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")

const SOURCE := "extends Node2D\n\n@export_category(\"Weapon\")\n@export_group(\"Gun\")\n## Hit points taken per shot\n@export var damage := 3\n@export var recoil := 5.0\n@export_group(\"\")\n@export_group(\"Bullet\", \"bullet\")\n@export var bullet_count := 3\n@export var bullet_speed := 10.0\n@export var health := 10\n@export_category(\"Movement\")\n@export_group(\"Movement\")\n@export_range(0, 600) var walk_speed: float = 220.0\n@export_subgroup(\"Jump\")\n@export_range(16, 256) var jump_height: float = 64.0\n@export_range(1, 3) var max_jumps: int = 2\nvar _cooldown: float = 0.0\n"


static func run() -> bool:
	var ok: bool = _test_the_inspector_rules()
	ok = _test_the_sheet_reading() and ok
	ok = _test_writing_the_type() and ok
	return ok


## The walk is the Inspector's own: a prefix shuts out the first name that does not fit, an empty
## name ends a section, a category ends both, and only whole section lines are read as sections.
static func _test_the_inspector_rules() -> bool:
	var walk: ExportSections = ExportSections.new()
	walk.enter(ExportSections.parse_line("@export_group(\"Bullet\", \"bullet\")"))
	var in_bullet: String = "%s/%s" % [walk.place("bullet_count").is_empty(), walk.group]
	var shut: Dictionary = walk.place("health")
	var after: String = "%s|%s" % [walk.group, walk.place("bullet_speed").is_empty()]
	walk.enter(ExportSections.parse_line("@export_group(\"Movement\")"))
	walk.enter(ExportSections.parse_line("@export_subgroup(\"Jump\", \"jump_\")"))
	walk.place("walk_speed")
	var sub_shut: String = "%s/%s" % [walk.group, walk.subgroup]
	walk.enter(ExportSections.parse_line("@export_category(\"Other\")"))
	return SUPPORT.pins("export_sections_test", [
		["a section line reads as its kind, name and prefix",
			ExportSections.parse_line("@export_group(\"Bullet\", \"bullet\")"),
			{"kind": "group", "name": "Bullet", "prefix": "bullet"}],
		["an empty group line is an end line", ExportSections.parse_line("  @export_group(\"\")"),
			{"kind": "group", "name": "", "prefix": ""}],
		["a category with a prefix is not a line the Inspector has", ExportSections.parse_line("@export_category(\"A\", \"a\")"), {}],
		["a block that also holds code is code",
			ExportSections.parse_block("@export_group(\"Gun\")\n@export var damage := 3"), []],
		["a block of two section lines is two sections",
			ExportSections.parse_block("@export_group(\"\")\n\n@export_subgroup(\"Jump\")").size(), 2],
		["a fitting name joins the prefix group", in_bullet, "true/Bullet"],
		["the first name that does not fit is shut out, and says by which group",
			ExportSections.outside_note(shut), "Not in Bullet: that group only takes names starting bullet."],
		["and the group stays closed for every name after it", after, "|true"],
		["a subgroup's prefix closes only the subgroup", sub_shut, "Movement/"],
		["a category ends the group around it", "%s/%s" % [walk.category, walk.group], "Other/"],
		["what a head holds, in words", ExportSections.holds_text(1, 1), "1 variable · 1 subgroup"],
	])


## The board's script, opened: band, strips, the end line, the prefix tint, the subgroup inside its
## group, the shut-out member with its help note, the hover on a head's NAME only, the inferred type
## and the badge's code - and the file re-emits byte for byte.
static func _test_the_sheet_reading() -> bool:
	var view: EventSheetViewport = _view(_open())
	var shape := PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or row_data.row_uid.begins_with("sheet_head_") or row_data.row_uid.begins_with("add_event"):
			continue
		var parent: EventRowData = entry.get("parent")
		shape.append("%s%s" % ["  " if parent != null else "", _texts(row_data)])
	var gun: EventRowData = _row(view, "variable_tree_group_Gun_0")
	var bullet: EventRowData = _row_named(view, "Bullet")
	var health: EventRowData = _member(view, "health")
	var bullet_count: EventRowData = _member(view, "bullet_count")
	var damage_type: Dictionary = _span_meta(_member(view, "damage"), "variable_type_span")
	var walk_type: Dictionary = _span_meta(_member(view, "walk_speed"), "variable_type_span")
	var ok: bool = SUPPORT.pins("export_sections_test", [
		["the sections read as the Inspector shows them", "\n".join(shape), "\n".join([
			"Weapon",
			"Gun",
			"  int | damage | ⚙ | = | 3 | Hit points taken per shot",
			"  float | recoil | ⚙ | = | 5",
			"  Gun ends here | @export_group(\"\")",
			"Bullet | bullet*",
			"  int | bullet_count | ⚙ | = | 3",
			"  float | bullet_speed | ⚙ | = | 10",
			"int | health | ⚙ | = | 10",
			"Movement",
			"Movement",
			"  float | walk_speed | ⚙ | = | 220",
			"  Jump",
			"  float | jump_height | ⚙ | = | 64",
			"  int | max_jumps | ⚙ | = | 2",
			"float | _cooldown | = | 0"])],
		["a head's hover says its kind, what it holds and its line - on the name",
			str((gun.spans[0].metadata as Dictionary).get("hover_note")),
			"Gun - an export group\nThe exported variables under it share one folder in the Inspector, until the group ends.\n2 variables\n@export_group(\"Gun\")\nDouble-click to rename it."],
		["a head the script line declares IS that line, so a double-click edits it",
			bullet.source_resource is RawCodeRow and bool((bullet.spans[0].metadata as Dictionary).get("raw_section")), true],
		["a prefix group's members tint the start their name matched",
			((_span_meta(bullet_count, "variable_name_span").get("bbcode_segments") as Array)[0] as Dictionary).get("text"), "bullet"],
		["the member a prefix shut out says why, in the help strip only", health.help_note,
			"Not in Bullet: that group only takes names starting bullet."],
		["and nothing about it inside the row", _texts(health), "int | health | ⚙ | = | 10"],
		["a type the code does not write reads as inferred", damage_type.get("variable_type_inferred"), true],
		["and its hover says so, and where to write it", damage_type.get("hover_note"),
			"int (inferred) - no type is written in the code, so Godot takes it from the default value. Properties... can write it."],
		["a written type says it is written", [walk_type.get("variable_type_inferred"), walk_type.get("hover_note")],
			[false, "float - the type written in the code."]],
		["a badge's hover ends with the code that earns it",
			NativeVariableMarks.badge_tooltip(NativeVariableMarks.BADGE_RANGE, _member(view, "walk_speed").source_resource),
			"Kept between limits in the Inspector (@export_range).\n@export_range(0, 600)"],
		["the file still re-emits byte for byte", str(SheetCompiler.compile(view._sheet).get("output", "")), SOURCE],
	])
	view.free()
	return ok


## Properties offers "Write the type in code" only to an inferred member, writes it in one step with
## the value's own words, and an untouched save leaves the file as it was (`5.0` stays `5.0`).
static func _test_writing_the_type() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(_open())
	dock._variable_dlg.init_dialog(dock)
	dock._variable_dlg.set_sheet_provider(func() -> EventSheetResource: return dock._current_sheet)
	_edit(dock, "walk_speed")
	var typed_offer: bool = dock._variable_dlg._write_type_check.visible
	_edit(dock, "recoil")
	dock._variable_dlg._on_confirmed()
	var untouched: String = str(SheetCompiler.compile(dock._current_sheet).get("output", ""))
	_edit(dock, "damage")
	var offer: String = dock._variable_dlg._write_type_check.text if dock._variable_dlg._write_type_check.visible else ""
	dock._variable_dlg._write_type_check.button_pressed = true
	dock._variable_dlg._on_confirmed()
	var written: String = str(SheetCompiler.compile(dock._current_sheet).get("output", ""))
	var ok: bool = SUPPORT.pins("export_sections_test", [
		["a written type is offered nothing", typed_offer, false],
		["an untouched save keeps the file's own words", untouched, SOURCE],
		["an inferred member is offered the type Godot infers", offer, "Write the type in code (: int)"],
		["ticked, the line writes it - and nothing else moves", written,
			SOURCE.replace("@export var damage := 3", "@export var damage: int = 3")],
	])
	dock.free()
	return ok


static func _open() -> EventSheetResource:
	var path: String = "user://export_sections_probe.gd"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.editor_style = (load("res://addons/eventsheet/themes/editor_native_theme.tres") as EventSheetEditorStyle).duplicate(true)
	return sheet


static func _view(sheet: EventSheetResource) -> EventSheetViewport:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _edit(dock: EventSheetDock, var_name: String) -> void:
	for entry: Variant in dock._current_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == var_name:
			dock._variables._context_variable = {"scope": "tree", "resource": entry}
	dock._variables._edit_context_variable()


static func _row(view: EventSheetViewport, uid: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid == uid:
			return row_data
	return null


static func _row_named(view: EventSheetViewport, text: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not row_data.spans.is_empty() and row_data.spans[0].text == text:
			return row_data
	return null


static func _member(view: EventSheetViewport, var_name: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is LocalVariable \
				and (row_data.source_resource as LocalVariable).name == var_name:
			return row_data
	return null


static func _span_meta(row_data: EventRowData, flag: String) -> Dictionary:
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get(flag, false)):
			return span.metadata
	return {}


static func _texts(row_data: EventRowData) -> String:
	var parts := PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	return " | ".join(parts)
