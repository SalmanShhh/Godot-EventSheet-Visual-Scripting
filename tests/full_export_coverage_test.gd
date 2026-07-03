# EventForge - full inspector export coverage, P1 (SPEC-full-export-coverage).
#
# THE CONTRACT: every wider @export hint family (range + its modifier tail, checkbox flags,
# layer masks, file/folder pickers, node-path filters, int-backed enums, storage, category)
# emits ONE canonical shape from structured attributes, lifts back from a .gd into those SAME
# editable attributes (never a verbatim hint), and round-trips byte-identically. Hand-written
# variants the canon cannot reproduce stay verbatim hints - degradation, never corruption.
@tool
class_name FullExportCoverageTest
extends RefCounted

## Canonical source: one variable per P1 family, exactly as the emitter spells them.
const COVERAGE_SOURCE := """extends Node

## Speed in pixels per second.
@export_category("Movement")
@export_range(0, 500, 5, "or_greater", "suffix:px") var speed: float = 220.0
@export_range(-3.14, 3.14, 0.01, "radians_as_degrees") var aim_angle: float = 0.0
@export_flags("Fire:1", "Ice:2", "Poison:4") var damage_types: int = 0
@export_enum("Slow:30", "Fast:60", "Turbo:120") var tick_rate: int = 60
@export_flags_2d_physics var wall_mask: int = 1
@export_file("*.ogg", "*.wav") var hit_sound: String = ""
@export_global_dir var export_folder: String = ""
@export_node_path("Button", "TouchScreenButton") var confirm_button: NodePath = NodePath("")
@export_storage var run_seed: int = 0
"""


static func run() -> bool:
	var all_passed: bool = true
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external_source(COVERAGE_SOURCE)
	sheet.external_source_path = "user://export_coverage.gd"

	# ── Every family lifts to STRUCTURED attributes (editable), not a verbatim hint ──
	var by_name: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			by_name[(entry as LocalVariable).name] = entry
	all_passed = _check("all nine variables lift as rows", by_name.size(), 9) and all_passed
	var speed: LocalVariable = by_name.get("speed")
	all_passed = _check("range modifiers lift structured (or_greater + suffix)",
		speed != null and speed.export_hint.is_empty()
		and bool((speed.attributes.get("range", {}) as Dictionary).get("or_greater", false))
		and str((speed.attributes.get("range", {}) as Dictionary).get("suffix", "")) == "px", true) and all_passed
	all_passed = _check("category absorbs onto the variable",
		str(speed.attributes.get("category", "")) if speed != null else "missing", "Movement") and all_passed
	all_passed = _check("tooltip still rides with the category",
		str(speed.attributes.get("tooltip", "")) if speed != null else "missing", "Speed in pixels per second.") and all_passed
	var aim: LocalVariable = by_name.get("aim_angle")
	all_passed = _check("angle modifier lifts structured",
		str((aim.attributes.get("range", {}) as Dictionary).get("angle", "")) if aim != null else "missing", "radians_as_degrees") and all_passed
	var damage: LocalVariable = by_name.get("damage_types")
	all_passed = _check("flags lift with their explicit values",
		damage != null and damage.export_hint.is_empty()
		and str((damage.attributes.get("flags", []) as Array)[0].get("label", "")) == "Fire"
		and str((damage.attributes.get("flags", []) as Array)[0].get("value", "")) == "1", true) and all_passed
	var tick: LocalVariable = by_name.get("tick_rate")
	all_passed = _check("int-backed enum lifts to enum_values",
		tick != null and (tick.attributes.get("enum_values", []) as Array).size() == 3, true) and all_passed
	var wall: LocalVariable = by_name.get("wall_mask")
	all_passed = _check("layer mask lifts structured", str(wall.attributes.get("layers", "")) if wall != null else "missing", "2d_physics") and all_passed
	var sound: LocalVariable = by_name.get("hit_sound")
	all_passed = _check("file picker lifts with its filters",
		sound != null and (sound.attributes.get("file", {}) as Dictionary).get("filters", []).size() == 2, true) and all_passed
	var folder: LocalVariable = by_name.get("export_folder")
	all_passed = _check("global dir lifts structured",
		folder != null and str((folder.attributes.get("file", {}) as Dictionary).get("mode", "")) == "dir"
		and bool((folder.attributes.get("file", {}) as Dictionary).get("global", false)), true) and all_passed
	var confirm: LocalVariable = by_name.get("confirm_button")
	all_passed = _check("node-path filters lift structured",
		confirm != null and (confirm.attributes.get("node_path_types", []) as Array) == ["Button", "TouchScreenButton"], true) and all_passed
	var seed_var: LocalVariable = by_name.get("run_seed")
	all_passed = _check("storage lifts structured", seed_var != null and bool(seed_var.attributes.get("storage", false)), true) and all_passed

	# ── Byte-identical round-trip through the compiler ──
	all_passed = _check("the whole file round-trips byte-identically",
		str(SheetCompiler.compile(sheet, "user://export_coverage.gd").get("output", "")), COVERAGE_SOURCE) and all_passed

	# ── Near-misses stay verbatim hints (degradation, never corruption) ──
	var hostile: EventSheetResource = importer.import_external_source("extends Node\n\n@export_range(0, 10, 1, \"exp\", \"or_greater\") var odd_order: float = 1.0\n")
	var odd: LocalVariable = null
	for entry: Variant in hostile.events:
		if entry is LocalVariable:
			odd = entry
	all_passed = _check("non-canonical modifier order stays a verbatim hint",
		odd != null and odd.export_hint == "@export_range(0, 10, 1, \"exp\", \"or_greater\")", true) and all_passed
	hostile.external_source_path = "user://export_hostile.gd"
	all_passed = _check("and still round-trips byte-identically",
		str(SheetCompiler.compile(hostile, "user://export_hostile.gd").get("output", "")).contains("@export_range(0, 10, 1, \"exp\", \"or_greater\") var odd_order: float = 1.0"), true) and all_passed

	# ── The dict-variable (main) path emits the same canonical shapes ──
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node"
	authored.variables = {
		"boost": {"type": "float", "default": 1.0, "exported": true, "attributes": {"range": {"min": "0", "max": "10", "step": "0.1", "or_greater": true, "suffix": "x"}}},
		"team_layers": {"type": "int", "default": 0, "exported": true, "attributes": {"layers": "3d_physics"}},
	}
	var authored_output: String = str(SheetCompiler.compile(authored, "user://export_authored.gd").get("output", ""))
	all_passed = _check("dict path emits the range tail canonically",
		authored_output.contains("@export_range(0, 10, 0.1, \"or_greater\", \"suffix:x\") var boost: float = 1.0"), true) and all_passed
	all_passed = _check("dict path emits layer masks",
		authored_output.contains("@export_flags_3d_physics var team_layers: int = 0"), true) and all_passed

	# ── The @export_custom presets + flagged exp-easing round-trip the same way ──
	var tail_source: String = "extends Node

