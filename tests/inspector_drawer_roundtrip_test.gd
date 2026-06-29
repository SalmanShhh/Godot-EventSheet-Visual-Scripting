# Godot EventSheets — Tier 3 custom-drawer round-trip (docs/INSPECTOR-ATTRIBUTES-SPEC.md).
#
# Each drawer compiles to an `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>…")` marker — graceful
# degradation: without the editor plugin (or in an exported game) the property is a plain field. This pins
# (a) emission of every drawer on its compatible type, (b) type-gating (an incompatible type emits no marker),
# and (c) the importer recovering the marker back into editable attributes.drawer (+ bounds) instead of a
# stray @export_custom block. progress_bar/texture_preview/curve_editor have clean (numeric/null) defaults so
# they round-trip fully; vector_dial/swatch_row round-trip when the var's own Vector2/Color default does.
@tool
extends RefCounted
class_name InspectorDrawerRoundtripTest

static func run() -> bool:
	var all_passed: bool = true

	# --- Emission: each drawer on its compatible type produces its marker prefix. ---
	all_passed = _eq("progress_bar emits its marker (with bounds)",
		_emit_for("int", 50, {"drawer": "progress_bar", "range": {"min": "0", "max": "200"}}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var v: int = 50") and all_passed
	all_passed = _eq("progress_bar defaults its bounds to 0..100 without a range",
		_emit_for("float", 1.0, {"drawer": "progress_bar"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:100\") var v: float = 1.0") and all_passed
	all_passed = _starts("vector_dial emits its marker (with max magnitude)",
		_emit_for("Vector2", Vector2(0, 0), {"drawer": "vector_dial", "range": {"max": "150"}}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:150\") var v: Vector2 = ") and all_passed
	all_passed = _starts("swatch_row emits its marker",
		_emit_for("Color", Color(1, 1, 1, 1), {"drawer": "swatch_row"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:swatch_row\") var v: Color = ") and all_passed
	all_passed = _eq("texture_preview emits its marker",
		_emit_for("Texture2D", null, {"drawer": "texture_preview"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:texture_preview\") var v: Texture2D = null") and all_passed
	all_passed = _eq("curve_editor emits its marker",
		_emit_for("Curve", null, {"drawer": "curve_editor"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:curve_editor\") var v: Curve = null") and all_passed

	# --- Type-gating: a drawer on an incompatible type emits no marker (plain @export, no corruption). ---
	all_passed = _eq("progress_bar on Vector2 emits no marker",
		_emit_for("Vector2", Vector2(0, 0), {"drawer": "progress_bar"}).contains("eventsheet:"), false) and all_passed
	all_passed = _eq("swatch_row on int emits no marker",
		_emit_for("int", 0, {"drawer": "swatch_row"}).contains("eventsheet:"), false) and all_passed
	all_passed = _eq("curve_editor on Color emits no marker",
		_emit_for("Color", Color(1, 1, 1, 1), {"drawer": "curve_editor"}).contains("eventsheet:"), false) and all_passed
	all_passed = _eq("an unexported drawer var emits no marker",
		_emit_unexported("int", 5, {"drawer": "progress_bar"}).contains("eventsheet:"), false) and all_passed

	# --- Round-trip (clean-default drawers): import a marker line, recover an editable attributes.drawer. ---
	all_passed = _roundtrip("progress_bar", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var hp: int = 50", "hp", "progress_bar") and all_passed
	all_passed = _roundtrip("texture_preview", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:texture_preview\") var icon: Texture2D = null", "icon", "texture_preview") and all_passed
	all_passed = _roundtrip("curve_editor", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:curve_editor\") var falloff: Curve = null", "falloff", "curve_editor") and all_passed

	# progress_bar recovers its bounds into the range dict the emitter reads.
	var pb_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var hp: int = 50\n")
	var pb: LocalVariable = _find(pb_sheet, "hp")
	all_passed = _eq("progress_bar recovers its bounds into range",
		(pb.attributes as Dictionary).get("range") if pb != null else null, {"min": "0", "max": "200"}) and all_passed

	# A read-only @export_custom (empty hint string) must NOT be mistaken for a drawer.
	var ro_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n@export_custom(PROPERTY_HINT_NONE, \"\", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var locked: int = 3\n")
	var ro: LocalVariable = _find(ro_sheet, "locked")
	all_passed = _eq("read-only export_custom is not absorbed as a drawer",
		ro != null and (ro.attributes as Dictionary).has("drawer"), false) and all_passed

	# --- New value types round-trip byte-exact (the hosts for the dial / swatch / texture / curve drawers). ---
	all_passed = _type_roundtrip("Vector2", "@export var dir: Vector2 = Vector2(5.0, -3.0)", "dir") and all_passed
	all_passed = _type_roundtrip("Color", "@export var tint: Color = Color(0.5, 0.25, 0.75, 1.0)", "tint") and all_passed
	all_passed = _type_roundtrip("Texture2D", "@export var icon: Texture2D = null", "icon") and all_passed
	all_passed = _type_roundtrip("Curve", "@export var falloff: Curve = null", "falloff") and all_passed

	# With the value types round-tripping, the Vector2/Color drawers now round-trip FULLY (the var lifts, then
	# the drawer extracts) — not just emit.
	all_passed = _roundtrip("vector_dial", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:150\") var aim: Vector2 = Vector2(0.0, 0.0)", "aim", "vector_dial") and all_passed
	all_passed = _roundtrip("swatch_row", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:swatch_row\") var hue: Color = Color(1.0, 1.0, 1.0, 1.0)", "hue", "swatch_row") and all_passed

	return all_passed

static func _emit_for(type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var lv: LocalVariable = LocalVariable.new()
	lv.name = "v"
	lv.type_name = type_name
	lv.default_value = default_value
	lv.exported = true
	lv.attributes = attributes
	return SheetCompiler._emit_tree_variable_line(lv)

static func _emit_unexported(type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var lv: LocalVariable = LocalVariable.new()
	lv.name = "v"
	lv.type_name = type_name
	lv.default_value = default_value
	lv.exported = false
	lv.attributes = attributes
	return SheetCompiler._emit_tree_variable_line(lv)

static func _find(sheet: EventSheetResource, var_name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == var_name:
			return entry as LocalVariable
	return null

static func _roundtrip(label: String, var_line: String, var_name: String, expected_drawer: String) -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + var_line + "\n")
	var lv: LocalVariable = _find(sheet, var_name)
	var has_block: bool = false
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains("eventsheet:"):
			has_block = true
	var recovered: bool = lv != null and str((lv.attributes as Dictionary).get("drawer", "")) == expected_drawer
	return _eq("%s round-trips into an editable drawer (no block)" % label, recovered and not has_block, true)

static func _type_roundtrip(label: String, var_line: String, var_name: String) -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + var_line + "\n")
	var lv: LocalVariable = _find(sheet, var_name)
	var has_block: bool = false
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains("var " + var_name):
			has_block = true
	var ok: bool = lv != null and not has_block and SheetCompiler._emit_tree_variable_line(lv) == var_line
	return _eq("a %s variable round-trips byte-exact (no block)" % label, ok, true)

static func _eq(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_drawer_roundtrip_test: %s" % label)
		return true
	print("[FAIL] inspector_drawer_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false

static func _starts(label: String, actual: String, prefix: String) -> bool:
	if actual.begins_with(prefix):
		print("[PASS] inspector_drawer_roundtrip_test: %s" % label)
		return true
	print("[FAIL] inspector_drawer_roundtrip_test: %s" % label)
	print("  expected prefix: %s" % prefix)
	print("  actual:          %s" % actual)
	return false
