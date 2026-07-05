# Godot EventSheets - Tier 3 custom-drawer round-trip.
#
# Each drawer compiles to an `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>…")` marker - graceful
# degradation: without the editor plugin (or in an exported game) the property is a plain field. This pins
# (a) emission of every drawer on its compatible type, (b) type-gating (an incompatible type emits no marker),
# and (c) the importer recovering the marker back into editable attributes.drawer (+ bounds) instead of a
# stray @export_custom block. progress_bar/texture_preview/curve_editor have clean (numeric/null) defaults so
# they round-trip fully; vector_dial/swatch_row round-trip when the var's own Vector2/Color default does.
@tool
class_name InspectorDrawerRoundtripTest
extends RefCounted


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
	all_passed = _starts("min_max emits its marker (with bounds)",
		_emit_for("Vector2", Vector2(10, 40), {"drawer": "min_max", "range": {"min": "0", "max": "60"}}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:min_max:0:60\") var v: Vector2 = ") and all_passed
	all_passed = _starts("min_max defaults its bounds to 0..100 without a range",
		_emit_for("Vector2", Vector2(0, 0), {"drawer": "min_max"}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:min_max:0:100\") var v: Vector2 = ") and all_passed
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
	all_passed = _eq("min_max on float emits no marker",
		_emit_for("float", 1.0, {"drawer": "min_max"}).contains("eventsheet:"), false) and all_passed
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
	# the drawer extracts) - not just emit.
	all_passed = _roundtrip("vector_dial", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:150\") var aim: Vector2 = Vector2(0.0, 0.0)", "aim", "vector_dial") and all_passed
	all_passed = _roundtrip("swatch_row", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:swatch_row\") var hue: Color = Color(1.0, 1.0, 1.0, 1.0)", "hue", "swatch_row") and all_passed
	all_passed = _roundtrip("min_max", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:min_max:0:60\") var spawn_gap: Vector2 = Vector2(10.0, 40.0)", "spawn_gap", "min_max") and all_passed

	# min_max recovers its bounds into the range dict the emitter reads, and re-emits byte-identically.
	var mm_line: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:min_max:0:60\") var spawn_gap: Vector2 = Vector2(10.0, 40.0)"
	var mm_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + mm_line + "\n")
	var mm: LocalVariable = _find(mm_sheet, "spawn_gap")
	all_passed = _eq("min_max recovers its bounds into range",
		(mm.attributes as Dictionary).get("range") if mm != null else null, {"min": "0", "max": "60"}) and all_passed
	if mm != null:
		all_passed = _eq("a min_max var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(mm), mm_line) and all_passed

	# --- Dialog: the per-type picker offers exactly the drawers each host type can use. ---
	all_passed = _eq("int hosts the progress_bar drawer", VariableDialog._drawer_kinds_for_type("int"), PackedStringArray(["progress_bar"])) and all_passed
	all_passed = _eq("float hosts the progress_bar drawer", VariableDialog._drawer_kinds_for_type("float"), PackedStringArray(["progress_bar"])) and all_passed
	all_passed = _eq("Vector2 hosts the dial AND the min-max slider", VariableDialog._drawer_kinds_for_type("Vector2"), PackedStringArray(["vector_dial", "min_max"])) and all_passed
	all_passed = _eq("Color hosts the swatch_row drawer", VariableDialog._drawer_kinds_for_type("Color"), PackedStringArray(["swatch_row"])) and all_passed
	all_passed = _eq("Texture2D hosts the texture_preview drawer", VariableDialog._drawer_kinds_for_type("Texture2D"), PackedStringArray(["texture_preview"])) and all_passed
	all_passed = _eq("Curve hosts the curve_editor drawer", VariableDialog._drawer_kinds_for_type("Curve"), PackedStringArray(["curve_editor"])) and all_passed
	all_passed = _eq("String hosts no drawer (combo/multiline instead)", VariableDialog._drawer_kinds_for_type("String"), PackedStringArray()) and all_passed
	all_passed = _eq("Dictionary hosts no drawer", VariableDialog._drawer_kinds_for_type("Dictionary"), PackedStringArray()) and all_passed
	all_passed = _eq("the min-max drawer label reads 'Min-max range'",
		VariableDialog._drawer_label_for_kind("min_max"), "Min-max range") and all_passed

	# Dialog default-field round-trip: the EXACT text the dialog displays for a value must parse back to that
	# value. This drives _default_display_text → _parse_default (the real edit cycle). Before the fix the
	# display used str() - "(5.0, -3.0)" - which _parse_default silently zeroed the first component on edit.
	all_passed = _eq("a Vector2 default survives a display→edit cycle",
		VariableDialog._parse_default("Vector2", VariableDialog._default_display_text(Vector2(5.0, -3.0))), Vector2(5.0, -3.0)) and all_passed
	all_passed = _eq("a Color default survives a display→edit cycle",
		VariableDialog._parse_default("Color", VariableDialog._default_display_text(Color(0.5, 0.25, 0.75, 1.0))), Color(0.5, 0.25, 0.75, 1.0)) and all_passed
	all_passed = _eq("a resource (null) default displays empty and parses back to null",
		VariableDialog._parse_default("Texture2D", VariableDialog._default_display_text(null)), null) and all_passed

	# texture_preview is Texture2D-only (matches the dialog picker) - a String never gets the marker.
	all_passed = _eq("texture_preview on a String emits no marker",
		_emit_for("String", "", {"drawer": "texture_preview"}).contains("eventsheet:"), false) and all_passed

	# A drawer + @export_group + @export_subgroup + tooltip on the SAME variable must ALL round-trip - the
	# group absorb must MERGE with (not overwrite) the drawer the hint-extraction already recovered.
	var combo_line: String = "## Aim it.\n@export_group(\"Aim\")\n@export_subgroup(\"Tuning\")\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:120\") var aim: Vector2 = Vector2(0.0, 0.0)"
	var combo_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + combo_line + "\n")
	var combo_var: LocalVariable = _find(combo_sheet, "aim")
	all_passed = _eq("a drawer+group+subgroup+tooltip var lifts (not a block)", combo_var != null, true) and all_passed
	if combo_var != null:
		var ca: Dictionary = combo_var.attributes as Dictionary
		all_passed = _eq("the combined var keeps its drawer", str(ca.get("drawer", "")), "vector_dial") and all_passed
		all_passed = _eq("the combined var keeps its group", str(ca.get("group", "")), "Aim") and all_passed
		all_passed = _eq("the combined var keeps its subgroup", str(ca.get("subgroup", "")), "Tuning") and all_passed
		all_passed = _eq("the combined var keeps its tooltip", str(ca.get("tooltip", "")), "Aim it.") and all_passed
		all_passed = _eq("the combined var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(combo_var), combo_line) and all_passed

	# --- Inspector decor (# @inspector_header / # @inspector_info): plain-comment markers the editor
	# renders as a section label / info panel. Emission order is header, info, tooltip, groups; the
	# absorb recovers them into editable attributes and the whole block re-emits byte-identically.
	var decor_var: LocalVariable = LocalVariable.new()
	decor_var.name = "armour"
	decor_var.type_name = "int"
	decor_var.default_value = 10
	decor_var.exported = true
	decor_var.attributes = {"header": "Combat", "header_color": "#e06666", "info": "Shared resource - edits affect every user.", "tooltip": "Flat reduction.", "group": "Stats"}
	var decor_expected: String = "# @inspector_header Combat #e06666\n# @inspector_info Shared resource - edits affect every user.\n## Flat reduction.\n@export_group(\"Stats\")\n@export var armour: int = 10"
	all_passed = _eq("decor emits header, info, tooltip, group in canonical order",
		SheetCompiler._emit_tree_variable_line(decor_var), decor_expected) and all_passed
	var decor_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + decor_expected + "\n")
	var decor_lifted: LocalVariable = _find(decor_sheet, "armour")
	all_passed = _eq("a decorated var lifts (not a block)", decor_lifted != null, true) and all_passed
	if decor_lifted != null:
		var da: Dictionary = decor_lifted.attributes as Dictionary
		all_passed = _eq("the lift recovers the header title", str(da.get("header", "")), "Combat") and all_passed
		all_passed = _eq("the lift recovers the header accent", str(da.get("header_color", "")), "#e06666") and all_passed
		all_passed = _eq("the lift recovers the info note", str(da.get("info", "")), "Shared resource - edits affect every user.") and all_passed
		all_passed = _eq("the decorated var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(decor_lifted), decor_expected) and all_passed
	var headerless_var: LocalVariable = LocalVariable.new()
	headerless_var.name = "hp"
	headerless_var.type_name = "int"
	headerless_var.default_value = 5
	headerless_var.exported = true
	headerless_var.attributes = {"header": "Vitals"}
	all_passed = _eq("a header without an accent emits no trailing hex",
		SheetCompiler._emit_tree_variable_line(headerless_var), "# @inspector_header Vitals\n@export var hp: int = 5") and all_passed

	# The editor-side decor map: property name -> decor entries, parsed straight from script source
	# (tooltips and @export_* lines may sit between the decor and its var; a blank line orphans it).
	var decor_source: String = "extends Node2D\n\n# @inspector_header Combat #e06666\n# @inspector_info Watch the alpha.\n## Flat reduction.\n@export var armour: int = 10\n\n# @inspector_header Level #not-a-hex\nvar stray: int = 1\n\n# @inspector_info orphaned by a blank line\n\nvar plain: int = 2\n"
	var decor_map: Dictionary = EventSheetAttributeDrawers.build_decor_map(decor_source)
	all_passed = _eq("the decor map binds header + info to the following var",
		decor_map.get("armour"), [{"kind": "header", "text": "Combat", "color": "#e06666"}, {"kind": "info", "text": "Watch the alpha."}]) and all_passed
	all_passed = _eq("a non-hex tail stays part of the header title",
		decor_map.get("stray"), [{"kind": "header", "text": "Level #not-a-hex", "color": ""}]) and all_passed
	all_passed = _eq("a blank line orphans decor (no binding)", decor_map.has("plain"), false) and all_passed

	# Required rides the same decor channel: a bare marker line, absorbed back into a bool attribute.
	var required_var: LocalVariable = LocalVariable.new()
	required_var.name = "portrait"
	required_var.type_name = "Texture2D"
	required_var.default_value = null
	required_var.exported = true
	required_var.attributes = {"required": true, "info": "Every enemy needs a face."}
	var required_expected: String = "# @inspector_info Every enemy needs a face.\n# @inspector_required\n@export var portrait: Texture2D = null"
	all_passed = _eq("required emits its marker after info, before the export",
		SheetCompiler._emit_tree_variable_line(required_var), required_expected) and all_passed
	var required_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + required_expected + "\n")
	var required_lifted: LocalVariable = _find(required_sheet, "portrait")
	all_passed = _eq("the lift recovers required as a bool",
		(required_lifted.attributes as Dictionary).get("required") if required_lifted != null else null, true) and all_passed
	if required_lifted != null:
		all_passed = _eq("a required var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(required_lifted), required_expected) and all_passed
	all_passed = _eq("the decor map carries the required kind",
		EventSheetAttributeDrawers.build_decor_map("extends Node\n\n# @inspector_required\n@export var icon: Texture2D = null\n").get("icon"),
		[{"kind": "required"}]) and all_passed
	all_passed = _eq("a null value counts as missing", EventSheetDrawerWidgets.RequiredBadge.is_value_missing(null), true) and all_passed
	all_passed = _eq("a blank String counts as missing", EventSheetDrawerWidgets.RequiredBadge.is_value_missing("  "), true) and all_passed
	all_passed = _eq("an assigned value is not missing", EventSheetDrawerWidgets.RequiredBadge.is_value_missing("Cave Rat"), false) and all_passed
	all_passed = _eq("zero is a value, not missing (required is for unset, not falsy)",
		EventSheetDrawerWidgets.RequiredBadge.is_value_missing(0), false) and all_passed

	# --- The table drawer: an Array of Dictionary rows edited as a grid; the column schema rides
	# the marker as name=type pairs and round-trips into editable table_columns.
	var table_var: LocalVariable = LocalVariable.new()
	table_var.name = "loot"
	table_var.type_name = "Array"
	table_var.default_value = []
	table_var.exported = true
	table_var.attributes = {"drawer": "table", "table_columns": [{"name": "item", "type": "String"}, {"name": "count", "type": "int"}, {"name": "rare", "type": "bool"}]}
	var table_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,count=int,rare=bool\") var loot: Array = []"
	all_passed = _eq("table emits its marker (columns as name=type pairs)",
		SheetCompiler._emit_tree_variable_line(table_var), table_expected) and all_passed
	all_passed = _eq("table on a non-Array emits no marker",
		_emit_for("int", 0, {"drawer": "table", "table_columns": [{"name": "hp", "type": "int"}]}).contains("eventsheet:"), false) and all_passed
	all_passed = _eq("table without columns emits no marker",
		_emit_for("Array", [], {"drawer": "table"}).contains("eventsheet:"), false) and all_passed
	var table_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + table_expected + "\n")
	var table_lifted: LocalVariable = _find(table_sheet, "loot")
	all_passed = _eq("the lift recovers the table columns",
		(table_lifted.attributes as Dictionary).get("table_columns") if table_lifted != null else null,
		[{"name": "item", "type": "String"}, {"name": "count", "type": "int"}, {"name": "rare", "type": "bool"}]) and all_passed
	if table_lifted != null:
		all_passed = _eq("a table var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(table_lifted), table_expected) and all_passed
	all_passed = _eq("the editor-side column parse matches (unknown types fall back to String)",
		EventSheetAttributeDrawers.parse_table_columns("item=String,count=int,odd=Vector2,=int"),
		[{"name": "item", "type": "String"}, {"name": "count", "type": "int"}, {"name": "odd", "type": "String"}]) and all_passed
	all_passed = _eq("Array hosts the table drawer",
		VariableDialog._drawer_kinds_for_type("Array"), PackedStringArray(["table"])) and all_passed
	var table_grid: EventSheetDrawerWidgets.DrawerTable = EventSheetDrawerWidgets.DrawerTable.new([{"name": "hp", "type": "int"}])
	table_grid.set_value([{"hp": 5}, {"hp": 9}])
	table_grid._on_move_up(1)
	all_passed = _eq("the grid's move-up swaps rows", table_grid.get_value(), [{"hp": 9}, {"hp": 5}]) and all_passed
	table_grid._on_remove(0)
	all_passed = _eq("the grid's remove drops the row", table_grid.get_value(), [{"hp": 5}]) and all_passed
	table_grid._on_add_row()
	all_passed = _eq("the grid's add appends typed defaults", table_grid.get_value(), [{"hp": 5}, {"hp": 0}]) and all_passed
	table_grid.free()

	# The dict-var path emits the same decor lines (one canonical shape across both variable paths).
	var dict_sheet: EventSheetResource = EventSheetResource.new()
	dict_sheet.variables = {"speed": {"type": "int", "default": 5, "exported": true, "attributes": {"header": "Motion", "info": "Tiles per second."}}}
	var dict_output: String = str(SheetCompiler.compile(dict_sheet, "user://decor_dict.gd").get("output", ""))
	all_passed = _eq("dict-path variables emit the same decor lines",
		dict_output.contains("# @inspector_header Motion\n# @inspector_info Tiles per second.\n@export var speed: int = 5"), true) and all_passed

	# Edit cycle: re-confirming a Vector2 dial variable must keep its range (the dial's max magnitude); the
	# apply previously gated range on is_numeric, dropping it for Vector2 and resetting the dial to max 100.
	all_passed = _vector_dial_range_persists() and all_passed

	# Forgiving Range parse (progressive disclosure P2): a bare max, min+max, or min+max+step all parse; a
	# blank max or >3 parts error. Shared by the apply and the live preview so they never disagree.
	all_passed = _eq("Range '150' parses as max 150 (min 0, step 1)",
		VariableDialog._parse_range_parts(PackedStringArray(["150"])), {"min": "0", "max": "150", "step": "1"}) and all_passed
	all_passed = _eq("Range '0, 200' parses min + max",
		VariableDialog._parse_range_parts(PackedStringArray(["0", "200"])), {"min": "0", "max": "200", "step": "1"}) and all_passed
	all_passed = _eq("Range '0, 100, 5' parses min + max + step",
		VariableDialog._parse_range_parts(PackedStringArray(["0", "100", "5"])), {"min": "0", "max": "100", "step": "5"}) and all_passed
	all_passed = _eq("Range with a blank max errors",
		VariableDialog._parse_range_parts(PackedStringArray([""])), {}) and all_passed
	all_passed = _eq("Range with 4 parts errors",
		VariableDialog._parse_range_parts(PackedStringArray(["1", "2", "3", "4"])), {}) and all_passed
	all_passed = _eq("the curve drawer label reads 'Curve preview' (it doesn't edit in place)",
		VariableDialog._drawer_label_for_kind("curve_editor"), "Curve preview") and all_passed
	# Exercise the REAL split path (allow_empty), not just explicit arrays: positions must be preserved so a
	# blank/trailing/middle empty field is caught, not silently shifted. (split(",", false) dropped empties and
	# read "0,,5" as max 5.)
	all_passed = _eq("Range '0,,5' (blank max slot) errors via the real split",
		VariableDialog._parse_range_parts("0,,5".split(",")), {}) and all_passed
	all_passed = _eq("Range '0,' (trailing comma = blank max) errors via the real split",
		VariableDialog._parse_range_parts("0,".split(",")), {}) and all_passed
	all_passed = _eq("Range '0, 100, 5' parses via the real split",
		VariableDialog._parse_range_parts("0, 100, 5".split(",")), {"min": "0", "max": "100", "step": "5"}) and all_passed

	return all_passed


static func _vector_dial_range_persists() -> bool:
	var dlg: VariableDialog = VariableDialog.new()
	var parent: Node = Node.new()
	dlg.init_dialog(parent)
	dlg.set_sheet_provider(func() -> Variant: return null)
	var captured: Dictionary = {}
	dlg.variable_confirmed.connect(func(_n: String, _t: String, _d: Variant, _s: String, _c: Dictionary, _k: bool, _e: bool, _o: PackedStringArray, attributes: Dictionary) -> void:
		captured["attributes"] = attributes
	)
	dlg.open_for_edit("tree", {"editing": true, "attributes": {"drawer": "vector_dial", "range": {"min": "0", "max": "150", "step": "1"}}},
		"aim", "Vector2", Vector2(0.0, 0.0), false, "edit", false, true)
	dlg._on_confirmed()
	parent.free()
	var attrs: Dictionary = captured.get("attributes", {})
	var range_dict: Variant = attrs.get("range")
	var ok: bool = str(attrs.get("drawer", "")) == "vector_dial" and range_dict is Dictionary and str((range_dict as Dictionary).get("max", "")) == "150"
	return _eq("a vector_dial's range (dial max) survives the dialog apply", ok, true)


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
