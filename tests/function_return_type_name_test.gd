# EventForge - EventFunction.return_type_name: a function can declare a return type a Variant.Type
# can't name (a custom class, an engine class, a typed collection). The emitter uses it verbatim, the
# empty-body stub falls back to `return null` (valid for any object/collection), and the "Ships as:"
# signature formatter honours it - so a Studio-authored verb returning `-> Node2D` round-trips. The
# reverse AUTO-LIFT of such a helper stays OFF (a mid-file private helper would reorder the file and
# fail the byte-verify), so this pins the FORWARD primitive + the drift=0 baseline is unregressed.
@tool
class_name FunctionReturnTypeNameTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The emitter uses the name verbatim, and it wins over return_type ──
	var custom: EventFunction = EventFunction.new()
	custom.function_name = "nearest_enemy"
	custom.return_type = TYPE_NIL          # would be "void"…
	custom.return_type_name = "Node2D"     # …but the name overrides it
	ok = _check("the return-type name wins over return_type", SheetCompiler._function_return_type_name(custom), "Node2D") and ok
	ok = _check("a bodiless custom-return function stubs `return null`", SheetCompiler._empty_function_stub(custom), "\treturn null") and ok
	ok = _check("the Ships-as signature honours it",
		EventSheetFunctionDialog.format_signature("nearest_enemy", TYPE_NIL, []).ends_with("-> void"), true) and ok

	# An empty name leaves the normal Variant.Type path untouched.
	var normal: EventFunction = EventFunction.new()
	normal.function_name = "is_dead"
	normal.return_type = TYPE_BOOL
	ok = _check("an empty name keeps the Variant.Type behaviour", SheetCompiler._function_return_type_name(normal), "bool") and ok

	# ── A sheet with a custom-return verb round-trips through the external path ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.tool_mode = true
	sheet.external_source_path = "user://_rtn_test.gd"
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "make_pool"
	verb.return_type_name = "HealthPool"
	verb.expose_as_ace = true
	verb.ace_display_name = "Make Pool"
	sheet.functions.append(verb)
	var output: String = str(SheetCompiler.compile(sheet, "user://_rtn_test.gd").get("output", ""))
	ok = _check("the emitted signature carries the custom return", output.contains("func make_pool() -> HealthPool:"), true) and ok
	ok = _check("its empty body is `return null`", output.contains("func make_pool() -> HealthPool:\n\treturn null"), true) and ok
	# Re-import → re-emit must be byte-identical (the round-trip the covenant guarantees).
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	reopened.external_source_path = "user://_rtn_test.gd"
	var reemitted: String = str(SheetCompiler.compile(reopened, "user://_rtn_test.gd").get("output", ""))
	ok = _check("a custom-return verb round-trips byte-identically", reemitted == output, true) and ok

	# ── The whole generated script parses (custom class names don't break the load) ──
	var script: GDScript = GDScript.new()
	script.source_code = "class HealthPool:\n\tvar amount: float = 0.0\n\n" + output.substr(output.find("func make_pool"))
	ok = _check("the generated function parses with the custom class in scope", script.reload() == OK, true) and ok

	# The static formatter honours a custom return type when handed one (the "Ships as:" strip).
	ok = _check("format_signature honours a passed custom return type",
		EventSheetFunctionDialog.format_signature("make_pool", TYPE_NIL, [], "HealthPool").ends_with("-> HealthPool"), true) and ok

	ok = _check_dialog_preserves_custom_return() and ok

	return ok


