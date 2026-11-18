# Godot EventSheets - Duplicate as Variant on rows read from a .gd file.
#
# A sheet opened from a .gd keeps its class-level `var` lines as variable rows rather than in its
# `variables` table, and its rows carry no baked codegen text. The window used to look only at the
# table and at the baked text, so for such a sheet it said the rows "name no objects and no
# variables" and listed them as internal ids. This pins the three things that changed: the variable
# the rows use is found, a rename reaches the rows and the variable that gets created, a variable the
# sheet already declares is never declared a second time, and the preview reads in the row's own words.
@tool
class_name DuplicateVariantGdRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "duplicate_variant_gd_rows_test"
const SOURCE := "extends CharacterBody2D\n\n\nvar hp: int = 100\n@onready var flash: AnimationPlayer = $Flash\n\n\nfunc _process(delta: float) -> void:\n\tif hp < 10:\n\t\tflash.play(\"hurt\")\n"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source(SOURCE, true, "")
	var event: EventRow = null
	for row: Variant in sheet.events:
		if row is EventRow:
			event = row as EventRow
	var found: Dictionary = EventSheetDuplicateVariant.targets(sheet, [event])
	var remapped: Dictionary = EventSheetDuplicateVariant.variant(sheet, [event], {"objects": {}, "variables": {"hp": "hp2"}})
	var renamed_rows: Array = remapped.get("rows", []) as Array
	var renamed_params: String = var_to_str((renamed_rows[0] as EventRow).conditions[0].params) if not renamed_rows.is_empty() else ""
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var builder: EventSheetViewportRowBuilder = viewport._row_builder
	var sentence: Callable = func(row_event: EventRow) -> String: return builder.row_sentence(row_event)
	var plain_lines: PackedStringArray = EventSheetDuplicateVariant.preview_lines(
		EventSheetDuplicateVariant.variant(sheet, [event], {}))
	var said_lines: PackedStringArray = EventSheetDuplicateVariant.preview_lines(
		EventSheetDuplicateVariant.variant(sheet, [event], {}), sentence)
	var hp_row: LocalVariable = null
	var flash_row: LocalVariable = null
	for row: Variant in sheet.events:
		if row is LocalVariable and (row as LocalVariable).name == "hp":
			hp_row = row as LocalVariable
		if row is LocalVariable and (row as LocalVariable).name == "flash":
			flash_row = row as LocalVariable
	viewport.free()
	return SUPPORT.pins(TEST_NAME, [
		["the variable the rows use is found though the sheet keeps it as a row", found.get("variables", []), ["hp"]],
		["a variable row that says more than a table entry can (@onready) is not offered as a variable", found.get("variables", []).has("flash"), false],
		["a rename reaches the rows", renamed_params.contains("hp2"), true],
		["and the variable that will be created carries the new name", (remapped.get("required_variables", {}) as Dictionary).keys(), ["hp2"]],
		["the created variable keeps the type and the value of the one it came from",
			var_to_str(((remapped.get("required_variables", {}) as Dictionary).get("hp2", {}) as Dictionary).get("default", -1)), "100"],
		["the sheet already declares hp, so a paste does not declare it again", EventSheetSnippet.sheet_declares(sheet, "hp"), true],
		["the sheet already declares flash too", EventSheetSnippet.sheet_declares(sheet, "flash"), true],
		["and does not declare a name it lacks", EventSheetSnippet.sheet_declares(sheet, "hp2"), false],
		["the plain preview still falls back to the row's id when it has no sentence to use", plain_lines.has("? CompareVar"), true],
		["the preview with the sheet's own sentence has no internal id", " ".join(said_lines).contains("CompareVar"), false],
		["the preview says one line for the event, in the sheet's words", said_lines.size(), 1],
		["and that line names the variable the row compares", said_lines[0].contains("hp") if said_lines.size() > 0 else false, true],
		["the declared rows exist in the sheet this test read", hp_row != null and flash_row != null, true],
	])
