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


const SUPPORT := preload("res://tests/support.gd")
const P: String = "inspector_drawer_roundtrip_test"


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
	all_passed = _eq("String hosts the toggle_row drawer", VariableDialog._drawer_kinds_for_type("String"), PackedStringArray(["toggle_row"])) and all_passed
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

	# --- A TYPED row list (Array[Dictionary]) hosts the grid exactly as the untyped one does. It reaches
	# the drawer as TYPE_ARRAY either way, so the marker, the lift and the re-emission all match; a list
	# typed to a non-Dictionary element cannot hold rows, so it still degrades to a plain field. ---
	var typed_table_var: LocalVariable = LocalVariable.new()
	typed_table_var.name = "loot"
	typed_table_var.type_name = "Array[Dictionary]"
	typed_table_var.default_value = []
	typed_table_var.exported = true
	typed_table_var.attributes = {"drawer": "table", "table_columns": [{"name": "item", "type": "String"}, {"name": "count", "type": "int"}]}
	var typed_table_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,count=int\") var loot: Array[Dictionary] = []"
	all_passed = _eq("a typed row list emits the table marker",
		SheetCompiler._emit_tree_variable_line(typed_table_var), typed_table_expected) and all_passed
	all_passed = _eq("table on a list typed to a NON-row element emits no marker",
		_emit_for("Array[int]", [], {"drawer": "table", "table_columns": [{"name": "hp", "type": "int"}]}).contains("eventsheet:"), false) and all_passed
	var typed_table_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + typed_table_expected + "\n")
	var typed_table_lifted: LocalVariable = _find(typed_table_sheet, "loot")
	all_passed = _eq("the lift keeps the typed row list's element type",
		typed_table_lifted.type_name if typed_table_lifted != null else "", "Array[Dictionary]") and all_passed
	all_passed = _eq("the lift recovers a typed row list's columns",
		(typed_table_lifted.attributes as Dictionary).get("table_columns") if typed_table_lifted != null else null,
		[{"name": "item", "type": "String"}, {"name": "count", "type": "int"}]) and all_passed
	if typed_table_lifted != null:
		all_passed = _eq("a typed table var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(typed_table_lifted), typed_table_expected) and all_passed
	all_passed = _eq("Array[Dictionary] hosts the table drawer",
		VariableDialog._drawer_kinds_for_type("Array[Dictionary]"), PackedStringArray(["table"])) and all_passed
	all_passed = _eq("a scalar typed list hosts no drawer",
		VariableDialog._drawer_kinds_for_type("Array[int]"), PackedStringArray()) and all_passed

	# Plain typed lists round-trip byte-exact, and carry Inspector grouping like any other exported var.
	all_passed = _type_roundtrip("Array[int]", "@export var scores: Array[int] = []", "scores") and all_passed
	all_passed = _type_roundtrip("Array[String]", "@export var names: Array[String] = []", "names") and all_passed
	var grouped_typed: LocalVariable = LocalVariable.new()
	grouped_typed.name = "scores"
	grouped_typed.type_name = "Array[int]"
	grouped_typed.default_value = []
	grouped_typed.exported = true
	grouped_typed.attributes = {"group": "Scoring", "subgroup": "Totals"}
	all_passed = _eq("a typed list carries its Inspector group and subgroup",
		SheetCompiler._tree_variable_group_prefix(grouped_typed),
		"@export_group(\"Scoring\")\n@export_subgroup(\"Totals\")\n") and all_passed
	var table_grid: EventSheetDrawerWidgets.DrawerTable = EventSheetDrawerWidgets.DrawerTable.new([{"name": "hp", "type": "int"}])
	table_grid.set_value([{"hp": 5}, {"hp": 9}])
	table_grid._on_move_up(1)
	all_passed = _eq("the grid's move-up swaps rows", table_grid.get_value(), [{"hp": 9}, {"hp": 5}]) and all_passed
	table_grid._on_remove(0)
	all_passed = _eq("the grid's remove drops the row", table_grid.get_value(), [{"hp": 5}]) and all_passed
	table_grid._on_add_row()
	all_passed = _eq("the grid's add appends typed defaults", table_grid.get_value(), [{"hp": 5}, {"hp": 0}]) and all_passed
	table_grid.free()

	# --- Enum columns: a String column constrained to a fixed choice list, rendered as a dropdown.
	# The stored cell value stays a plain String; only the marker gains an enum(a|b|c) token. The `|`
	# option delimiter avoids every reserved marker char, so the whole thing round-trips byte-for-byte.
	# Options decode to {key, label} pairs - the same shape an ACE param's options use, so one
	# convention covers both. An unlabeled option is its own label, which is what every option
	# written before labels existed is.
	all_passed = _eq("the enum codec decodes an option list",
		SheetCompiler.table_enum_options("enum(circle|ring|rect)"),
		[{"key": "circle", "label": "circle"}, {"key": "ring", "label": "ring"}, {"key": "rect", "label": "rect"}]) and all_passed
	all_passed = _eq("the enum codec ignores a non-enum token",
		SheetCompiler.table_enum_options("String"), []) and all_passed
	all_passed = _eq("the enum codec ignores a malformed token (no closing paren)",
		SheetCompiler.table_enum_options("enum(circle|ring"), []) and all_passed
	all_passed = _eq("the enum codec re-encodes an option list",
		SheetCompiler.table_enum_type(["circle", "ring", "rect"]), "enum(circle|ring|rect)") and all_passed

	# ── Labeled options: the cell READS English and STORES a token ──
	# The separator is `=`, and the reason it is safe is that a bare `=` has ALWAYS been rejected
	# inside an option, so no marker written before labels existed can contain one. That makes the
	# pair form unambiguous against every file already on disk with no escape character at all -
	# which matters, because "~" is legal in an option today and the marker rides inside a
	# double-quoted GDScript literal that the importer reads by scanning to the NEXT quote.
	all_passed = _eq("a labeled option decodes into key and label",
		SheetCompiler.table_enum_options("enum(gte=>= (at least)|lt=< (less than))"),
		[{"key": "gte", "label": ">= (at least)"}, {"key": "lt", "label": "< (less than)"}]) and all_passed
	all_passed = _eq("and re-encodes to exactly what it came from",
		SheetCompiler.table_enum_type([{"key": "gte", "label": ">= (at least)"}, {"key": "lt", "label": "< (less than)"}]),
		"enum(gte=>= (at least)|lt=< (less than))") and all_passed
	# THE byte-compatibility guarantee: a label that merely repeats its key emits BARE, so every one
	# of the 76 shipped packs re-emits identically and the drift gate stays at zero.
	all_passed = _eq("a label that repeats its key emits bare",
		SheetCompiler.table_enum_type([{"key": "circle", "label": "circle"}]), "enum(circle)") and all_passed
	all_passed = _eq("decode then encode is the identity for an unlabeled token",
		SheetCompiler.table_enum_type(SheetCompiler.table_enum_options("enum(gte|gt|lte|lt|eq|neq)")),
		"enum(gte|gt|lte|lt|eq|neq)") and all_passed
	# A label may hold `=` and parentheses (only the FINAL `)` is consumed by the wrapper strip), but
	# never `,` `|` `:` or `"` - each of those breaks a specific split, so such an option degrades to
	# its bare key rather than emitting a marker that would parse into garbage.
	# The four characters a label cannot carry literally are escaped, so a label is never truncated
	# and never degrades. Each escape exists for a split the marker depends on.
	all_passed = _eq("a comma in a label cannot split the column list",
		SheetCompiler.table_enum_type([{"key": "gte", "label": "at least, or more"}]),
		"enum(gte=at least~2C or more)") and all_passed
	all_passed = _eq("and comes back whole",
		SheetCompiler.table_enum_options("enum(gte=at least~2C or more)"),
		[{"key": "gte", "label": "at least, or more"}]) and all_passed
	all_passed = _eq("a quote can never reach the GDScript literal it lives in",
		SheetCompiler.table_enum_type([{"key": "gte", "label": "say \"hi\""}]),
		"enum(gte=say ~22hi~22)") and all_passed
	all_passed = _eq("a pipe cannot split the option list",
		SheetCompiler.table_enum_type([{"key": "a", "label": "x|y"}]), "enum(a=x~7Cy)") and all_passed
	all_passed = _eq("a colon cannot split the marker segments",
		SheetCompiler.table_enum_type([{"key": "a", "label": "x:y"}]), "enum(a=x~3Ay)") and all_passed
	# The tilde is NEVER escaped, which is what keeps the sequence list closed and the codec
	# idempotent: if the lead-in were escapable, two spellings would collapse to one value and the
	# importer's byte gate would turn a working grid into a verbatim block on the next open.
	all_passed = _eq("a bare tilde stays literal text",
		SheetCompiler.table_enum_type(SheetCompiler.table_enum_options("enum(a=fast~ish)")),
		"enum(a=fast~ish)") and all_passed
	for tricky: String in ["at least, or more", "say \"hi\"", "x|y", "x:y", "~ish", ">= (at least)"]:
		all_passed = _eq("`%s` survives a full round-trip" % tricky,
			SheetCompiler.table_enum_label(SheetCompiler.table_enum_options(
				SheetCompiler.table_enum_type([{"key": "k", "label": tricky}]))[0]), tricky) and all_passed
	# ── A comparison operator has to survive as a plain STORED VALUE ──
	# `=` is the pair separator, so a naive split ate every operator that contains one: declaring
	# enum(==|!=|<|<=|>|>=) kept only `<` and `>`, and the UHTN Plan Resource shipped exactly that
	# declaration. An `=` only separates when BOTH sides stand on their own, so `<=` fails that test
	# and falls through to being the bare key it looks like.
	for operator: String in ["==", "!=", "<", "<=", ">", ">="]:
		all_passed = _eq("`%s` survives as a stored value" % operator,
			SheetCompiler.table_enum_type(SheetCompiler.table_enum_options("enum(%s)" % operator)),
			"enum(%s)" % operator) and all_passed
	all_passed = _eq("the whole operator set round-trips",
		SheetCompiler.table_enum_type(SheetCompiler.table_enum_options("enum(==|!=|<|<=|>|>=)")),
		"enum(==|!=|<|<=|>|>=)") and all_passed
	# The self-check that makes the grammar safe rather than merely clever: an entry is written only
	# if reading it back yields the key it started from. `a=b` would come back as the PAIR {a, b},
	# so it is refused instead of being written as something that means something else on the way in.
	all_passed = _eq("a key that would read back as a pair is refused",
		SheetCompiler.table_enum_type([{"key": "a=b", "label": "a=b"}]), "") and all_passed
	# A key carrying `=` keeps its value and loses the wording, rather than losing the choice.
	all_passed = _eq("an operator key cannot also be labeled",
		SheetCompiler.table_enum_type([{"key": ">=", "label": "at least"}]), "enum(>=)") and all_passed

	# The reader helpers an extension uses, and the reason the drawer needs them: display and data
	# used to be the SAME string, so a label would have been persisted into the designer's .tres.
	all_passed = _eq("the key is what gets stored",
		SheetCompiler.table_enum_key({"key": "gte", "label": ">= (at least)"}), "gte") and all_passed
	all_passed = _eq("the label is what gets shown",
		SheetCompiler.table_enum_label({"key": "gte", "label": ">= (at least)"}), ">= (at least)") and all_passed
	all_passed = _eq("a plain string still reads as both",
		SheetCompiler.table_enum_key("circle"), "circle") and all_passed
	# A fresh row seeds the first option's KEY, never its label - nothing re-validates a stored cell.
	all_passed = _eq("a new row seeds the key, not the label",
		EventSheetDrawerWidgets.DrawerTable._default_for(
			{"name": "op", "type": "enum", "options": [{"key": "gte", "label": ">= (at least)"}]}), "gte") and all_passed
	var enum_var: LocalVariable = LocalVariable.new()
	enum_var.name = "steps"
	enum_var.type_name = "Array"
	enum_var.default_value = []
	enum_var.exported = true
	enum_var.attributes = {"drawer": "table", "table_columns": [{"name": "kind", "type": "enum", "options": ["circle", "ring", "rect"]}, {"name": "x", "type": "float"}]}
	var enum_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:kind=enum(circle|ring|rect),x=float\") var steps: Array = []"
	all_passed = _eq("an enum column emits its option list in the marker",
		SheetCompiler._emit_tree_variable_line(enum_var), enum_expected) and all_passed
	var enum_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + enum_expected + "\n")
	var enum_lifted: LocalVariable = _find(enum_sheet, "steps")
	all_passed = _eq("the lift recovers the enum column as {type:enum, options}",
		(enum_lifted.attributes as Dictionary).get("table_columns") if enum_lifted != null else null,
		[{"name": "kind", "type": "enum", "options": [
			{"key": "circle", "label": "circle"}, {"key": "ring", "label": "ring"}, {"key": "rect", "label": "rect"}]},
			{"name": "x", "type": "float"}]) and all_passed
	if enum_lifted != null:
		all_passed = _eq("an enum column re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(enum_lifted), enum_expected) and all_passed
	all_passed = _eq("the editor parse recovers an enum column (options captured)",
		EventSheetAttributeDrawers.parse_table_columns("kind=enum(circle|ring),x=float"),
		[{"name": "kind", "type": "enum", "options": [
			{"key": "circle", "label": "circle"}, {"key": "ring", "label": "ring"}]},
			{"name": "x", "type": "float"}]) and all_passed
	var enum_grid: EventSheetDrawerWidgets.DrawerTable = EventSheetDrawerWidgets.DrawerTable.new([{"name": "kind", "type": "enum", "options": ["circle", "ring"]}])
	enum_grid._on_add_row()
	all_passed = _eq("a fresh enum row seeds the first option", enum_grid.get_value(), [{"kind": "circle"}]) and all_passed
	enum_grid.free()

	# --- Color columns: a String cell shown as a swatch (ColorPickerButton). The stored value stays a
	# plain hex String, so the marker just gains a bare "color" type token that round-trips verbatim.
	var color_var: LocalVariable = LocalVariable.new()
	color_var.name = "steps"
	color_var.type_name = "Array"
	color_var.default_value = []
	color_var.exported = true
	color_var.attributes = {"drawer": "table", "table_columns": [{"name": "tint", "type": "color"}, {"name": "x", "type": "float"}]}
	var color_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:tint=color,x=float\") var steps: Array = []"
	all_passed = _eq("a color column emits its bare type token",
		SheetCompiler._emit_tree_variable_line(color_var), color_expected) and all_passed
	var color_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + color_expected + "\n")
	var color_lifted: LocalVariable = _find(color_sheet, "steps")
	all_passed = _eq("the lift recovers the color column verbatim",
		(color_lifted.attributes as Dictionary).get("table_columns") if color_lifted != null else null,
		[{"name": "tint", "type": "color"}, {"name": "x", "type": "float"}]) and all_passed
	if color_lifted != null:
		all_passed = _eq("a color column re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(color_lifted), color_expected) and all_passed
	all_passed = _eq("the editor parse keeps a color column",
		EventSheetAttributeDrawers.parse_table_columns("tint=color,x=float"),
		[{"name": "tint", "type": "color"}, {"name": "x", "type": "float"}]) and all_passed
	var color_grid: EventSheetDrawerWidgets.DrawerTable = EventSheetDrawerWidgets.DrawerTable.new([{"name": "tint", "type": "color"}])
	color_grid._on_add_row()
	all_passed = _eq("a fresh color row seeds a valid hex String", color_grid.get_value(), [{"tint": "#ffffff"}]) and all_passed
	color_grid.free()

	# A drawer on a CLAMPED var (setter-suffixed "= 120:" line): the drawer must survive the lift -
	# the expression-default emission previously quoted the suffix and the extraction verify failed,
	# stranding the drawer as a verbatim hint (found by the Inspector Designer over EnemyStats).
	var clamped_source: String = "extends Resource\n\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:200\") var hp: int = 120:\n\tset(value):\n\t\thp = clampi(value, 0, 200)\n"
	var clamped_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(clamped_source)
	var clamped_var: LocalVariable = _find(clamped_sheet, "hp")
	all_passed = _eq("a clamped var keeps its drawer through the lift",
		str((clamped_var.attributes as Dictionary).get("drawer", "")) if clamped_var != null else "missing", "progress_bar") and all_passed
	clamped_sheet.external_source_path = "user://clamped_drawer_roundtrip.gd"
	all_passed = _eq("the clamped drawer file round-trips byte-identically",
		str(SheetCompiler.compile(clamped_sheet, "user://clamped_drawer_roundtrip.gd").get("output", "")), clamped_source) and all_passed

	# --- The toggle-button row: a String's fixed choices as one row of toggle buttons; the choices
	# ride the marker INSTEAD of @export_enum and round-trip into editable toggle_options.
	var toggle_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:easy,normal,hard\") var difficulty: String = \"normal\""
	all_passed = _eq("toggle_row emits its marker (choices ride along)",
		_emit_for_named("difficulty", "String", "normal", {"drawer": "toggle_row", "toggle_options": ["easy", "normal", "hard"]}), toggle_expected) and all_passed
	# An int hosts the same row of buttons, storing the option's INDEX (the way a plain enum int reads).
	all_passed = _eq("toggle_row on an int emits the same marker (the int stores the index)",
		_emit_for_named("caps", "int", 2, {"drawer": "toggle_row", "toggle_options": ["None", "Square", "Round"]}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:None,Square,Round\") var caps: int = 2") and all_passed
	all_passed = _eq("toggle_row on a Vector2 emits no marker",
		_emit_for("Vector2", Vector2(0, 0), {"drawer": "toggle_row", "toggle_options": ["a"]}).contains("eventsheet:"), false) and all_passed
	all_passed = _eq("toggle_row without choices emits no marker",
		_emit_for("String", "", {"drawer": "toggle_row"}).contains("eventsheet:"), false) and all_passed
	var toggle_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + toggle_expected + "\n")
	var toggle_lifted: LocalVariable = _find(toggle_sheet, "difficulty")
	all_passed = _eq("the lift recovers the toggle choices",
		(toggle_lifted.attributes as Dictionary).get("toggle_options") if toggle_lifted != null else null, ["easy", "normal", "hard"]) and all_passed
	if toggle_lifted != null:
		all_passed = _eq("a toggle_row var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(toggle_lifted), toggle_expected) and all_passed
	var toggle_widget: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(PackedStringArray(["easy", "normal", "hard"]))
	toggle_widget.set_value("hard")
	all_passed = _eq("the toggle row stores the pressed value", toggle_widget.get_value(), "hard") and all_passed
	toggle_widget.set_value("nonsense")
	all_passed = _eq("a value outside the set stays (never clobbered)", toggle_widget.get_value(), "nonsense") and all_passed
	toggle_widget.free()

	# --- Inline validation (# @inspector_validate <function>): the editor calls the named sheet
	# function while the property is edited and shows the returned warning String above the field.
	var validate_var: LocalVariable = LocalVariable.new()
	validate_var.name = "spawn_gap"
	validate_var.type_name = "Vector2"
	validate_var.default_value = "Vector2(8.0, 20.0)"
	validate_var.expression_default = true
	validate_var.exported = true
	validate_var.attributes = {"required": true, "validate": "check_spawn_gap"}
	var validate_expected: String = "# @inspector_required\n# @inspector_validate check_spawn_gap\n@export var spawn_gap: Vector2 = Vector2(8.0, 20.0)"
	all_passed = _eq("validate emits its marker after required",
		SheetCompiler._emit_tree_variable_line(validate_var), validate_expected) and all_passed
	all_passed = _eq("a non-identifier validator emits nothing",
		_emit_for("int", 1, {"validate": "not a function()"}).contains("@inspector_validate"), false) and all_passed
	var validate_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + validate_expected + "\n")
	var validate_lifted: LocalVariable = _find(validate_sheet, "spawn_gap")
	all_passed = _eq("the lift recovers the validator name",
		str((validate_lifted.attributes as Dictionary).get("validate", "")) if validate_lifted != null else "missing", "check_spawn_gap") and all_passed
	if validate_lifted != null:
		all_passed = _eq("a validated var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(validate_lifted), validate_expected) and all_passed
	all_passed = _eq("the decor map carries the validator",
		EventSheetAttributeDrawers.build_decor_map("extends Node\n\n# @inspector_validate check_hp\n@export var hp: int = 1\n").get("hp"),
		[{"kind": "validate", "function": "check_hp"}]) and all_passed

	# --- The field button (# @inspector_action <function> <Label>): a small button rendered with
	# the property that calls a sheet function on click; label optional (defaults to the function).
	var action_var: LocalVariable = LocalVariable.new()
	action_var.name = "stats_seed"
	action_var.type_name = "int"
	action_var.default_value = 0
	action_var.exported = true
	action_var.attributes = {"action": "reroll_stats", "action_label": "Reroll"}
	var action_expected: String = "# @inspector_action reroll_stats Reroll\n@export var stats_seed: int = 0"
	all_passed = _eq("the field button emits its marker (function + label)",
		SheetCompiler._emit_tree_variable_line(action_var), action_expected) and all_passed
	all_passed = _eq("a label-less field button emits just the function",
		_emit_for("int", 0, {"action": "reroll_stats"}), "# @inspector_action reroll_stats\n@export var v: int = 0") and all_passed
	all_passed = _eq("a non-identifier action emits nothing",
		_emit_for("int", 0, {"action": "do it()"}).contains("@inspector_action"), false) and all_passed
	var action_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + action_expected + "\n")
	var action_lifted: LocalVariable = _find(action_sheet, "stats_seed")
	all_passed = _eq("the lift recovers the action function + label",
		[str((action_lifted.attributes as Dictionary).get("action", "")), str((action_lifted.attributes as Dictionary).get("action_label", ""))] if action_lifted != null else [],
		["reroll_stats", "Reroll"]) and all_passed
	if action_lifted != null:
		all_passed = _eq("a field-button var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(action_lifted), action_expected) and all_passed
	all_passed = _eq("the decor map carries the action (with label)",
		EventSheetAttributeDrawers.build_decor_map("extends Node\n\n# @inspector_action reroll_stats Reroll\n@export var s: int = 0\n").get("s"),
		[{"kind": "action", "function": "reroll_stats", "label": "Reroll"}]) and all_passed

	# The dict-var path emits the same decor lines (one canonical shape across both variable paths).
	var dict_sheet: EventSheetResource = EventSheetResource.new()
	dict_sheet.variables = {"speed": {"type": "int", "default": 5, "exported": true, "attributes": {"header": "Motion", "info": "Tiles per second."}}}
	var dict_output: String = str(SheetCompiler.compile(dict_sheet, "user://decor_dict.gd").get("output", ""))
	all_passed = _eq("dict-path variables emit the same decor lines",
		dict_output.contains("# @inspector_header Motion\n# @inspector_info Tiles per second.\n@export var speed: int = 5"), true) and all_passed

	# Edit cycle: re-confirming a Vector2 dial variable must keep its range (the dial's max magnitude); the
	# apply previously gated range on is_numeric, dropping it for Vector2 and resetting the dial to max 100.
	all_passed = _vector_dial_range_persists() and all_passed

	# Forgiving Range parse (progressive disclosure): a bare max, min+max, or min+max+step all parse; a
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

	all_passed = _unit_drawer() and all_passed
	all_passed = _toggle_icons() and all_passed

	return all_passed


# ── The unit drawer: a float and the unit it is read in ────────────────────────
#
## The conversions, the marker, the lift, and THE PROMISE: switching the dropdown moves the reading
## and never the stored number, so the emitted GDScript is the same before and after.
static func _unit_drawer() -> bool:
	var passed: bool = true

	# Conversion by value, one family at a time. Every conversion runs through the family's base.
	passed = _near("a quarter turn is 90 degrees", EventSheetDrawerWidgets.convert_unit("turn", "deg", 0.25), 90.0) and passed
	passed = _near("90 degrees is a quarter turn", EventSheetDrawerWidgets.convert_unit("deg", "turn", 90.0), 0.25) and passed
	passed = _near("PI radians is 180 degrees", EventSheetDrawerWidgets.convert_unit("rad", "deg", PI), 180.0) and passed
	passed = _near("180 degrees is PI radians", EventSheetDrawerWidgets.convert_unit("deg", "rad", 180.0), PI) and passed
	passed = _near("a quarter second is 250 ms", EventSheetDrawerWidgets.convert_unit("s", "ms", 0.25), 250.0) and passed
	passed = _near("500 ms is half a second", EventSheetDrawerWidgets.convert_unit("ms", "s", 500.0), 0.5) and passed
	# The project's own physics rate answers for "frames" - derived, never a hard-coded 60.
	passed = _near("one second is the project's physics rate in frames",
		EventSheetDrawerWidgets.convert_unit("s", "frames", 1.0), EventSheetDrawerWidgets.physics_rate()) and passed
	passed = _near("a full amplitude is 0 dB", EventSheetDrawerWidgets.convert_unit("fraction", "db", 1.0), 0.0) and passed
	passed = _near("0 dB is a full amplitude", EventSheetDrawerWidgets.convert_unit("db", "fraction", 0.0), 1.0) and passed
	passed = _near("half amplitude is about -6 dB", EventSheetDrawerWidgets.convert_unit("fraction", "db", 0.5), -6.0206) and passed
	passed = _near("silence reads as the dB floor, never negative infinity",
		EventSheetDrawerWidgets.convert_unit("fraction", "db", 0.0), EventSheetDrawerWidgets.SILENCE_DB) and passed
	# The project's viewport width answers for "screen"; a world unit IS a pixel in Godot 2D.
	passed = _near("half a screen is half the project's viewport width in pixels",
		EventSheetDrawerWidgets.convert_unit("screen", "px", 0.5), EventSheetDrawerWidgets.screen_unit_pixels() * 0.5) and passed
	passed = _near("a world unit is a pixel", EventSheetDrawerWidgets.convert_unit("world", "px", 2.0), 2.0) and passed
	# Units that do not share a family (and a pack's own words) are labels: the number is untouched.
	passed = _near("degrees do not convert into seconds", EventSheetDrawerWidgets.convert_unit("deg", "s", 5.0), 5.0) and passed
	passed = _near("a pack's own words leave the number alone", EventSheetDrawerWidgets.convert_unit("tiles", "chunks", 3.0), 3.0) and passed
	passed = _eq("a pack's own word belongs to no family", EventSheetDrawerWidgets.unit_family("tiles"), "") and passed
	passed = _eq("a known unit names its family", EventSheetDrawerWidgets.unit_family("turn"), "angle") and passed
	passed = _eq("an unknown unit is its own label", EventSheetDrawerWidgets.unit_label("tiles"), "tiles") and passed

	# The marker's grammar, and its store fallback.
	passed = _eq("the marker parses into units + the stored one",
		EventSheetAttributeDrawers.parse_unit_spec("kinds=px|world|screen,store=world"),
		{"units": PackedStringArray(["px", "world", "screen"]), "store": "world"}) and passed
	passed = _eq("a marker naming no store falls back to the first unit",
		str(EventSheetAttributeDrawers.parse_unit_spec("kinds=deg|turn|rad").get("store", "")), "deg") and passed
	passed = _eq("a marker naming a store it does not list falls back to the first unit",
		str(EventSheetAttributeDrawers.parse_unit_spec("kinds=s|ms,store=frames").get("store", "")), "s") and passed
	# The short spelling a card schema's field uses: a FAMILY'S name is that family, in its own
	# order, with its first unit as the stored one.
	passed = _eq("a family's name is the whole family",
		EventSheetAttributeDrawers.parse_unit_spec("time"),
		{"units": PackedStringArray(["s", "ms", "frames"]), "store": "s"}) and passed
	passed = _eq("and every shipped family answers to its own name",
		EventSheetAttributeDrawers.parse_unit_spec("level"),
		{"units": PackedStringArray(["db", "fraction"]), "store": "db"}) and passed
	passed = _eq("a spelling that names units keeps naming them, family word or not",
		EventSheetAttributeDrawers.parse_unit_spec("kinds=deg|turn,store=turn"),
		{"units": PackedStringArray(["deg", "turn"]), "store": "turn"}) and passed
	passed = _eq("a word that is no family and lists nothing names no units at all",
		EventSheetAttributeDrawers.parse_unit_spec("tiles"),
		{"units": PackedStringArray(), "store": ""}) and passed

	# THE PROMISE, on the widget: the dropdown moves the reading, not the value.
	var field: EventSheetDrawerWidgets.DrawerUnitField = EventSheetDrawerWidgets.DrawerUnitField.new(PackedStringArray(["deg", "turn", "rad"]), "deg")
	var emitted: Array = []
	field.value_changed.connect(func(value: float) -> void: emitted.append(value))
	field.set_value(90.0)
	passed = _near("the field shows the stored value in the stored unit", field.get_shown_value(), 90.0) and passed
	field.set_view_unit("turn")
	passed = _near("switching the unit re-reads the number", field.get_shown_value(), 0.25) and passed
	passed = _near("switching the unit does not move the stored value", field.get_value(), 90.0) and passed
	passed = _eq("switching the unit emits nothing (the file cannot move)", emitted.size(), 0) and passed
	field._on_spin_changed(0.5)
	passed = _near("typing in the shown unit stores the converted value", field.get_value(), 180.0) and passed
	passed = _eq("typing emits exactly one change", emitted.size(), 1) and passed
	passed = _near("the emitted value is in the STORED unit", float(emitted[0]) if not emitted.is_empty() else -1.0, 180.0) and passed
	field.free()

	# Emission + the byte-exact lift back.
	var unit_expected: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=px|world|screen,store=world\") var thickness: float = 2.0"
	passed = _eq("unit emits its marker (the units and the stored one ride along)",
		_emit_for_named("thickness", "float", 2.0, {"drawer": "unit", "unit_kinds": ["px", "world", "screen"], "unit_store": "world"}),
		unit_expected) and passed
	passed = _eq("unit falls back to the first listed unit as the stored one",
		_emit_for_named("start_angle", "float", 0.0, {"drawer": "unit", "unit_kinds": ["deg", "turn", "rad"]}),
		"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=deg|turn|rad,store=deg\") var start_angle: float = 0.0") and passed
	passed = _eq("unit on an int emits no marker",
		_emit_for("int", 2, {"drawer": "unit", "unit_kinds": ["px"]}).contains("eventsheet:"), false) and passed
	passed = _eq("unit without a unit list emits no marker",
		_emit_for("float", 1.0, {"drawer": "unit"}).contains("eventsheet:"), false) and passed
	passed = _roundtrip("unit", unit_expected, "thickness", "unit") and passed
	var unit_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + unit_expected + "\n")
	var unit_lifted: LocalVariable = _find(unit_sheet, "thickness")
	passed = _eq("the lift recovers the unit list",
		(unit_lifted.attributes as Dictionary).get("unit_kinds") if unit_lifted != null else null, ["px", "world", "screen"]) and passed
	passed = _eq("the lift recovers the stored unit",
		str((unit_lifted.attributes as Dictionary).get("unit_store", "")) if unit_lifted != null else "", "world") and passed
	if unit_lifted != null:
		passed = _eq("a unit var re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(unit_lifted), unit_expected) and passed

	# The look, its one field, and the round trip through the dialog's grammar.
	passed = _eq("float offers the unit look", _look_ids_for("float").has("unit"), true) and passed
	passed = _eq("int does not offer the unit look (the stored number is a float)",
		_look_ids_for("int").has("unit"), false) and passed
	passed = _eq("the look's field parses the marker's own spelling",
		VariableDialog._parse_unit_detail("kinds=s|ms|frames, store=s"),
		{"units": ["s", "ms", "frames"], "store": "s"}) and passed
	passed = _eq("the look's field parses the shorthand a designer types",
		VariableDialog._parse_unit_detail("deg|turn|rad, store=deg"),
		{"units": ["deg", "turn", "rad"], "store": "deg"}) and passed
	passed = _eq("an empty field lands the length units",
		VariableDialog._parse_unit_detail(""), {"units": ["px", "world", "screen"], "store": "world"}) and passed
	passed = _eq("the field rebuilds from a lifted variable's attributes",
		VariableDialog._unit_detail_text({"unit_kinds": ["px", "world", "screen"], "unit_store": "world"}),
		"kinds=px|world|screen, store=world") and passed

	# The gallery tile draws the real field, so the picture cannot drift from the drawer.
	var tile: Control = EventSheetInspectorLooks.build_preview("unit")
	passed = _eq("the gallery tile for the unit look is the real field",
		tile is EventSheetDrawerWidgets.DrawerUnitField, true) and passed
	tile.free()
	return passed


# ── Toggle buttons: a picture per option, and the segmented word strip ─────────────
#
## The icon source (a path pattern or a registered renderer), the segmented word strip, and the
## int form where the button's INDEX is the stored value.
static func _toggle_icons() -> bool:
	var passed: bool = true

	# The marker's optional tails, in their fixed order. The icon source is rejoined because a
	# res:// path carries colons the marker split apart.
	var icon_marker: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:None,Square,Round:segmented:icons=res://art/cap_%s.svg\") var caps: String = \"Round\""
	passed = _eq("toggle_row emits its icon source and the segmented tail",
		_emit_for_named("caps", "String", "Round", {
			"drawer": "toggle_row", "toggle_options": ["None", "Square", "Round"],
			"toggle_segmented": true, "toggle_icons": "res://art/cap_%s.svg",
		}), icon_marker) and passed
	passed = _eq("the marker's tails parse back (the path's own colons survive)",
		EventSheetAttributeDrawers.parse_toggle_spec(["None,Square,Round", "segmented", "icons=res", "//art/cap_%s.svg"]),
		{"options": PackedStringArray(["None", "Square", "Round"]), "segmented": true, "icons": "res://art/cap_%s.svg"}) and passed
	passed = _eq("a plain option list parses with no tails",
		EventSheetAttributeDrawers.parse_toggle_spec(["easy,normal,hard"]),
		{"options": PackedStringArray(["easy", "normal", "hard"]), "segmented": false, "icons": ""}) and passed
	var icon_sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + icon_marker + "\n")
	var icon_lifted: LocalVariable = _find(icon_sheet, "caps")
	passed = _eq("the lift recovers the icon source",
		str((icon_lifted.attributes as Dictionary).get("toggle_icons", "")) if icon_lifted != null else "",
		"res://art/cap_%s.svg") and passed
	passed = _eq("the lift recovers the segmented tail",
		bool((icon_lifted.attributes as Dictionary).get("toggle_segmented", false)) if icon_lifted != null else false, true) and passed
	if icon_lifted != null:
		passed = _eq("an icon toggle_row re-emits byte-identically",
			SheetCompiler._emit_tree_variable_line(icon_lifted), icon_marker) and passed

	# Provider lookup: a pack that can only DRAW its options registers a renderer by name.
	var drawn: PlaceholderTexture2D = PlaceholderTexture2D.new()
	var asked: Array = []
	EventSheets.register_toggle_icon_provider("test:cap", func(option: String, size: int) -> Texture2D:
		asked.append("%s@%d" % [option, size])
		return drawn
	)
	passed = _eq("a registered renderer is found by name",
		EventSheets.toggle_icon_provider_for("test:cap").is_valid(), true) and passed
	passed = _eq("an unregistered name finds no renderer",
		EventSheets.toggle_icon_provider_for("test:missing").is_valid(), false) and passed
	passed = _eq("a source that is not a path pattern asks the renderer",
		EventSheetDrawerWidgets.toggle_icon_for("test:cap", "Round", 24) == drawn, true) and passed
	passed = _eq("the renderer is asked for the option at the icon size", asked, ["Round@24"]) and passed
	passed = _eq("an unregistered source draws no icon (the button keeps its word)",
		EventSheetDrawerWidgets.toggle_icon_for("test:missing", "Round", 24), null) and passed
	passed = _eq("a path pattern with no file behind it draws no icon",
		EventSheetDrawerWidgets.toggle_icon_for("res://art/no_such_cap_%s.svg", "Round", 24), null) and passed
	EventSheets.unregister_toggle_icon_provider("test:cap")
	passed = _eq("unregistering removes the renderer",
		EventSheets.toggle_icon_provider_for("test:cap").is_valid(), false) and passed

	# The row itself: the picture replaces the word, and the word becomes the tooltip.
	EventSheets.register_toggle_icon_provider("test:cap", func(_option: String, _size: int) -> Texture2D: return drawn)
	var icon_row: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(PackedStringArray(["None", "Square", "Round"]), "test:cap")
	var first: Button = icon_row.get_child(0) as Button
	passed = _eq("an icon button shows no text", first.text, "") and passed
	passed = _eq("an icon button says its option in the tooltip", first.tooltip_text, "None") and passed
	icon_row.set_value("Round")
	passed = _eq("the pressed icon button is the one whose OPTION matches",
		(icon_row.get_child(2) as Button).button_pressed, true) and passed
	passed = _eq("the unpressed icon buttons stay unpressed", first.button_pressed, false) and passed
	icon_row.free()
	EventSheets.unregister_toggle_icon_provider("test:cap")

	# Segmented: a handful of word options joined into one strip; past that, ordinary buttons.
	var strip: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(PackedStringArray(["Flat", "Billboard", "Volumetric"]), "", true)
	passed = _eq("a segmented row joins its buttons into one strip",
		strip.get_theme_constant("separation"), 0) and passed
	passed = _eq("a segmented row keeps its words", (strip.get_child(0) as Button).text, "Flat") and passed
	strip.free()
	var too_many: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(PackedStringArray(["a", "b", "c", "d", "e", "f"]), "", true)
	passed = _eq("past a handful of options the segmented strip falls back to ordinary buttons",
		too_many.get_theme_constant("separation"), 2) and passed
	too_many.free()
	return passed


static func _look_ids_for(type_name: String) -> Array:
	var ids: Array = []
	for preset: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		ids.append(str(preset.get("id")))
	return ids


## A float pin, both sides rounded to the fourth decimal so the last bit of a conversion does not
## decide a test. Reported through the ONE assertion file, like every other pin in the suite.
static func _near(label: String, actual: float, expected: float) -> bool:
	return SUPPORT.check(P, label, _rounded(actual), _rounded(expected))


static func _rounded(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0


static func _vector_dial_range_persists() -> bool:
	var dlg: VariableDialog = VariableDialog.new()
	var parent: Node = Node.new()
	dlg.init_dialog(parent)
	dlg.set_sheet_provider(func() -> Variant: return null)
	var captured: Dictionary = {}
	dlg.variable_confirmed.connect(func(_n: String, _t: String, _d: Variant, _s: String, _c: Dictionary, _k: bool, _e: bool, _o: PackedStringArray, attributes: Dictionary, _onready: bool, _st: bool) -> void:
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


static func _emit_for_named(var_name: String, type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var lv: LocalVariable = LocalVariable.new()
	lv.name = var_name
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
	return SUPPORT.check(P, label, actual, expected)


## The `_eq` pin for a line whose TAIL is a default-value spelling this test does not fix (a Vector2
## writes its own `Vector2(...)` text): the HEAD of the line is compared, as a value, through the one
## reporter the runner and the report tool parse.
static func _starts(label: String, actual: String, prefix: String) -> bool:
	return SUPPORT.check(P, label, actual.substr(0, prefix.length()), prefix)
