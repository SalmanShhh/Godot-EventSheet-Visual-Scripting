# EventForge - a class-level `static var` opens as a first-class editable variable row instead of a
# verbatim block. On emit, LocalVariable.is_static emits `static var` in the plain-var branch (mutually
# exclusive with @export/@onready/const); on lift, `_try_lift_variable` strips a `static ` prefix (mirroring
# @onready) and flags is_static, gated by the existing emit-and-compare so a static var that cannot re-emit
# to its exact source (e.g. an untyped `static var x = 5`) degrades to a verbatim block, never corrupt.
@tool
class_name StaticVarLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Forward emit ──
	var count_var: LocalVariable = LocalVariable.new()
	count_var.name = "count"
	count_var.type_name = "int"
	count_var.default_value = 0
	count_var.is_static = true
	ok = _check("a static int var emits `static var`",
		SheetCompiler._emit_tree_variable_line(count_var), "static var count: int = 0") and ok

	var origin_var: LocalVariable = LocalVariable.new()
	origin_var.name = "origin"
	origin_var.type_name = "Vector2"
	origin_var.default_value = "Vector2.ZERO"
	origin_var.expression_default = true
	origin_var.is_static = true
	ok = _check("a static expression-default var emits verbatim",
		SheetCompiler._emit_tree_variable_line(origin_var), "static var origin: Vector2 = Vector2.ZERO") and ok

	# A non-static var is unchanged (regression guard on the shared else-branch).
	var plain_var: LocalVariable = LocalVariable.new()
	plain_var.name = "count"
	plain_var.type_name = "int"
	plain_var.default_value = 0
	ok = _check("a non-static var emits a plain `var` (no leaked static)",
		SheetCompiler._emit_tree_variable_line(plain_var), "var count: int = 0") and ok

	# ── Reverse round-trip: two static vars lift to editable rows and re-emit exactly ──
	var src: String = "@tool\nextends Node\n\nstatic var count: int = 0\nstatic var origin: Vector2 = Vector2.ZERO\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	var statics: Array = _static_vars(imported)
	ok = _check("both static vars lifted to editable rows", statics.size(), 2) and ok
	if statics.size() == 2:
		ok = _check("the first lifted var is flagged static", (statics[0] as LocalVariable).is_static, true) and ok
		ok = _check("the first lifted var keeps its name", (statics[0] as LocalVariable).name, "count") and ok
	imported.external_source_path = "user://sv_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://sv_rt.gd").get("output", ""))
	ok = _check("the static vars round-trip byte-identically", roundtrip == src, true) and ok
	if roundtrip != src:
		print("  --- src ---\n%s\n  --- rt ---\n%s" % [src, roundtrip])

	# ── Regression: a plain var still lifts, not flagged static ──
	var plain_src: String = "@tool\nextends Node\n\nvar count: int = 0\n"
	var plain_imported: EventSheetResource = GDScriptImporter.new().import_external_source(plain_src)
	var plain_lifted: Array = _all_local_vars(plain_imported)
	ok = _check("a plain var still lifts", plain_lifted.size(), 1) and ok
	if plain_lifted.size() == 1:
		ok = _check("a plain var is NOT flagged static", (plain_lifted[0] as LocalVariable).is_static, false) and ok

	# ── Regression (review e8362aa): a static var with an inline setter tail must NOT lift (the accessor
	# body would be orphaned and the `0:` default would recompile to invalid GDScript). Stays verbatim. ──
	var setter: String = "@tool\nextends Node\n\nstatic var health: int = 0:\n\tset(value):\n\t\thealth = value\n"
	var setter_imported: EventSheetResource = GDScriptImporter.new().import_external_source(setter)
	ok = _check("a static var with a setter tail does NOT lift", _all_local_vars(setter_imported).is_empty(), true) and ok
	setter_imported.external_source_path = "user://sv_setter.gd"
	ok = _check("the setter-property static var round-trips byte-identically",
		str(SheetCompiler.compile(setter_imported, "user://sv_setter.gd").get("output", "")) == setter, true) and ok

	# ── Degrade safety: an untyped `static var x = 5` cannot re-emit exactly -> stays a verbatim block ──
	var untyped: String = "@tool\nextends Node\n\nstatic var x = 5\n"
	var untyped_imported: EventSheetResource = GDScriptImporter.new().import_external_source(untyped)
	ok = _check("an untyped static var does NOT lift (byte-gate degrades it)",
		_static_vars(untyped_imported).is_empty(), true) and ok
	untyped_imported.external_source_path = "user://sv_untyped.gd"
	ok = _check("the un-lifted untyped static var round-trips byte-identically",
		str(SheetCompiler.compile(untyped_imported, "user://sv_untyped.gd").get("output", "")) == untyped, true) and ok

	ok = _reads_as_shared_by_every_object() and ok
	return ok


## A `static var` belongs to the CLASS, so the row says so: "Static number spawned = 0  shared by
## every Player". Reading a static var as an ordinary variable hides the one thing about it that
## matters - that every object of the type reads and writes the same value.
static func _reads_as_shared_by_every_object() -> bool:
	var ok: bool = true
	var source: String = "@tool\nclass_name StaticReadingProbe\nextends Node\n\nstatic var spawned: int = 0\nvar hp: int = 3\n"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://static_reading_probe.gd"
	sheet.read_only = true
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	var static_texts: PackedStringArray = PackedStringArray()
	var plain_texts: PackedStringArray = PackedStringArray()
	var walked: Array[EventRowData] = []
	for entry: Dictionary in view.get_flat_rows():
		_collect_rows(entry.get("row"), walked)
	for row: EventRowData in walked:
		if not (row.source_resource is LocalVariable):
			continue
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row.spans:
			texts.append(span.text)
		if (row.source_resource as LocalVariable).is_static:
			static_texts = texts
		else:
			plain_texts = texts
	ok = _check("a static var reads as Static, and says who shares it",
		static_texts, PackedStringArray(["x", "Static", "whole number", "spawned", "=", "0", "shared by every StaticReadingProbe",
		"static var spawned: int = 0"])) and ok
	ok = _check("an ordinary variable reads with its own scope word and none of the static note",
		plain_texts, PackedStringArray(["x", "Instance", "whole number", "hp", "=", "3", "var hp: int = 3"])) and ok
	view.free()
	return ok


static func _collect_rows(row: Variant, into: Array[EventRowData]) -> void:
	if not (row is EventRowData):
		return
	into.append(row as EventRowData)
	for child: EventRowData in (row as EventRowData).children:
		_collect_rows(child, into)


static func _static_vars(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for ev: Variant in sheet.events:
		if ev is LocalVariable and (ev as LocalVariable).is_static:
			out.append(ev)
	return out


static func _all_local_vars(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for ev: Variant in sheet.events:
		if ev is LocalVariable:
			out.append(ev)
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] static_var_lift_test: %s" % label)
		return true
	print("[FAIL] static_var_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
