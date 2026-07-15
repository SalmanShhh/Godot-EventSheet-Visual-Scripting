# EventForge (gap G4, BUILD-partial) - a methods-bearing inner class (`class X:` with methods, not only data)
# reads as a foldable, READ-ONLY class block: the class in the condition cell, its fields (read-only) and a
# `ƒ name(params) -> Type` chip per method as child rows, instead of a raw GDScript wall. It is a PURE VIEW
# over an unchanged RawCodeRow (the compiler never sees a structured nested class), byte-gated by
# methods_class_lifts, and disjoint from the pure-data class view (which requires ZERO methods). This pins the
# recognizer, the byte-exact model round-trip, and the collapsed rendering; the .gd round-trip is untouched.
@tool
class_name MethodsClassLiftTest
extends RefCounted

const WEAPON := "class Weapon:\n\tvar ammo: int = 6\n\tvar max_ammo: int = 6\n\tfunc fire() -> void:\n\t\tammo -= 1\n\tfunc reload() -> void:\n\t\tammo = max_ammo"


static func run() -> bool:
	var ok: bool = true

	# ── The recognizer, and its disjointness from the pure-data view ──
	ok = _check("a field+method class is recognised", ViewportRowBuilder.methods_class_name(WEAPON), "Weapon") and ok
	ok = _check("the same class is NOT a pure-data class (disjoint)", ViewportRowBuilder.data_class_name(WEAPON), "") and ok
	ok = _check("a pure-data class is NOT a methods class (disjoint)",
		ViewportRowBuilder.methods_class_name("class Foo:\n\tvar x: int = 0"), "") and ok
	ok = _check("an `extends` base is tolerated",
		ViewportRowBuilder.methods_class_name("class Bar extends RefCounted:\n\tfunc go() -> void:\n\t\tpass"), "Bar") and ok
	ok = _check("a nested class rejects",
		ViewportRowBuilder.methods_class_name("class Foo:\n\tfunc a() -> void:\n\t\tpass\n\tclass Inner:\n\t\tvar x: int = 0"), "") and ok
	ok = _check("trailing top-level code rejects",
		ViewportRowBuilder.methods_class_name("class Foo:\n\tfunc a() -> void:\n\t\tpass\nprint(1)"), "") and ok
	ok = _check("a method-less (pass-only) class is not a methods class",
		ViewportRowBuilder.methods_class_name("class Foo:\n\tpass"), "") and ok

	# ── The byte-gate: the model re-emits the whole class (methods as verbatim raw) byte-for-byte ──
	var model: Dictionary = ViewportRowBuilder.parse_methods_class(WEAPON)
	ok = _check("the model names the class", str(model.get("class_name")), "Weapon") and ok
	ok = _check("emit reproduces the source byte-for-byte", ViewportRowBuilder.emit_data_class(model), WEAPON) and ok
	ok = _check("methods_class_lifts gates it true", ViewportRowBuilder.methods_class_lifts(WEAPON), true) and ok
	# Blank lines between methods and a `##` doc above a method survive verbatim.
	var spaced: String = "class Kit:\n\tvar n: int = 0\n\t## does a thing\n\tfunc a() -> void:\n\t\tpass\n\n\tfunc b() -> void:\n\t\tpass"
	ok = _check("blank lines + a doc comment round-trip", ViewportRowBuilder.methods_class_lifts(spaced), true) and ok

	# ── Rendering over a synthetic opened sheet ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = WEAPON
	sheet.events.append(raw)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var class_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is RawCodeRow and str(row_data.row_uid).begins_with("methods_class_"):
			class_row = row_data
	ok = _check("the sheet shows a methods-class block", class_row != null, true) and ok
	if class_row != null:
		ok = _check("it collapses to one header line", class_row.line_count, 1) and ok
		ok = _check("the header shows the class in the condition cell",
			str(class_row.spans[0].text) == "class Weapon" and str((class_row.spans[0].metadata as Dictionary).get("lane")) == "condition", true) and ok
		# 2 fields + 2 methods = 4 child rows.
		ok = _check("fields and methods render as child rows", class_row.children.size(), 4) and ok
		var method_child: EventRowData = _first_method_child(class_row)
		ok = _check("a method renders as a read-only ƒ chip",
			method_child != null and str(method_child.spans[0].text).begins_with("ƒ fire(") and method_child.source_resource == null, true) and ok
		ok = _check("the block keeps its RawCodeRow (double-click opens code)", class_row.source_resource is RawCodeRow, true) and ok

	# ── Covenant: a pure view - the raw code is untouched, so it re-emits byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(sheet, "user://mc_rt.gd").get("output", ""))
	ok = _check("the sheet re-emits the class verbatim (drift-safe)", reemitted.contains(WEAPON), true) and ok

	# ── Degrade: a class with a bare one-tab statement is not a clean class -> not lifted (stays a plain block) ──
	ok = _check("a class with a stray one-tab statement does not lift",
		ViewportRowBuilder.methods_class_lifts("class Foo:\n\tfunc a() -> void:\n\t\tpass\n\tx = 5"), false) and ok

	dock.free()
	return ok


static func _first_method_child(class_row: EventRowData) -> EventRowData:
	for child: EventRowData in class_row.children:
		if str(child.row_uid).begins_with("methods_class_method_"):
			return child
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] methods_class_lift_test: %s" % label)
		return true
	print("[FAIL] methods_class_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