@export_custom(PROPERTY_HINT_PASSWORD, \"\") var api_key: String = \"\"
@export_custom(PROPERTY_HINT_LINK, \"\") var cell_size: Vector2 = Vector2.ZERO
@export_exp_easing(\"attenuation\") var falloff: float = 1.0
"
	var tail_sheet: EventSheetResource = importer.import_external_source(tail_source)
	tail_sheet.external_source_path = "user://export_tail.gd"
	var tail_by_name: Dictionary = {}
	for entry: Variant in tail_sheet.events:
		if entry is LocalVariable:
			tail_by_name[(entry as LocalVariable).name] = entry
	var api_key: LocalVariable = tail_by_name.get("api_key")
	all_passed = _check("password preset lifts structured",
		str(api_key.attributes.get("custom_preset", "")) if api_key != null else "missing", "password") and all_passed
	var cell: LocalVariable = tail_by_name.get("cell_size")
	all_passed = _check("linked-axes preset lifts on a Vector2",
		str(cell.attributes.get("custom_preset", "")) if cell != null else "missing", "link") and all_passed
	var falloff: LocalVariable = tail_by_name.get("falloff")
	all_passed = _check("flagged exp-easing lifts structured",
		(falloff.attributes.get("exp_easing_flags", []) as Array) == ["attenuation"] if falloff != null else false, true) and all_passed
	all_passed = _check("the tail file round-trips byte-identically",
		str(SheetCompiler.compile(tail_sheet, "user://export_tail.gd").get("output", "")), tail_source) and all_passed

	# ── The dialog's look parsing (pure): labels with and without explicit values ──
	var parsed_labels: Array = VariableDialog._parse_look_labels("Fire:1, Ice, Poison:4")
	all_passed = _check("look labels parse with mixed values",
		parsed_labels.size() == 3 and str(parsed_labels[0].get("value")) == "1" and str(parsed_labels[1].get("value")) == "", true) and all_passed
	all_passed = _check("look labels render back to the same text",
		VariableDialog._look_labels_text(parsed_labels), "Fire:1, Ice, Poison:4") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] full_export_coverage_test: %s" % label)
		return true
	print("[FAIL] full_export_coverage_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
