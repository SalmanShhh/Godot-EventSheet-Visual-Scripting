# EventForge — GDScript-backed sheets (open ANY .gd as a sheet, losslessly)
#
# THE CONTRACT (GDSCRIPT-PAIRING-SPEC): importing a GDScript file and saving it untouched
# reproduces the file byte-identically. Declarations lift to first-class rows only when
# canonical re-emission matches the source exactly (verify-lift); everything else is kept
# verbatim as ordered block rows. Hand-written helper functions reverse-lift to un-exposed sheet
# functions (Phase 1); events added later land in the events section (standard sheet layout).
@tool
extends RefCounted
class_name ExternalSheetTest

## Deliberately hostile sample: prelude annotations, comments, a canonical (liftable) var,
## non-canonical vars (inferred type / unusual spacing), signal, enum, const, non-void
## function, default-param function, and blank-line structure that must all survive.
const SAMPLE_SOURCE := """@tool
class_name ExternalSample
extends CharacterBody2D

## Player movement sample.

var hp: int = 100
var speed := 5.0
var  weird_spacing : int = 2

signal hurt(amount: int)

enum Mode { IDLE, RUN }
const MAX_HP: int = 200

func get_mode() -> int:
	return Mode.IDLE

func reset(to_full: bool = true) -> void:
	if to_full:
		hp = MAX_HP
"""

static func run() -> bool:
	var all_passed: bool = true
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external_source(SAMPLE_SOURCE)
	sheet.external_source_path = "user://external_sample.gd"

	# Golden round-trip: untouched sheet reproduces the file byte-identically.
	var output: String = str(SheetCompiler.compile(sheet, "user://external_sample.gd").get("output", ""))
	all_passed = _check("untouched round-trip is byte-identical", output == SAMPLE_SOURCE, true) and all_passed
	all_passed = _check("host class parsed for lint/completion", sheet.host_class, "CharacterBody2D") and all_passed
	all_passed = _check("no generated header on external files", output.contains("AUTO-GENERATED"), false) and all_passed

	# Verify-lift: exactly the canonical var lifted; non-canonical ones stayed verbatim.
	var lifted_names: Array[String] = []
	var function_blocks: int = 0
	for entry in sheet.events:
		if entry is LocalVariable:
			lifted_names.append((entry as LocalVariable).name)
		elif entry is RawCodeRow and (entry as RawCodeRow).code.begins_with("func "):
			function_blocks += 1
	all_passed = _check("canonical var lifted to a variable row", lifted_names, ["hp"] as Array[String]) and all_passed
	# Phase 1: hand-written helper functions reverse-lift to un-exposed sheet functions, not blocks.
	all_passed = _check("plain functions lift to sheet functions, not blocks", function_blocks, 0) and all_passed
	var helper_names: Array[String] = []
	for fn in sheet.functions:
		helper_names.append((fn as EventFunction).function_name)
	all_passed = _check("both helper functions lifted as sheet functions", helper_names, ["get_mode", "reset"] as Array[String]) and all_passed

	# Editing a lifted variable changes exactly that line on save.
	for entry in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "hp":
			(entry as LocalVariable).default_value = 150
	var edited_output: String = str(SheetCompiler.compile(sheet, "user://external_sample.gd").get("output", ""))
	all_passed = _check("edited variable updates its line", edited_output.contains("var hp: int = 150"), true) and all_passed
	all_passed = _check("everything else is untouched by the edit",
		edited_output.replace("var hp: int = 150", "var hp: int = 100") == SAMPLE_SOURCE, true) and all_passed

	# Adding an event puts it in the events section (standard sheet layout) — before the lifted
	# helper functions. The prelude stays a prefix, both helpers survive intact, and the diff is a
	# single clean insert. (The untouched round-trip above already proved byte-identity.)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "QueueFree"
	event.actions.append(action)
	sheet.events.append(event)
	var with_event: String = str(SheetCompiler.compile(sheet, "user://external_sample.gd").get("output", ""))
	all_passed = _check("added event compiles as a trigger function",
		with_event.contains("func _process(") and with_event.contains("queue_free()"), true) and all_passed
	all_passed = _check("prelude stays a prefix when an event is added",
		with_event.begins_with("@tool\nclass_name ExternalSample\nextends CharacterBody2D"), true) and all_passed
	all_passed = _check("lifted helper functions survive the added event",
		with_event.contains("func get_mode() -> int:\n\treturn Mode.IDLE")
		and with_event.contains("func reset(to_full: bool = true) -> void:"), true) and all_passed
	all_passed = _check("added event sits in the events section, before the helpers",
		with_event.find("func _process(") < with_event.find("func get_mode("), true) and all_passed

	# Dock flow: open a real file as a sheet, save back, confirm identical on disk.
	var sample_path: String = "user://external_dock_sample.gd"
	var sample_file: FileAccess = FileAccess.open(sample_path, FileAccess.WRITE)
	sample_file.store_string(SAMPLE_SOURCE)
	sample_file.close()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor._load_sheet_from_path(sample_path)
	all_passed = _check("dock opens .gd as a GDScript-backed sheet",
		editor._current_sheet != null and editor._current_sheet.external_source_path == sample_path, true) and all_passed
	# Opening a .gd is a SAFE read-only PREVIEW by default — a casual look never overwrites it.
	all_passed = _check("opening a .gd is a read-only preview", editor._current_sheet.read_only, true) and all_passed
	# Modify a lifted variable, then a preview-save must NOT write it back over the source.
	for preview_entry in editor._current_sheet.events:
		if preview_entry is LocalVariable and (preview_entry as LocalVariable).name == "hp":
			(preview_entry as LocalVariable).default_value = 999
	editor._on_save_requested()
	all_passed = _check("preview save does not overwrite the source file",
		FileAccess.get_file_as_string(sample_path) == SAMPLE_SOURCE, true) and all_passed
	# "Edit Events" unlocks editing; the two-way GDScript-backed save then writes the change.
	editor._on_preview_edit_requested()
	all_passed = _check("Edit Events unlocks editing", editor._current_sheet.read_only, false) and all_passed
	editor._on_save_requested()
	all_passed = _check("dock save writes the edit back to disk after unlock",
		FileAccess.get_file_as_string(sample_path).contains("var hp: int = 999"), true) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] external_sheet_test: %s" % label)
		return true
	print("[FAIL] external_sheet_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
