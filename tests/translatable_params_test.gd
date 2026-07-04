# Godot EventSheets - translatable string params (v0.11 chapter 1, P1).
#
# The whole feature is a convention over the param VALUE: the globe toggle wraps a
# string literal in tr("...") inside the value itself. Emission substitutes params
# verbatim (so Godot's own POT extraction and TranslationServer see the call), the
# lifter captures the wrapped value back untouched, and the params dialog merely
# reads/writes the wrapper - no schema change, no compiler change, byte-safe by
# construction. These pins hold the convention still.
@tool
class_name TranslatableParamsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The wrapper parser (drives the dialog's unwrap-and-light-the-globe) ──
	ok = _check("plain text passes through",
		ACEParamsDialog.translatable_parts("Hello"), {"text": "Hello", "translatable": false}) and ok
	ok = _check("tr(\"...\") unwraps with the globe lit",
		ACEParamsDialog.translatable_parts("tr(\"Hello\")"), {"text": "Hello", "translatable": true}) and ok
	ok = _check("escaped quotes unescape on unwrap",
		ACEParamsDialog.translatable_parts("tr(\"He said \\\"hi\\\"\")"), {"text": "He said \"hi\"", "translatable": true}) and ok
	ok = _check("the two-argument context form stays verbatim",
		ACEParamsDialog.translatable_parts("tr(\"a\", \"ctx\")"), {"text": "tr(\"a\", \"ctx\")", "translatable": false}) and ok
	ok = _check("an unrelated call stays verbatim",
		ACEParamsDialog.translatable_parts("str(42)"), {"text": "str(42)", "translatable": false}) and ok

	# ── The globe wraps at value-extraction time (quotes escaped) ──
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var edit: LineEdit = LineEdit.new()
	edit.text = "He said \"hi\""
	var globe: Button = Button.new()
	globe.toggle_mode = true
	globe.button_pressed = true
	edit.set_meta("translatable_toggle", globe)
	ok = _check("a lit globe wraps and escapes the literal",
		str(dialog._extract_value(edit)), "tr(\"He said \\\"hi\\\"\")") and ok
	globe.button_pressed = false
	ok = _check("an unlit globe leaves the text untouched",
		str(dialog._extract_value(edit)), "He said \"hi\"") and ok
	edit.free()
	globe.free()

	# ── Compile parity: the wrapped value reaches the .gd verbatim ──
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var print_action: ACEAction = ACEAction.new()
	print_action.provider_id = "Core"
	print_action.ace_id = "Print"
	print_action.params = {"value": "tr(\"Spawned\")"}
	event.actions.append(print_action)
	sheet.events.append(event)
	var compiled: String = str(SheetCompiler.compile(sheet).get("output", ""))
	ok = _check("the compiled script calls tr() at the usage site",
		compiled.contains("print(tr(\"Spawned\"))"), true) and ok

	# ── Byte round-trip: a tr() call in an opened .gd survives untouched ──
	var external_source: String = "extends Node\n\nfunc _ready() -> void:\n\tprint(tr(\"Spawned\"))\n"
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	reimported.external_source_path = "user://tr_roundtrip.gd"
	ok = _check("a tr() call round-trips byte-identically",
		str(SheetCompiler.compile(reimported, "user://tr_roundtrip.gd").get("output", "")) == external_source, true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if str(actual) == str(expected):
		print("[PASS] translatable_params_test: %s" % label)
		return true
	print("[FAIL] translatable_params_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
