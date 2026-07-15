# EventForge (gap G4) - a leading GDScript annotation (`@rpc`, `@warning_ignore`, `@abstract`, stacked) above
# a function no longer blocks it from lifting. The annotation lines are kept VERBATIM on the EventFunction
# (annotation_lines) and re-emitted between the `## @ace_*` block and the `func` header, so a `@rpc`
# multiplayer method opens as an editable function instead of a raw block. It is the repo's established
# verbatim-plus-byte-gate pattern (like export_hint / return_type_name): any shape that cannot reproduce its
# source degrades to a raw block, never corrupt.
@tool
class_name FunctionAnnotationLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A trailing @rpc helper lifts with its annotation captured, and round-trips ──
	var rpc_src: String = "@tool\nextends Node\n\n\n@rpc(\"any_peer\", \"call_local\", \"reliable\")\nfunc take_damage(amount: int) -> void:\n\thealth -= amount\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(rpc_src)
	var fn: EventFunction = _first_function(imported)
	ok = _check("the @rpc function lifted to an EventFunction", fn != null, true) and ok
	if fn != null:
		ok = _check("the @rpc line is captured verbatim",
			fn.annotation_lines.size() == 1 and fn.annotation_lines[0] == "@rpc(\"any_peer\", \"call_local\", \"reliable\")", true) and ok
		ok = _check("the function keeps its name", fn.function_name, "take_damage") and ok
	ok = _roundtrips("trailing @rpc helper", rpc_src) and ok

	# ── Stacked annotations keep source order ──
	var stacked_src: String = "@tool\nextends Node\n\n\n@rpc(\"any_peer\")\n@warning_ignore(\"unused_parameter\")\nfunc ping(id: int) -> void:\n\treturn\n"
	var stacked_imported: EventSheetResource = GDScriptImporter.new().import_external_source(stacked_src)
	var stacked_fn: EventFunction = _first_function(stacked_imported)
	ok = _check("a stacked-annotation function lifted", stacked_fn != null, true) and ok
	if stacked_fn != null:
		ok = _check("both annotation lines captured in order",
			stacked_fn.annotation_lines.size() == 2 and stacked_fn.annotation_lines[0] == "@rpc(\"any_peer\")" and stacked_fn.annotation_lines[1] == "@warning_ignore(\"unused_parameter\")", true) and ok
	ok = _roundtrips("stacked annotations", stacked_src) and ok

	# ── Exposed function + @rpc together: author it, compile (canonical `## @ace` block then `@rpc` then
	# `func`), then re-open - both the exposure and the annotation survive, and it recompiles byte-exact. ──
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node"
	var afn: EventFunction = EventFunction.new()
	afn.function_name = "fire"
	afn.expose_as_ace = true
	afn.ace_display_name = "Fire"
	afn.ace_category = "Net"
	afn.annotation_lines = PackedStringArray(["@rpc(\"any_peer\")"])
	var body_event: EventRow = EventRow.new()
	var ret: ACEAction = ACEAction.new()
	ret.provider_id = "Core"
	ret.ace_id = "ReturnEarly"
	body_event.actions.append(ret)
	afn.events = [body_event]
	authored.functions = [afn]
	var comp: String = str(SheetCompiler.compile(authored, "user://fa_authored.gd").get("output", ""))
	# The `@rpc` line emits AFTER the `## @ace` block and BEFORE the `func` header (the GDScript convention).
	ok = _check("the emitted order is `## @ace` then `@rpc` then `func`",
		comp.contains("## @ace") and comp.find("@rpc(\"any_peer\")") < comp.find("func fire(") and comp.find("## @ace") < comp.find("@rpc(\"any_peer\")"), true) and ok
	# Re-opening that canonical output and re-emitting reproduces it byte-for-byte (the covenant on the
	# combined `## @ace` + `@rpc` shape).
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(comp)
	reimported.external_source_path = "user://fa_authored_rt.gd"
	ok = _check("the authored exposed+@rpc function round-trips byte-identically",
		str(SheetCompiler.compile(reimported, "user://fa_authored_rt.gd").get("output", "")) == comp, true) and ok

	# ── Regression: a plain function with no annotation lifts with an empty annotation_lines ──
	var plain_src: String = "@tool\nextends Node\n\n\nfunc plain() -> void:\n\treturn\n"
	var plain_imported: EventSheetResource = GDScriptImporter.new().import_external_source(plain_src)
	var plain_fn: EventFunction = _first_function(plain_imported)
	ok = _check("a plain function still lifts", plain_fn != null, true) and ok
	if plain_fn != null:
		ok = _check("a plain function has no annotation lines", plain_fn.annotation_lines.is_empty(), true) and ok
	ok = _roundtrips("plain function (regression)", plain_src) and ok

	return ok


static func _roundtrips(label: String, src: String) -> bool:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(src)
	imported.external_source_path = "user://fa_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://fa_rt.gd").get("output", ""))
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
		print("[PASS] function_annotation_lift_test: %s" % label)
		return true
	print("[FAIL] function_annotation_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
