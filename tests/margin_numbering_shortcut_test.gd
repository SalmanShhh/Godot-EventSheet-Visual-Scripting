# Godot EventSheets - the margin numbers of a sheet the canvas could not renumber are the sheet's own.
#
# Doctor findings and Find results name an event by the number the margin draws, which a throwaway
# canvas reads off (it costs a sheet's whole reading, about a fifth of a second for a small file). A sheet
# whose rows are plain events and declarations is numbered the same by the sheet itself, so the canvas
# is built only for one that holds a group, a lambda handed to connect, a file included, or a row the
# shortcut does not know. The pins hold the shortcut up against the canvas: over the shipped showcases
# and a spread of the packs it may skip the canvas only where the canvas would have answered the same.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "margin_numbering_shortcut_test"
const NUMBERING := preload("res://addons/eventsheet/editor/interaction/margin_numbering.gd")
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const LAMBDA_SOURCE := "extends Node\n\n\nfunc _ready() -> void:\n\t$Button.pressed.connect(func() -> void:\n\t\tprint(\"a\")\n\t\tprint(\"b\"))\n\tprint(\"after\")\n"
const PLAIN_SOURCE := "extends Node\n\nvar hp: int = 3\n\n\nfunc _ready() -> void:\n\tprint(\"a\")\n\n\nfunc _process(_delta: float) -> void:\n\thp -= 1\n"


static func run() -> bool:
	var rows: Array = []
	var plain: EventSheetResource = _in_native_look(SUPPORT.reopen(PLAIN_SOURCE))
	rows.append(["a sheet of plain events: the canvas cannot renumber it", NUMBERING.can_differ(plain), false])
	rows.append(["a connect lambda kept as one raw statement: the canvas might", NUMBERING.can_differ(_raw_lambda_sheet()), true])
	rows.append(["an `a if c else b` value is a branch drawn as a pair: the canvas might", NUMBERING.can_differ(_in_native_look(SUPPORT.reopen("extends Node

var a: int = 0


func _process(_d: float) -> void:
	a = 1 if Input.is_action_pressed(\"x\") else 2
"))), true])
	var grouped: EventSheetResource = _grouped_sheet()
	rows.append(["a sheet with a group: the canvas might", NUMBERING.can_differ(grouped), true])
	var model: Dictionary = EventSheetResource.event_numbers(grouped.events, grouped.functions)
	var drawn: Dictionary = NUMBERING.canvas_numbers(grouped, model)
	rows.append(["a group takes a place of its own, so the canvas does move the numbers after it", _moved(model, drawn), true])
	rows.append(["the numbers asked for are the canvas's for that sheet", NUMBERING.numbers(grouped) == drawn, true])
	var lambda_sheet: EventSheetResource = _in_native_look(SUPPORT.reopen(LAMBDA_SOURCE))
	var lambda_model: Dictionary = EventSheetResource.event_numbers(lambda_sheet.events, lambda_sheet.functions)
	rows.append(["a lambda that lifts to a trigger of its own is numbered as the canvas numbers it", NUMBERING.numbers(lambda_sheet) == NUMBERING.canvas_numbers(lambda_sheet, lambda_model), true])
	# The shortcut over real files: wherever it says the canvas cannot differ, the canvas does not.
	var checked: int = 0
	var skipped: int = 0
	var disagree: PackedStringArray = PackedStringArray()
	for path: String in _population():
		var sheet: EventSheetResource = _in_native_look(SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path))
		if sheet == null:
			continue
		checked += 1
		if NUMBERING.can_differ(sheet):
			continue
		skipped += 1
		var own: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
		if NUMBERING.canvas_numbers(sheet, own) != own:
			disagree.append(path)
	rows.append(["files read", checked > 20, true])
	rows.append(["some of them are numbered without a canvas", skipped > 5, true])
	rows.append(["files the shortcut skipped and the canvas numbers differently", disagree, PackedStringArray()])
	return SUPPORT.pins(P, rows)


static func _in_native_look(sheet: EventSheetResource) -> EventSheetResource:
	if sheet != null:
		sheet.editor_style = (load(NATIVE_THEME) as EventSheetEditorStyle).duplicate(true)
	return sheet


static func _moved(model: Dictionary, drawn: Dictionary) -> bool:
	for id: Variant in model:
		if int(model[id]) != int(drawn.get(id, -1)):
			return true
	return false


## An event whose one action is a connect lambda the importer left as raw code.
static func _raw_lambda_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = _in_native_look(EventSheetResource.new())
	var event := EventRow.new()
	var raw := RawCodeRow.new()
	raw.code = "$Button.pressed.connect(func() -> void:
	print(1))"
	event.actions.append(raw)
	sheet.events.append(event)
	return sheet


## A group holding one event, and an event after it: the group takes the first place in the margin.
static func _grouped_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = _in_native_look(EventSheetResource.new())
	var group := EventGroup.new()
	group.name = "Group"
	var inside := EventRow.new()
	group.events.append(inside)
	var after := EventRow.new()
	sheet.events.append(group)
	sheet.events.append(after)
	return sheet


## Every showcase script, and every eighth pack script, in path order.
static func _population() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_collect("res://demo/showcase", found, 1)
	_collect("res://eventsheet_addons", found, 8)
	return found


static func _collect(folder: String, into: PackedStringArray, every: int) -> void:
	var seen: int = 0
	var pending: PackedStringArray = PackedStringArray([folder])
	var files: PackedStringArray = PackedStringArray()
	while not pending.is_empty():
		var here: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for sub: String in DirAccess.get_directories_at(here):
			pending.append(here.path_join(sub))
		for file: String in DirAccess.get_files_at(here):
			if file.get_extension() == "gd":
				files.append(here.path_join(file))
	files.sort()
	for file: String in files:
		if seen % every == 0:
			into.append(file)
		seen += 1