## Slice 2c: the Function dialog SHOWS, EDITS, and PRESERVES a not-carded return type. Fixtures mirror the
## IMPORTER's real state (ace_lifter.gd): a custom class lifts as (TYPE_MAX, name); a builtin Variant type
## with no dialog card - Color / Array / Dictionary - lifts as (that type, name=""). Both must open as an
## Expression OF that type (not a mislabelled void Action or a wrong "float"), and an accidental open-and-OK
## must be a byte-safe no-op that keeps lifted_unannotated AND re-emits the sheet byte-for-byte. Switching
## to a builtin card is a real edit that intentionally drops the type so the new one takes effect.
static func _check_dialog_preserves_custom_return() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	# A custom-class helper, exactly as the importer lifts one: return_type = TYPE_MAX (NOT TYPE_NIL).
	var pool_fn: EventFunction = EventFunction.new()
	pool_fn.function_name = "make_pool"
	pool_fn.return_type = TYPE_MAX
	pool_fn.return_type_name = "HealthPool"
	pool_fn.expose_as_ace = false
	pool_fn.lifted_unannotated = true
	var pool_body: RawCodeRow = RawCodeRow.new()
	pool_body.code = "return HealthPool.new()"
	pool_fn.events.append(pool_body)
	sheet.functions.append(pool_fn)
	# A not-carded builtin return (Color) the importer stores as (TYPE_COLOR, "") - no card exists for it.
	var tint_fn: EventFunction = EventFunction.new()
	tint_fn.function_name = "tint"
	tint_fn.return_type = TYPE_COLOR
	tint_fn.expose_as_ace = false
	tint_fn.lifted_unannotated = true
	var tint_body: RawCodeRow = RawCodeRow.new()
	tint_body.code = "return Color.WHITE"
	tint_fn.events.append(tint_body)
	sheet.functions.append(tint_fn)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var glue: EventSheetFunctionDialogGlue = dock._function_dialog_glue
	var output_before: String = str(SheetCompiler.compile(dock.get_current_sheet(), "").get("output", ""))

	# The custom class opens as an Expression whose value type IS that class, with the compiler-true signature.
	glue._open_function_dialog_for(_live_fn(dock, "make_pool"))
	var dialog: EventSheetFunctionDialog = glue._function_dialog
	ok = _check("a custom-return verb opens as an Expression, not a void Action", dialog._usable_option.selected, 2) and ok
	ok = _check("the dialog shows the custom class in the value-type dropdown",
		dialog._value_type_option.get_item_text(dialog._value_type_option.selected), "HealthPool") and ok
	ok = _check("build_function_data carries the custom return type",
		str(dialog.build_function_data().get("return_type_name", "")), "HealthPool") and ok
	ok = _check("the dialog's Ships-as signature honours the custom return",
		dialog._preview_signature.text.ends_with("-> HealthPool"), true) and ok
	dialog._on_confirmed()  # open-and-OK, no change
	var after_pool: EventFunction = _live_fn(dock, "make_pool")
	ok = _check("open-and-OK stays byte-safe on a custom return (lifted_unannotated preserved)",
		after_pool.lifted_unannotated if after_pool != null else false, true) and ok

	# A not-carded builtin (Color) opens as that type - NOT flattened to the first card (float).
	glue._open_function_dialog_for(_live_fn(dock, "tint"))
	ok = _check("a Color-return verb opens as an Expression, not a void Action", dialog._usable_option.selected, 2) and ok
	ok = _check("the dialog shows Color (not the fallback float) in the value-type dropdown",
		dialog._value_type_option.get_item_text(dialog._value_type_option.selected), "Color") and ok
	ok = _check("the dialog's Ships-as signature keeps the Color return",
		dialog._preview_signature.text.ends_with("-> Color"), true) and ok
	dialog._on_confirmed()  # open-and-OK, no change
	var after_tint: EventFunction = _live_fn(dock, "tint")
	ok = _check("open-and-OK stays byte-safe on a Color return (lifted_unannotated preserved)",
		after_tint.lifted_unannotated if after_tint != null else false, true) and ok

	# The covenant proxy the review demanded: after both accidental open-and-OKs, the whole sheet re-emits
	# byte-for-byte - no spurious `## @ace_hidden`, no flattened `-> float`, nothing dirtied.
	var output_after: String = str(SheetCompiler.compile(dock.get_current_sheet(), "").get("output", ""))
	ok = _check("open-and-OK on lifted not-carded returns re-emits the sheet byte-identically", output_after == output_before, true) and ok

	# Switching to a builtin card IS a real edit: the custom type is intentionally dropped, the new one wins.
	glue._open_function_dialog_for(_live_fn(dock, "make_pool"))
	dialog._select_usable(0)  # the void "Action" card
	dialog._on_confirmed()
	var after_change: EventFunction = _live_fn(dock, "make_pool")
	ok = _check("switching to a builtin card clears the custom return type",
		after_change.return_type_name if after_change != null else "x", "") and ok
	ok = _check("the verb now emits the builtin type",
		SheetCompiler._function_return_type_name(after_change) if after_change != null else "", "void") and ok
	ok = _check("a real type change clears lifted_unannotated",
		after_change.lifted_unannotated if after_change != null else true, false) and ok

	dock.free()
	return ok


static func _live_fn(dock: EventSheetDock, fn_name: String) -> EventFunction:
	for entry: Variant in dock.get_current_sheet().functions:
		if entry is EventFunction and (entry as EventFunction).function_name == fn_name:
			return entry as EventFunction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_return_type_name_test: %s" % label)
		return true
	print("[FAIL] function_return_type_name_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
