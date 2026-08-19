# Godot EventSheets - R38 (the five variable verbs and the two questions) and R42 (the dialog
# that speaks the same sentence).
#
# The picker's entries and the reading are named IDENTICALLY, so the round trip is word-exact and
# not merely byte-exact. The ids behind them are frozen - only display names and placement moved -
# which is what this pins: id -> name, and the boolean sentences the reading produces.
@tool
class_name VariableVerbsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The five verbs and the two questions, by the names the picker shows ──
	ok = _check("Set value", _display_name("SetVar"), "Set value") and ok
	ok = _check("Add to", _display_name("AddVar"), "Add to") and ok
	ok = _check("Subtract from", _display_name("SubtractVar"), "Subtract from") and ok
	ok = _check("Toggle boolean", _display_name("ToggleVar"), "Toggle boolean") and ok
	ok = _check("Set boolean", _display_name("SetBoolVar"), "Set boolean") and ok
	ok = _check("Compare variable", _display_name("CompareVar"), "Compare variable") and ok
	ok = _check("Boolean is true / is false", _display_name("BoolVarIsTrue"), "Boolean is true / is false") and ok

	# ── They all still live under one picker section ──
	for ace_id: String in ["SetVar", "AddVar", "SubtractVar", "ToggleVar", "SetBoolVar", "CompareVar", "BoolVarIsTrue"]:
		ok = _check("%s is filed under Variables" % ace_id, _category(ace_id), "Variables") and ok

	# ── The ids and the lines they emit are the frozen half ──
	ok = _check("Set value still emits an assignment", _template("SetVar"), "{var_name} = {value}") and ok
	ok = _check("Add to still emits +=", _template("AddVar"), "{var_name} += {amount}") and ok
	ok = _check("Subtract from still emits -=", _template("SubtractVar"), "{var_name} -= {amount}") and ok
	ok = _check("Toggle boolean still emits the flip", _template("ToggleVar"), "{var_name} = not {var_name}") and ok
	ok = _check("Set boolean writes the flag", _template("SetBoolVar"), "{var_name} = {value}") and ok
	ok = _check("Boolean is true / is false asks the flag", _template("BoolVarIsTrue"), "{var_name} == {value}") and ok

	# ── The reading: a boolean condition is a plain sentence, never "Is alive set" ──
	var context: Dictionary = {"self_object": "Player"}
	ok = _check("`if alive:` reads as a sentence",
		_condition_text("alive", context), "alive is true") and ok
	ok = _check("`if not muted:` flips the WORD, not a mark",
		_condition_text("not muted", context), "muted is false") and ok

	# ── R42: the dialog previews the exact row it will write, in the R37 shape ──
	var dialog: VariableDialog = VariableDialog.new()
	var host: Node = Node.new()
	dialog.init_dialog(host)
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")
	ok = _check("the preview is the row the sheet will show",
		dialog.row_preview_text(), "Instance whole number  hp = 100") and ok
	ok = _check("the Instance chip is the lit one", _lit_chip(dialog), "Instance") and ok
	dialog.open_for_edit("global", {}, "MAX_HP", "int", "100", false, "Add variable", true)
	ok = _check("a constant previews as a Constant row",
		dialog.row_preview_text(), "Constant whole number  MAX_HP = 100") and ok
	ok = _check("…and the Constant chip lights instead", _lit_chip(dialog), "Constant") and ok
	dialog.open_for_edit("local", {}, "remaining", "float", "0", false, "Add variable")
	ok = _check("a local previews as a Local row",
		dialog.row_preview_text(), "Local number  remaining = 0") and ok
	# Pressing a chip moves the scope, and the preview follows in the same breath.
	dialog._on_scope_chip_pressed(EventSheetVariableSentence.SCOPE_INSTANCE)
	ok = _check("pressing Instance moves the row back to the object",
		dialog.row_preview_text(), "Instance number  remaining = 0") and ok
	dialog.open_for_edit("global", {}, "nickname", "String", "", false, "Add variable")
	ok = _check("an empty value previews what it will actually hold",
		dialog.row_preview_text(), "Instance text  nickname = \"\"") and ok
	host.free()

	return ok


## The lit scope chip's word, "" when none is.
static func _lit_chip(dialog: VariableDialog) -> String:
	for scope_key: String in dialog._scope_chips:
		var chip: Button = dialog._scope_chips[scope_key]
		if chip.button_pressed:
			return chip.text
	return ""


## The words a condition reads with, joined - the sentence a reader actually sees.
static func _condition_text(expression: String, context: Dictionary) -> String:
	var sentence: Dictionary = EventSheetSentence.condition(expression, context)
	var words: String = ""
	for segment: Variant in sentence.get("segments", []):
		words += str((segment as Dictionary).get("text", ""))
	return words.strip_edges()


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


static func _display_name(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	return descriptor.display_name if descriptor != null else "(missing)"


static func _category(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	return descriptor.category if descriptor != null else "(missing)"


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	return descriptor.codegen_template if descriptor != null else "(missing)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_verbs_test: %s" % label)
		return true
	print("[FAIL] variable_verbs_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
