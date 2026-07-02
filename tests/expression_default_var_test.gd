# EventForge — a tree variable whose default is a bare GDScript EXPRESSION (Vector2.ZERO, Color.RED,
# Type.CONST) now lifts into a first-class State row instead of stranding as a GDScript block. Before,
# the parser stored `Vector2.ZERO` as a String and the emitter re-quoted it (`= "Vector2.ZERO"`), so
# the byte-verify failed and it stayed raw. The importer now flags an unquoted-expression default so
# it re-emits verbatim (byte-verify gated). Pins: the emitter branch, the importer detection over a
# real pack, that a genuine String literal is NOT mis-flagged, and drift=0.
@tool
extends RefCounted
class_name ExpressionDefaultVarTest

static func run() -> bool:
	var ok: bool = true

	# ── The emitter renders a flagged expression default verbatim, a literal quoted ──
	var expr_var: LocalVariable = LocalVariable.new()
	expr_var.name = "_base"
	expr_var.type_name = "Vector2"
	expr_var.default_value = "Vector2.ZERO"
	expr_var.expression_default = true
	ok = _check("a flagged expression default emits verbatim (unquoted)",
		SheetCompiler._emit_tree_variable_line(expr_var), "var _base: Vector2 = Vector2.ZERO") and ok
	var string_var: LocalVariable = LocalVariable.new()
	string_var.name = "label"
	string_var.type_name = "String"
	string_var.default_value = "hello"  # a genuine String literal — must stay quoted
	ok = _check("an unflagged String default stays quoted",
		SheetCompiler._emit_tree_variable_line(string_var), "var label: String = \"hello\"") and ok

	# ── Importer detection: an unquoted-expression source default is flagged; a quoted one isn't ──
	var lifted_expr: LocalVariable = GDScriptImporter.new()._try_lift_variable("var _base: Vector2 = Vector2.ZERO")
	ok = _check("an unquoted Vector2.ZERO default lifts (not a raw block)", lifted_expr != null, true) and ok
	ok = _check("…and is flagged as an expression default",
		lifted_expr != null and lifted_expr.expression_default, true) and ok
	ok = _check("the value is kept as the bare expression",
		str(lifted_expr.default_value) if lifted_expr != null else "", "Vector2.ZERO") and ok
	var lifted_string: LocalVariable = GDScriptImporter.new()._try_lift_variable("var greeting: String = \"hi\"")
	ok = _check("a quoted String default is NOT flagged as an expression",
		lifted_string != null and not lifted_string.expression_default, true) and ok
	ok = _check("engine-constant defaults lift too (Color.RED)",
		GDScriptImporter.new()._try_lift_variable("var tint: Color = Color.RED") != null, true) and ok

	# ── Over a REAL pack (juice): its private Vector2 state vars now lift, none stay raw, drift=0 ──
	var pack_path: String = "res://eventsheet_addons/juice/juice_behavior.gd"
	var source: String = FileAccess.get_file_as_string(pack_path)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var raw_var_blocks: int = 0
	var expr_defaults: int = 0
	for row: Variant in sheet.events:
		if row is LocalVariable and (row as LocalVariable).expression_default:
			expr_defaults += 1
		elif row is RawCodeRow:
			var stripped: String = (row as RawCodeRow).code.strip_edges()
			if stripped.begins_with("var ") or stripped.begins_with("@export"):
				raw_var_blocks += 1
	ok = _check("juice lifts its expression-default state vars", expr_defaults > 5, true) and ok
	ok = _check("no `var` block stays raw in juice", raw_var_blocks, 0) and ok
	sheet.external_source_path = pack_path
	var reemitted: String = str(SheetCompiler.compile(sheet, pack_path).get("output", ""))
	ok = _check("juice round-trips byte-identically", reemitted == source, true) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] expression_default_var_test: %s" % label)
		return true
	print("[FAIL] expression_default_var_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
