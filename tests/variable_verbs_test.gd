# Godot EventSheets - the five variable verbs, the two questions, and the dialog
# that speaks the same sentence).
#
# The picker's entries and the reading are named IDENTICALLY, so the round trip is word-exact and
# not merely byte-exact. The ids behind them are frozen - only display names moved - which is what
# this pins: id -> name, the line each still emits, and the boolean sentences the reading produces.
#
# Setting and testing a boolean go through Set value and Compare variable: a separate descriptor for
# them would carry a template byte-identical to those two, and the lifter resolves a line BY its
# template, so a duplicate silently steals every `muted = true` and every `i == 1` in the project.
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
	ok = _check("Compare variable", _display_name("CompareVar"), "Compare variable") and ok

	# ── They all still live under one picker section ──
	for ace_id: String in ["SetVar", "AddVar", "SubtractVar", "ToggleVar", "CompareVar"]:
		ok = _check("%s is filed under Variables" % ace_id, _category(ace_id), "Variables") and ok

	# ── The ids and the lines they emit are the frozen half ──
	ok = _check("Set value still emits an assignment", _template("SetVar"), "{var_name} = {value}") and ok
	ok = _check("Add to still emits +=", _template("AddVar"), "{var_name} += {amount}") and ok
	ok = _check("Subtract from still emits -=", _template("SubtractVar"), "{var_name} -= {amount}") and ok
	ok = _check("Toggle boolean still emits the flip", _template("ToggleVar"), "{var_name} = not {var_name}") and ok

	# ── The reading: a boolean condition is a plain sentence, never "Is alive set" ──
	var context: Dictionary = {"self_object": "Player"}
	ok = _check("`if alive:` reads as a sentence",
		_condition_text("alive", context), "alive is true") and ok
	ok = _check("`if not muted:` flips the WORD, not a mark",
		_condition_text("not muted", context), "muted is false") and ok

	# ── the dialog previews the exact row it will write, in the shape ───────
	var dialog: VariableDialog = VariableDialog.new()
	var host: Node = Node.new()
	dialog.init_dialog(host)
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")
	ok = _check("the preview is the row the sheet will show",
		dialog.row_preview_text(), "Instance whole number  hp = 100") and ok
	ok = _check("Instance is the chosen scope", _chosen_scope(dialog), "Instance") and ok
	dialog.open_for_edit("global", {}, "MAX_HP", "int", "100", false, "Add variable", true)
	ok = _check("a constant previews as a Constant row",
		dialog.row_preview_text(), "Constant whole number  MAX_HP = 100") and ok
	ok = _check("…and the Scope dropdown says Constant instead", _chosen_scope(dialog), "Constant") and ok
	dialog.open_for_edit("local", {}, "remaining", "float", "0", false, "Add variable")
	ok = _check("a local previews as a Local row",
		dialog.row_preview_text(), "Local number  remaining = 0") and ok
	# Choosing a scope moves it, and the preview follows in the same breath.
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_INSTANCE)
	ok = _check("pressing Instance moves the row back to the object",
		dialog.row_preview_text(), "Instance number  remaining = 0") and ok
	dialog.open_for_edit("global", {}, "nickname", "String", "", false, "Add variable")
	ok = _check("an empty value previews what it will actually hold",
		dialog.row_preview_text(), "Instance text  nickname = \"\"") and ok
	host.free()

	return ok


## The word the Scope dropdown is showing, "" when it shows nothing.
static func _chosen_scope(dialog: VariableDialog) -> String:
	var option: OptionButton = dialog._scope_option
	return option.get_item_text(option.selected) if option != null and option.selected >= 0 else ""


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
