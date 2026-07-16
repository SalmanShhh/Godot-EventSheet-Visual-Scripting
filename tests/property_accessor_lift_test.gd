# EventForge - a GDScript PROPERTY (a `var …:` declaration with `set(value):` and/or `get:` accessor
# blocks - https://school.gdquest.com/glossary/setter_getter) reads as a first-class variable row with its
# accessors, instead of a code wall. It maps onto the condition/action model: the variable identity IS the
# row, and each accessor folds under it as a condition/action child (`set(value)` / `get` in the condition
# cell, its body as actions). Emit: the declaration gains a `:` suffix and the accessor blocks emit beneath
# it (canonical set-then-get). The lift is byte-gated - a property whose re-emission does not reproduce the
# source (odd spacing, getter-before-setter) stays a verbatim block. Pins: emit, both-accessors and
# one-accessor round-trips, the language-block rendering with accessor children, and a degrade case.
@tool
class_name PropertyAccessorLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Forward emit: both accessors, canonical set-then-get ──
	var prop: LocalVariable = LocalVariable.new()
	prop.name = "health"
	prop.type_name = "int"
	prop.default_value = 100
	prop.setter_body = "health = clampi(value, 0, max_health)\nhealth_changed.emit(health)"
	prop.getter_body = "return health"
	ok = _check("a full property emits declaration + set + get",
		SheetCompiler._emit_tree_variable_line(prop),
		"var health: int = 100:\n\tset(value):\n\t\thealth = clampi(value, 0, max_health)\n\t\thealth_changed.emit(health)\n\tget:\n\t\treturn health") and ok
	ok = _check("has_property_accessors is true", prop.has_property_accessors(), true) and ok

	# ── Round-trip: a full property lifts and re-emits byte-identically ──
	ok = _roundtrips("both accessors",
		"extends Node\n\nvar health: int = 100:\n\tset(value):\n\t\thealth = clampi(value, 0, 100)\n\tget:\n\t\treturn health\n", true, true) and ok
	# ── Setter-only ("does one job") ──
	ok = _roundtrips("setter only",
		"extends Node\n\nvar score: int = 0:\n\tset(value):\n\t\tscore = value\n\t\tscore_label.text = str(value)\n", true, false) and ok
	# ── Getter-only ──
	ok = _roundtrips("getter only",
		"extends Node\n\nvar elapsed: float = 0.0:\n\tget:\n\t\treturn Time.get_ticks_msec() / 1000.0\n", false, true) and ok
	# ── An @export property (Inspector + accessors together) ──
	ok = _roundtrips("exported property",
		"extends Node\n\n@export var speed: float = 1.0:\n\tset(value):\n\t\tspeed = maxf(value, 0.0)\n", true, false) and ok
	# ── A custom setter parameter name is preserved ──
	ok = _roundtrips("custom setter param",
		"extends Node\n\nvar mode: int = 0:\n\tset(new_mode):\n\t\tmode = new_mode\n", true, false) and ok

	# ── Rendering: a property reads as a language block with accessor children ──
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\nvar health: int = 100:\n\tset(value):\n\t\thealth = clampi(value, 0, 100)\n\tget:\n\t\treturn health\n")
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var prop_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and str(row_data.row_uid).begins_with("variable_tree_") and not row_data.children.is_empty():
			prop_row = row_data
	ok = _check("the property renders as a variable row with children", prop_row != null, true) and ok
	if prop_row != null:
		ok = _check("the property row is flagged a language block", prop_row.language_block, true) and ok
		ok = _check("it has a set and a get accessor child", prop_row.children.size(), 2) and ok
		ok = _check("the set accessor reads in the condition cell",
			_lane_text(prop_row.children[0], "condition"), "set(value)") and ok
		ok = _check("the get accessor reads in the condition cell",
			_lane_text(prop_row.children[1], "condition"), "get") and ok
		ok = _check("an accessor child is inert (source null)", prop_row.children[0].source_resource == null, true) and ok

	# ── Degrade: a getter-before-setter (non-canonical order) does NOT lift as a structured property - the
	# accessor bodies stay a verbatim block (no setter_body/getter_body recovered) and it round-trips. ──
	var odd: String = "extends Node\n\nvar v: int = 0:\n\tget:\n\t\treturn v\n\tset(value):\n\t\tv = value\n"
	var odd_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(odd)
	var odd_var: LocalVariable = _find_var(odd_sheet, "v")
	ok = _check("a getter-before-setter property has NO structured accessors (stays verbatim)",
		odd_var == null or not odd_var.has_property_accessors(), true) and ok
	odd_sheet.external_source_path = "user://prop_odd.gd"
	ok = _check("the non-canonical property still round-trips byte-identically",
		str(SheetCompiler.compile(odd_sheet, "user://prop_odd.gd").get("output", "")) == odd, true) and ok

	# ── Authoring: the dialog carries the accessor bodies in its attributes payload; the receiver copies
	# them onto the variable's first-class fields (and a blank body clears the accessor). ──
	var authored: LocalVariable = LocalVariable.new()
	authored.name = "hp"
	EventSheetVariablesManager._apply_property_accessors(authored, {"setter_body": "hp = value", "getter_body": "return hp", "setter_param": "value"})
	ok = _check("the receiver applies a setter body", authored.setter_body, "hp = value") and ok
	ok = _check("the receiver applies a getter body", authored.getter_body, "return hp") and ok
	ok = _check("the authored property emits with accessors",
		SheetCompiler._emit_tree_variable_line(authored).contains("set(value):") and SheetCompiler._emit_tree_variable_line(authored).contains("get:"), true) and ok
	EventSheetVariablesManager._apply_property_accessors(authored, {})
	ok = _check("clearing the bodies removes the accessors", authored.has_property_accessors(), false) and ok

	dock.free()
	return ok


static func _roundtrips(label: String, src: String, want_set: bool, want_get: bool) -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	var prop_name: String = _first_prop_name(src)
	var lifted: LocalVariable = _find_var(sheet, prop_name)
	ok = _check("%s: the property lifted to a variable" % label, lifted != null, true) and ok
	if lifted != null:
		ok = _check("%s: setter presence" % label, not lifted.setter_body.strip_edges().is_empty(), want_set) and ok
		ok = _check("%s: getter presence" % label, not lifted.getter_body.strip_edges().is_empty(), want_get) and ok
	sheet.external_source_path = "user://prop_rt.gd"
	var rt: String = str(SheetCompiler.compile(sheet, "user://prop_rt.gd").get("output", ""))
	ok = _check("%s: round-trips byte-identically" % label, rt == src, true) and ok
	if rt != src:
		print("  --- src ---\n%s\n  --- rt ---\n%s" % [src, rt])
	return ok


static func _first_prop_name(src: String) -> String:
	for line: String in src.split("\n"):
		var trimmed: String = line.strip_edges()
		var body: String = trimmed.trim_prefix("@export ").trim_prefix("var ")
		if trimmed.begins_with("var ") or trimmed.begins_with("@export var "):
			return body.split(":")[0].strip_edges()
	return ""


static func _find_var(sheet: EventSheetResource, name: String) -> LocalVariable:
	for ev: Variant in sheet.events:
		if ev is LocalVariable and (ev as LocalVariable).name == name:
			return ev as LocalVariable
	return null


static func _lane_text(row: EventRowData, lane: String) -> String:
	for span: SemanticSpan in row.spans:
		if span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane")) == lane:
			return str(span.text)
	return "<none>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] property_accessor_lift_test: %s" % label)
		return true
	print("[FAIL] property_accessor_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
