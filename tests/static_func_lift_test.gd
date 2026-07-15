# EventForge (gap G3) - a `static func` round-trips as a first-class editable EventFunction instead of a raw
# block. On emit, EventFunction.is_static prepends `static ` at the (single, shared) function-header emitter;
# on lift, the header regex accepts an optional `static ` prefix and sets is_static, and the four
# `begins_with("func ")` gates (importer chunker, trailing-run classifier, mid-file anchor, declaration
# splitter) also admit `static func `. Everything is byte-gated: a static func whose model does not re-emit
# to its exact source (e.g. a return-type-less `static func foo():`) degrades to a verbatim block, and a
# plain non-static func still lifts with is_static == false (the regex-index-shift guard).
@tool
class_name StaticFuncLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Forward emit: is_static toggles the `static ` prefix at the shared header emitter ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "clamp01"
	fn.return_type = TYPE_FLOAT
	var p: ACEParam = ACEParam.new()
	p.id = "v"
	p.type_name = "float"
	fn.params = [p]
	fn.is_static = true
	# (A fresh un-exposed function emits a leading `## @ace_hidden` line, so match on the header line itself.)
	var static_text: String = SheetCompiler.emit_function_block_text(fn, sheet)
	ok = _check("is_static emits a `static func` header",
		static_text.contains("static func clamp01(v: float) -> float:"), true) and ok
	fn.is_static = false
	var plain_text: String = SheetCompiler.emit_function_block_text(fn, sheet)
	ok = _check("is_static false emits a plain `func` header (no leaked `static`)",
		plain_text.contains("func clamp01(v: float) -> float:") and not plain_text.contains("static func"), true) and ok

	# ── Reverse round-trip: an unannotated static helper lifts to an EventFunction and re-emits exactly ──
	var src: String = "@tool\nextends Node\n\n\nstatic func clamp01(v: float) -> float:\n\treturn clampf(v, 0.0, 1.0)\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	var lifted: EventFunction = _first_function(imported)
	ok = _check("the static helper lifted to an EventFunction", lifted != null, true) and ok
	if lifted != null:
		ok = _check("the lifted function is flagged static", lifted.is_static, true) and ok
		ok = _check("the lifted function keeps its name", lifted.function_name, "clamp01") and ok
		ok = _check("an unannotated helper lifts as un-exposed", lifted.lifted_unannotated, true) and ok
	imported.external_source_path = "user://sf_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://sf_rt.gd").get("output", ""))
	ok = _check("the static func round-trips byte-identically", roundtrip == src, true) and ok
	if roundtrip != src:
		print("  --- src ---\n%s\n  --- rt ---\n%s" % [src, roundtrip])

	# ── A plain (non-static) helper still lifts, with is_static == false (index-shift guard) ──
	var plain_src: String = "@tool\nextends Node\n\n\nfunc clamp01(v: float) -> float:\n\treturn clampf(v, 0.0, 1.0)\n"
	var plain_imported: EventSheetResource = GDScriptImporter.new().import_external_source(plain_src)
	var plain_lifted: EventFunction = _first_function(plain_imported)
	ok = _check("a plain func still lifts after the regex widening", plain_lifted != null, true) and ok
	if plain_lifted != null:
		ok = _check("a plain func is NOT flagged static", plain_lifted.is_static, false) and ok

	# ── A return-type-less static func stays a raw block (same rule as return-type-less plain funcs) ──
	var no_ret: String = "@tool\nextends Node\n\n\nstatic func tick():\n\tpass\n"
	var no_ret_imported: EventSheetResource = GDScriptImporter.new().import_external_source(no_ret)
	ok = _check("a return-type-less static func does NOT lift", _first_function(no_ret_imported) == null, true) and ok
	ok = _check("...and stays a verbatim `static func` block", _has_raw_beginning(no_ret_imported, "static func tick"), true) and ok
	no_ret_imported.external_source_path = "user://sf_noret.gd"
	ok = _check("the un-lifted static func round-trips byte-identically",
		str(SheetCompiler.compile(no_ret_imported, "user://sf_noret.gd").get("output", "")) == no_ret, true) and ok

	# ── Non-canonical `static  func` (two spaces) never matches -> stays raw, round-trips ──
	var two_space: String = "@tool\nextends Node\n\n\nstatic  func clamp01(v: float) -> float:\n\treturn v\n"
	var two_space_imported: EventSheetResource = GDScriptImporter.new().import_external_source(two_space)
	ok = _check("a two-space `static  func` does NOT lift", _first_function(two_space_imported) == null, true) and ok
	two_space_imported.external_source_path = "user://sf_2sp.gd"
	ok = _check("the two-space form round-trips byte-identically",
		str(SheetCompiler.compile(two_space_imported, "user://sf_2sp.gd").get("output", "")) == two_space, true) and ok

	return ok


static func _first_function(sheet: EventSheetResource) -> EventFunction:
	for f: Variant in sheet.functions:
		if f is EventFunction:
			return f as EventFunction
	return null


static func _has_raw_beginning(sheet: EventSheetResource, needle: String) -> bool:
	for ev: Variant in sheet.events:
		if ev is RawCodeRow and (ev as RawCodeRow).code.contains(needle):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] static_func_lift_test: %s" % label)
		return true
	print("[FAIL] static_func_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
