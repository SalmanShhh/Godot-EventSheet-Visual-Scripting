# EventForge - Godot documentation comments on functions: a plain `##` block above a function (brief +
# description, BBCode allowed - per https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
# gdscript_documentation_comments.html) now lifts onto EventFunction.doc_comment and re-emits above the
# function, so a documented helper opens as an editable function with its docs instead of a stray comment
# block. It rides the SAME leading-annotation machinery as @rpc, byte-gated: the doc is stored without the
# `## ` prefix and emitted topmost (above the `## @ace` block and any `@rpc`). Distinct from the `@ace`
# exposure description. Pins: emit, a documented-helper round-trip (incl. BBCode + a blank doc line + an
# @rpc together), and that a plain function has no doc.
@tool
class_name FunctionDocCommentTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Forward emit: doc_comment emits as `## …` topmost (a blank line -> bare `##`) ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "clamp01"
	fn.return_type = TYPE_FLOAT
	fn.lifted_unannotated = true  # a plain helper: no @ace block, so the doc is the only ## text
	fn.doc_comment = "Clamps [code]v[/code] to 0-1.\n\nHandy for [b]bars[/b]."
	var p: ACEParam = ACEParam.new()
	p.id = "v"
	p.type_name = "float"
	fn.params = [p]
	fn.events = [_return_row("clampf(v, 0.0, 1.0)")]
	sheet.functions = [fn]
	var emitted: String = SheetCompiler.emit_function_block_text(fn, sheet)
	ok = _check("doc emits as ## lines above the func, blank -> bare ##",
		emitted.begins_with("## Clamps [code]v[/code] to 0-1.\n##\n## Handy for [b]bars[/b].\nfunc clamp01("), true) and ok

	# ── Round-trip: a documented plain helper lifts with its doc and re-emits byte-identically ──
	var src: String = "@tool\nextends Node\n\n\n## Clamps the value.\n## BBCode [i]works[/i].\nfunc clamp01(v: float) -> float:\n\treturn clampf(v, 0.0, 1.0)\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	var lifted: EventFunction = _first_function(imported)
	ok = _check("the documented helper lifted", lifted != null, true) and ok
	if lifted != null:
		ok = _check("its doc comment is captured (prefix stripped)", lifted.doc_comment, "Clamps the value.\nBBCode [i]works[/i].") and ok
	ok = _roundtrips("documented helper", src) and ok

	# ── A doc comment AND an @rpc together (doc topmost, then @rpc, then func) ──
	ok = _roundtrips("doc + @rpc",
		"@tool\nextends Node\n\n\n## Broadcasts damage.\n@rpc(\"any_peer\")\nfunc take_damage(amount: int) -> void:\n\thealth -= amount\n") and ok

	# ── A plain (undocumented) function has an empty doc comment ──
	var plain: EventSheetResource = GDScriptImporter.new().import_external_source("@tool\nextends Node\n\n\nfunc plain() -> void:\n\treturn\n")
	var plain_fn: EventFunction = _first_function(plain)
	ok = _check("a plain function has no doc comment", plain_fn != null and plain_fn.doc_comment.is_empty(), true) and ok

	return ok


static func _return_row(value: String) -> EventRow:
	var ev: EventRow = EventRow.new()
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "ReturnValue"
	act.params = {"value": value}
	ev.actions.append(act)
	return ev


static func _roundtrips(label: String, src: String) -> bool:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	imported.external_source_path = "user://doc_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://doc_rt.gd").get("output", ""))
	if rt != src:
		print("  --- src ---\n%s\n  --- rt ---\n%s" % [src, rt])
	return _check("%s: round-trips byte-identically" % label, rt == src, true)


static func _first_function(sheet: EventSheetResource) -> EventFunction:
	for f: Variant in sheet.functions:
		if f is EventFunction:
			return f as EventFunction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_doc_comment_test: %s" % label)
		return true
	print("[FAIL] function_doc_comment_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
