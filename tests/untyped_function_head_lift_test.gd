# The untyped function head - `func hurt(amount):` - opens as a real function block.
#
# WHY IT MATTERS ENOUGH TO HAVE ITS OWN GATE. A head with no `-> Type` is what almost everybody
# writes before they meet the style guide, and until this landed one of them turned its whole file
# into a wall of verbatim code: the head did not match, the function stayed raw, and (because a
# refusal re-anchors the trailing run) it took the functions above it down with it. Measured over
# the six beginner-shaped scripts in tests/fixtures/interop_corpus/ the wall was total - 15 of 15
# functions stayed code, none lifted. Over 264 style-guide files in this repo the change moves
# nothing at all, because they all annotate their returns.
#
# The whole mechanism is ONE remembered fact: the head had no return annotation, so emission leaves
# the arrow off. Nothing is corrected, and the file comes back byte for byte.
@tool
class_name UntypedFunctionHeadLiftTest
extends RefCounted

## The corpus, and what each file opens as. Beginner-shaped scripts nobody wrote for a lifter:
## untyped heads, inferred variables, connect lambdas, `##` docs. The VALUES are pinned rather than
## a count, so a regression says which function stopped opening rather than that a number moved.
const CORPUS_FUNCTIONS: Dictionary = {
	"player": ["take_damage", "heal", "die"],
	"progress": ["grant_xp", "complete_quest", "reset"],
	"enemy": ["patrol", "chase", "see_player"],
	"hud": ["restart", "show_banner", "hide_banner"],
	"pickup": ["collect"],
	"main_menu": ["start_game", "focus_entry"],
}

const CORPUS_DIR: String = "res://tests/fixtures/interop_corpus"


static func run() -> bool:
	var ok: bool = true

	# ── The mechanism: one head, one remembered fact, the same bytes back ──
	var source: String = "extends Node\n\n\nfunc hurt(amount):\n\thealth -= amount\n"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted: EventFunction = _first_function(sheet)
	ok = _check("an untyped head lifts to a function", lifted != null, true) and ok
	if lifted != null:
		ok = _check("named as written", lifted.function_name, "hurt") and ok
		ok = _check("its one parameter arrives bare", _param_ids(lifted), ["amount"]) and ok
		ok = _check("the missing return annotation is remembered", lifted.no_return_annotation, true) and ok
		ok = _check("and the head re-emits without an arrow",
			SheetCompiler.emit_function_block_text(lifted, sheet).contains("func hurt(amount):"), true) and ok
	sheet.external_source_path = "user://_untyped_head_rt.gd"
	ok = _check("the file round-trips byte-identically",
		str(SheetCompiler.compile(sheet, "user://_untyped_head_rt.gd").get("output", "")), source) and ok

	# ── A function AUTHORED on a sheet is untouched: no flag, so the typed head it always had ──
	var authored: EventFunction = EventFunction.new()
	authored.function_name = "hurt"
	ok = _check("an authored function still writes a typed head",
		SheetCompiler.emit_function_block_text(authored, EventSheetResource.new()).contains("func hurt() -> void:"),
		true) and ok

	# ── Typed and untyped heads side by side in one file, both lifting, both re-emitted as typed ──
	var mixed: String = "extends Node\n\n\nfunc typed(a: int) -> int:\n\treturn a\n\n\nfunc untyped(a):\n\treturn a\n"
	var mixed_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(mixed)
	ok = _check("both heads lift", _function_names(mixed_sheet), ["typed", "untyped"]) and ok
	ok = _check("and only the untyped one carries the flag",
		_annotation_flags(mixed_sheet), [false, true]) and ok
	mixed_sheet.external_source_path = "user://_untyped_mixed_rt.gd"
	ok = _check("the mixed file round-trips byte-identically",
		str(SheetCompiler.compile(mixed_sheet, "user://_untyped_mixed_rt.gd").get("output", "")), mixed) and ok

	# ── The corpus: what a real beginner-shaped project opens as, byte-gated file by file ──
	var drifted: PackedStringArray = PackedStringArray()
	var raw_functions: PackedStringArray = PackedStringArray()
	for file_name: Variant in CORPUS_FUNCTIONS:
		var path: String = "%s/%s.gd" % [CORPUS_DIR, str(file_name)]
		var file_source: String = FileAccess.get_file_as_string(path)
		var opened: EventSheetResource = GDScriptImporter.new().import_external(path)
		if opened == null:
			drifted.append(path)
			continue
		ok = _check("%s opens as its own functions" % str(file_name), _function_names(opened),
			CORPUS_FUNCTIONS[file_name]) and ok
		for item: Variant in opened.events:
			if item is RawCodeRow and (item as RawCodeRow).code.begins_with("func "):
				raw_functions.append("%s: %s" % [str(file_name), (item as RawCodeRow).code.split("\n")[0]])
		if str(SheetCompiler.compile(opened, "user://_untyped_corpus_rt.gd").get("output", "")) != file_source:
			drifted.append(path)
	ok = _check("every corpus file round-trips byte-identically", drifted, PackedStringArray()) and ok
	ok = _check("and not one function is left sitting as code", raw_functions, PackedStringArray()) and ok

	return ok


static func _first_function(sheet: EventSheetResource) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			return entry as EventFunction
	return null


static func _function_names(sheet: EventSheetResource) -> Array:
	var names: Array = []
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			names.append((entry as EventFunction).function_name)
	return names


static func _annotation_flags(sheet: EventSheetResource) -> Array:
	var flags: Array = []
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			flags.append((entry as EventFunction).no_return_annotation)
	return flags


static func _param_ids(event_function: EventFunction) -> Array:
	var ids: Array = []
	for param: ACEParam in event_function.params:
		ids.append(param.id)
	return ids


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] untyped_function_head_lift_test: %s" % label)
		return true
	print("[FAIL] untyped_function_head_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
