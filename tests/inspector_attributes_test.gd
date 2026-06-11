# Godot EventSheets — Inspector attributes, Tier 1 (docs/INSPECTOR-ATTRIBUTES-SPEC.md):
# tooltip / group / range / multiline on exported globals; canonical emission order;
# lossless raw fallback for external files.
@tool
extends RefCounted
class_name InspectorAttributesTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func run() -> bool:
	var all_passed: bool = true

	# Emission: tooltip doc-comment, then group, then the annotated export line.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"max_health": {"type": "int", "default": 100, "exported": true,
			"attributes": {"tooltip": "Max health", "group": "Combat", "range": {"min": "0", "max": "200", "step": "1"}}},
		"bio": {"type": "String", "default": "", "exported": true, "attributes": {"multiline": true}},
		"secret": {"type": "int", "default": 7, "exported": false, "attributes": {"tooltip": "never shown"}},
		"difficulty": {"type": "String", "default": "easy", "exported": true, "options": ["easy", "hard"],
			"attributes": {"tooltip": "Pick one"}}
	}
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_attrs.gd").get("output", ""))
	all_passed = _check("range merges into the export annotation",
		output.contains("@export_range(0, 200, 1) var max_health: int = 100"), true) and all_passed
	var tooltip_at: int = output.find("## Max health")
	var group_at: int = output.find("@export_group(\"Combat\")")
	var var_at: int = output.find("var max_health")
	all_passed = _check("canonical order: tooltip, group, export line",
		tooltip_at >= 0 and tooltip_at < group_at and group_at < var_at, true) and all_passed
	all_passed = _check("multiline strings annotate",
		output.contains("@export_multiline var bio: String = \"\""), true) and all_passed
	all_passed = _check("non-exported variables ignore attributes",
		output.contains("never shown"), false) and all_passed
	all_passed = _check("combos keep their enum prefix alongside a tooltip",
		output.contains("## Pick one") and output.contains("@export_enum(\"easy\", \"hard\") var difficulty"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("attributed output parses", generated.reload(true) == OK, true) and all_passed

	# Dialog plumbing: fields -> attributes payload -> dock storage.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var dock_sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(dock_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._on_variable_dialog_confirmed("speed", "float", 5.0, "global", {}, false, true,
		PackedStringArray(), {"tooltip": "Units/sec", "range": {"min": "0", "max": "10", "step": "0.5"}})
	var stored: Dictionary = dock_sheet.variables.get("speed", {})
	all_passed = _check("dock stores the attributes",
		(stored.get("attributes", {}) as Dictionary).get("tooltip", ""), "Units/sec") and all_passed
	var stored_output: String = str(SheetCompiler.compile(dock_sheet, "user://eventsheets_attrs2.gd").get("output", ""))
	all_passed = _check("stored attributes compile",
		stored_output.contains("@export_range(0, 10, 0.5) var speed: float = 5.0"), true) and all_passed
	editor.free()

	# Lossless rule: an external .gd with attribute lines round-trips byte-identically
	# (the prefix lines ride as raw rows; nothing rewrites them).
	var ext: String = "extends Node\n\n## Max health\n@export_group(\"Combat\")\n@export_range(0, 200, 1) var max_health: int = 100\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(ext)
	imported.external_source_path = "user://eventsheets_attrs_ext.gd"
	all_passed = _check("external attribute lines round-trip byte-identically",
		str(SheetCompiler.compile(imported, "user://eventsheets_attrs_ext.gd").get("output", "")) == ext, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_attributes_test: %s" % label)
		return true
	print("[FAIL] inspector_attributes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
